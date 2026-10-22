import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { webcrypto } from 'node:crypto';
import worker from '../backend_worker.js';
import { createD1Database, createR2Bucket, createAssetsBinding } from './d1_r2_runtime_server.mjs';

if (!globalThis.crypto) globalThis.crypto = webcrypto;
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DB = createD1Database(':memory:', path.join(ROOT, 'd1_schema_migration.sql'));
const FILES = createR2Bucket();
const ASSETS = createAssetsBinding(path.join(ROOT, 'public'));
const env = {
  DB, FILES, ASSETS,
  BOOTSTRAP_SECRET_TOKEN: 'local-test-bootstrap-secret-not-for-production-2026-10-22',
  ID_ENCRYPTION_KEY: 'local-test-identity-encryption-key-not-for-production-2026',
  EXAM_PORTAL_URL: 'https://exam.skyfirst.io.vn', DEBUG: true
};
let token = '', csrf = '', adminId = '';
let passes = 0;
const test = async (name, run) => { await run(); passes++; console.log(`PASS ${passes}: ${name}`); };
async function call(route, { method = 'GET', body, headers = {}, form } = {}) {
  const h = new Headers(headers);
  if (token) { h.set('Authorization', `Bearer ${token}`); if (csrf) h.set('X-CSRF-Token', csrf); }
  let payload;
  if (form) payload = form;
  else if (body !== undefined) { h.set('Content-Type', 'application/json'); payload = JSON.stringify(body); }
  const req = new Request(`https://scrd.skyfirst.io.vn${route}`, { method, headers: h, body: ['GET','HEAD'].includes(method) ? undefined : payload });
  const res = await worker.fetch(req, env);
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) return { res, data: await res.json() };
  return { res, data: await res.text() };
}
try {
  await test('D1 schema loads and health checks return configured bindings', async () => {
    const { res, data } = await call('/api/health');
    assert.equal(res.status, 200); assert.equal(data.d1_binding, 'connected'); assert.equal(data.r2_binding, 'configured');
  });

  await test('public bootstrap data seeds approved navigation and bilingual pages without fake records', async () => {
    const { res, data } = await call('/api/public/bootstrap-data');
    assert.equal(res.status, 200); assert.ok(data.menus.length >= 8); assert.ok(data.pages.length >= 8);
    for (const pathName of ['/','/gioi-thieu','/nghien-cuu-khoa-hoc','/du-an-cong-dong','/khao-thi-danh-gia','/cong-bo-tai-lieu','/hop-tac-doi-tac','/tin-tuc-hoat-dong']) assert.ok(data.menus.some(x=>x.target_url===pathName), `missing menu ${pathName}`);
    assert.equal(data.partners.length, 0); assert.equal(data.posts.length, 0); assert.equal(data.settings.homepage_layout.length, 9, 'homepage layout defaults must include all public blocks');
  });

  await test('one-time secure bootstrap creates the first admin and closes bootstrap', async () => {
    const { res, data } = await call('/api/bootstrap/init', { method: 'POST', headers: { 'X-Bootstrap-Token': env.BOOTSTRAP_SECRET_TOKEN }, body: { email: 'admin@example.test', full_name: 'Admin Test', password: 'TestAdminPassword123!' } });
    assert.equal(res.status, 201, JSON.stringify(data)); adminId = data.admin_user.id;
    const again = await call('/api/bootstrap/init', { method: 'POST', headers: { 'X-Bootstrap-Token': env.BOOTSTRAP_SECRET_TOKEN }, body: { email: 'second@example.test', full_name: 'Admin Two', password: 'TestAdminPassword456!' } });
    assert.equal(again.res.status, 403);
  });

  await test('login returns bearer and CSRF tokens, current-user API returns safe profile', async () => {
    const login = await call('/api/auth/login', { method: 'POST', body: { email: 'admin@example.test', password: 'TestAdminPassword123!' } });
    assert.equal(login.res.status, 200, JSON.stringify(login.data)); token = login.data.token; csrf = login.data.csrf_token; assert.ok(token && csrf);
    const me = await call('/api/auth/me'); assert.equal(me.res.status, 200); assert.equal(me.data.user.role, 'super_admin'); assert.equal(me.data.csrf_token, csrf);
  });

  await test('authenticated mutating APIs reject missing or incorrect CSRF tokens', async () => {
    const savedCsrf=csrf;
    csrf='';
    const noToken=await call('/api/cms/settings',{method:'POST',body:{settings:{hero_title_vi:'Must not be persisted'}}});
    assert.equal(noToken.res.status,403,'mutations must reject a missing CSRF header');
    csrf='not-the-real-csrf-token';
    const wrongToken=await call('/api/cms/settings',{method:'POST',body:{settings:{hero_title_vi:'Must not be persisted'}}});
    assert.equal(wrongToken.res.status,403,'mutations must reject a mismatched CSRF header');
    csrf=savedCsrf;
    const unchanged=await DB.prepare("SELECT config_value FROM system_config WHERE config_key='hero_title_vi'").first();
    assert.notEqual(unchanged?.config_value,'Must not be persisted');
  });

  await test('password recovery API no longer issues/reset tokens and provides the administrator hotline workflow', async () => {
    const forgotten = await call('/api/auth/forgot-password', { method: 'POST', body: { email: 'admin@example.test' } });
    assert.equal(forgotten.res.status, 410); assert.match(forgotten.data.error, /0924 910 210/);
    const reset = await call('/api/auth/reset-password', { method: 'POST', body: { token: 'legacy-reset-token', password: 'Never-used-password123!' } });
    assert.equal(reset.res.status, 410); assert.match(reset.data.error, /quản trị viên/i);
  });

  let requestCode = '', requestId = '';
  await test('five-step account request validates and persists encrypted identity with unique code', async () => {
    const body = {
      full_name: 'Nguyen Thi Test', email: 'applicant@example.test', phone: '0912345678', gender: 'Nữ', date_of_birth: '2000-02-03',
      applicant_group: 'general', education_level: 'Đại học', institution_name: 'Đơn vị kiểm thử', major_or_field: 'Khoa học xã hội', current_occupation: 'Nghiên cứu viên',
      id_document_type: 'CCCD', id_number: '123456789012', id_issued_date: '2020-01-01', id_issued_place: 'Cục Cảnh sát quản lý hành chính',
      registration_purpose: 'Tham gia hoạt động nghiên cứu và phát triển cộng đồng.', research_or_project_interest: 'Nghiên cứu cộng đồng',
      privacy_policy_accepted: true, terms_accepted: true, data_accuracy_confirmed: true,
      signature_data: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR3kAAAAASUVORK5CYII=',
      id_front_r2_key: 'malicious/legacy-id-front-key', id_back_r2_key: 'malicious/legacy-id-back-key'
    };
    const futureIssueDate = await call('/api/account-requests', { method: 'POST', body: { ...body, id_issued_date: '2999-01-01' } });
    assert.equal(futureIssueDate.res.status, 400, 'document issue dates in the future must be rejected');
    assert.match(futureIssueDate.data.error, /ngày cấp|hạn sử dụng/i);
    const expiryBeforeIssue = await call('/api/account-requests', { method: 'POST', body: { ...body, id_expiry_date: '2019-01-01' } });
    assert.equal(expiryBeforeIssue.res.status, 400, 'document expiry cannot precede issue date');
    assert.match(expiryBeforeIssue.data.error, /ngày cấp|hạn sử dụng/i);
    const missingPhoto = await call('/api/account-requests', { method: 'POST', body });
    assert.equal(missingPhoto.res.status, 400, 'a submitted application must include a personal portrait');
    assert.equal((await DB.prepare('SELECT COUNT(*) n FROM account_requests').first()).n, 0, 'failed submissions must not create request records or issue codes');
    const truncatedPortraitForm = new FormData();
    truncatedPortraitForm.set('file', new File([Uint8Array.from([137,80,78,71,13,10,26,10,0,0,0,0])], 'truncated.png', { type: 'image/png' }));
    truncatedPortraitForm.set('purpose', 'personal_photo');
    const truncatedPortrait = await call('/api/account-requests/upload', { method: 'POST', form: truncatedPortraitForm });
    assert.equal(truncatedPortrait.res.status,415,'a file that only carries a PNG header must be rejected');
    const portraitForm = new FormData();
    portraitForm.set('file', new File([Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR3kAAAAASUVORK5CYII=','base64')], 'portrait.png', { type: 'image/png' }));
    portraitForm.set('purpose', 'personal_photo');
    const portraitUpload = await call('/api/account-requests/upload', { method: 'POST', form: portraitForm });
    assert.equal(portraitUpload.res.status, 201, JSON.stringify(portraitUpload.data));
    body.personal_photo_r2_key = portraitUpload.data.r2_key;
    const { res, data } = await call('/api/account-requests', { method: 'POST', body });
    assert.equal(res.status, 201, JSON.stringify(data)); requestCode = data.request_code; assert.match(requestCode, /^SCRD-SFN-\d{10}$/);
    const row = await DB.prepare('SELECT * FROM account_requests WHERE request_code=?').bind(requestCode).first();
    assert.ok(row.id_number_encrypted); assert.doesNotMatch(row.id_number_encrypted, /123456789012/); assert.equal(row.id_number_masked.slice(-4), '9012'); assert.equal(row.id_number_hash, null, 'do not persist a reversible-by-brute-force unsalted hash of a low-entropy ID number'); requestId = row.id;
    assert.equal(row.id_front_r2_key,null,'legacy ID-document photo fields must never be accepted'); assert.equal(row.id_back_r2_key,null,'legacy ID-document photo fields must never be accepted');
    assert.ok(row.signature_data && !row.signature_data.includes('data:image/png'), 'signature must be encrypted at rest');
    const details = await call(`/api/admin/account-requests/${encodeURIComponent(requestId)}`);
    assert.equal(details.res.status, 200, JSON.stringify(details.data)); assert.equal(details.data.signature_data, body.signature_data); assert.ok(details.data.portrait_media_id);
    const submittedPortrait = await call(`/api/media/${encodeURIComponent(details.data.portrait_media_id)}`);
    assert.equal(submittedPortrait.res.status, 200, 'a submitted portrait must be available to an authorized reviewer');
  });

  await test('public lookup returns only safe status data and never identity/guardian fields', async () => {
    const { res, data } = await call('/api/account-requests/lookup', { method: 'POST', body: { request_code: requestCode, email: 'applicant@example.test' } });
    assert.equal(res.status, 200); const json = JSON.stringify(data); assert.match(data.request.status, /Đã tiếp nhận/); assert.doesNotMatch(json, /123456789012|guardian_phone|id_number_encrypted|review_notes_internal/);
  });

  await test('public support ticket is recorded in D1', async () => {
    const { res, data } = await call('/api/public/support-tickets', { method: 'POST', body: { sender_name: 'Nguyen Test', sender_email: 'help@example.test', subject: 'Kiểm tra hệ thống', category: 'technical', message: 'Nội dung kiểm thử hệ thống đủ dài.' } });
    assert.equal(res.status, 201, JSON.stringify(data)); const row=await DB.prepare('SELECT id FROM support_requests WHERE ticket_code=?').bind(data.ticket_code).first(); assert.ok(row);
  });

  await test('private direct/group chat, member-only endpoints, user management and temporary password workflow', async () => {
    await DB.prepare(`INSERT INTO users(id,sfn_id,email,password_hash,password_salt,full_name,role,status,created_at,updated_at) VALUES(?,?,?,?,?,?,?,'active',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)`)
      .bind('chat-member-001','SFN-CHAT001','chat.member@example.test','legacy-placeholder-hash','','Chat Member','member').run();
    const contacts=await call('/api/chat/contacts?q=Chat');assert.equal(contacts.res.status,200,JSON.stringify(contacts.data));assert.ok(contacts.data.contacts.some(x=>x.id==='chat-member-001'));assert.doesNotMatch(JSON.stringify(contacts.data.contacts),/chat.member@example.test/);
    const direct=await call('/api/chat/rooms',{method:'POST',body:{room_type:'direct',target_user_id:'chat-member-001'}});assert.equal(direct.res.status,201,JSON.stringify(direct.data));
    const directRooms=await call('/api/chat/rooms');assert.equal(directRooms.res.status,200);const directRoom=directRooms.data.rooms.find(x=>x.id===direct.data.id);assert.equal(directRoom.name,'Chat Member');assert.equal(directRoom.member_count,2);
    const directMembers=await call(`/api/chat/rooms/${encodeURIComponent(direct.data.id)}/members`);assert.equal(directMembers.res.status,404,'direct rooms do not expose group membership manager');
    const group=await call('/api/chat/rooms',{method:'POST',body:{room_type:'group',name:'Nhóm thử nghiệm bảo mật',member_user_ids:['chat-member-001']}});assert.equal(group.res.status,201,JSON.stringify(group.data));
    const members=await call(`/api/chat/rooms/${encodeURIComponent(group.data.id)}/members`);assert.equal(members.res.status,200,JSON.stringify(members.data));assert.equal(members.data.members.length,2);
    const msg=await call(`/api/chat/rooms/${encodeURIComponent(group.data.id)}/messages`,{method:'POST',body:{message_text:'Nội dung nhóm thử nghiệm'}});assert.equal(msg.res.status,201,JSON.stringify(msg.data));
    const attachmentForm=new FormData();attachmentForm.set('message_text','Tệp hướng dẫn cho nhóm');attachmentForm.set('file',new File(['chat attachment content'],'chat-notes.txt',{type:'text/plain'}));
    const attach=await call(`/api/chat/rooms/${encodeURIComponent(group.data.id)}/messages`,{method:'POST',form:attachmentForm});assert.equal(attach.res.status,201,JSON.stringify(attach.data));assert.ok(attach.data.attachment_id);
    const history=await call(`/api/chat/rooms/${encodeURIComponent(group.data.id)}/messages`);assert.equal(history.res.status,200);assert.equal(history.data.messages.length,2);const fileMessage=history.data.messages.find(x=>x.attachment);assert.equal(fileMessage.attachment.filename,'chat-notes.txt');assert.equal(fileMessage.attachment.mime_type,'text/plain');
    const permittedFile=await call(`/api/media/${encodeURIComponent(fileMessage.attachment.id)}`);assert.equal(permittedFile.res.status,200);assert.match(String(permittedFile.data),/chat attachment content/);
    const adminCredentials=await DB.prepare('SELECT password_hash,password_salt FROM users WHERE id=?').bind(adminId).first();
    await DB.prepare(`INSERT INTO users(id,sfn_id,email,password_hash,password_salt,full_name,role,status,created_at,updated_at) VALUES(?,?,?,?,?,?,'member','active',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)`).bind('chat-outsider-001','SFN-OUTSIDER01','outsider@example.test',adminCredentials.password_hash,adminCredentials.password_salt,'Chat Outsider').run();
    const adminTokenBeforeOutsider=token,adminCsrfBeforeOutsider=csrf;const outsiderLogin=await call('/api/auth/login',{method:'POST',body:{email:'outsider@example.test',password:'TestAdminPassword123!'}});assert.equal(outsiderLogin.res.status,200,JSON.stringify(outsiderLogin.data));token=outsiderLogin.data.token;csrf=outsiderLogin.data.csrf_token;
    const deniedHistory=await call(`/api/chat/rooms/${encodeURIComponent(group.data.id)}/messages`);assert.equal(deniedHistory.res.status,403,'nonmember cannot read room history');
    const deniedFile=await call(`/api/media/${encodeURIComponent(fileMessage.attachment.id)}`);assert.equal(deniedFile.res.status,403,'nonmember cannot download a private room attachment');token=adminTokenBeforeOutsider;csrf=adminCsrfBeforeOutsider;
    const users=await call('/api/admin/users');assert.equal(users.res.status,200,JSON.stringify(users.data));assert.ok(users.data.users.some(x=>x.id==='chat-member-001'));
    const selfTemp=await call(`/api/admin/users/${encodeURIComponent(adminId)}/temporary-password`,{method:'POST',body:{}});assert.equal(selfTemp.res.status,409,'super admin cannot issue its own temporary password');
    const changed=await call('/api/admin/users/chat-member-001',{method:'PATCH',body:{role:'member',status:'suspended'}});assert.equal(changed.res.status,200,JSON.stringify(changed.data));
    const suspendedTemp=await call('/api/admin/users/chat-member-001/temporary-password',{method:'POST',body:{}});assert.equal(suspendedTemp.res.status,409,'password assistance must not silently reactivate suspended users');
    const stillSuspended=await DB.prepare('SELECT status FROM users WHERE id=?').bind('chat-member-001').first();assert.equal(stillSuspended.status,'suspended');
    const activeAgain=await call('/api/admin/users/chat-member-001',{method:'PATCH',body:{role:'member',status:'active'}});assert.equal(activeAgain.res.status,200,JSON.stringify(activeAgain.data));
    const temp=await call('/api/admin/users/chat-member-001/temporary-password',{method:'POST',body:{}});assert.equal(temp.res.status,200,JSON.stringify(temp.data));assert.ok(temp.data.temporary_password);assert.equal(temp.data.status,'active');assert.equal(temp.data.must_change_password,true);
    const activated=await DB.prepare('SELECT status,password_hash,must_change_password FROM users WHERE id=?').bind('chat-member-001').first();assert.equal(activated.status,'active');assert.equal(activated.must_change_password,1);assert.match(activated.password_hash,/^pbkdf2_sha256\$210000\$/);
    const memberLogin=await call('/api/auth/login',{method:'POST',body:{email:'chat.member@example.test',password:temp.data.temporary_password}});assert.equal(memberLogin.res.status,200,JSON.stringify(memberLogin.data));assert.equal(memberLogin.data.user.must_change_password,true);
    const adminTokenBeforeMember=token,adminCsrfBeforeMember=csrf;token=memberLogin.data.token;csrf=memberLogin.data.csrf_token;
    const forcedBlocked=await call('/api/dashboard/overview');assert.equal(forcedBlocked.res.status,428,'temporary password must block protected APIs');
    const changedPassword=await call('/api/auth/change-password',{method:'POST',body:{current_password:temp.data.temporary_password,new_password:'ChangedMemberPassword123!',confirm_password:'ChangedMemberPassword123!'}});assert.equal(changedPassword.res.status,200,JSON.stringify(changedPassword.data));
    const memberMe=await call('/api/auth/me');assert.equal(memberMe.res.status,200);assert.equal(memberMe.data.user.must_change_password,false);
    const afterChangeProtected=await call('/api/dashboard/overview');assert.equal(afterChangeProtected.res.status,200,JSON.stringify(afterChangeProtected.data));
    const oldTempLogin=await call('/api/auth/login',{method:'POST',body:{email:'chat.member@example.test',password:temp.data.temporary_password}});assert.equal(oldTempLogin.res.status,401,'old temporary password is invalid after change');
    const newMemberLogin=await call('/api/auth/login',{method:'POST',body:{email:'chat.member@example.test',password:'ChangedMemberPassword123!'}});assert.equal(newMemberLogin.res.status,200);assert.equal(newMemberLogin.data.user.must_change_password,false);
    token=adminTokenBeforeMember;csrf=adminCsrfBeforeMember;
  });

  await test('CMS page/post/menu/settings/redirect routes persist content and sanitize dangerous markup', async () => {
    const post = await call('/api/cms/posts', { method: 'POST', body: { slug: 'test-post', title_vi: 'Bài kiểm thử', title_en: 'Test post', content_vi: '<p>Hợp lệ</p><script>alert(1)</script><img src=x onerror=alert(1)>', content_en: '<p>Safe</p>', status: 'published' } });
    assert.equal(post.res.status, 200, JSON.stringify(post.data));
    const postRow=await DB.prepare('SELECT * FROM cms_posts WHERE id=?').bind(post.data.id).first(); assert.ok(postRow); assert.doesNotMatch(postRow.content_vi,/script|onerror/i);
    const page = await call('/api/cms/pages', { method: 'POST', body: { slug: 'smoke-page', title_vi: 'Trang thử', title_en: 'Smoke page', content_vi: '<p>Nội dung</p>', content_en: '<p>Content</p>', page_group: 'general', status: 'published' } });
    assert.equal(page.res.status, 200, JSON.stringify(page.data)); assert.ok(await DB.prepare('SELECT id FROM cms_pages WHERE id=?').bind(page.data.id).first());
    const upsertBySlug = await call('/api/cms/pages', { method: 'POST', body: { slug: 'smoke-page', title_vi: 'Trang thử cập nhật', title_en: 'Updated smoke page', content_vi: '<p>Cập nhật</p>', content_en: '<p>Updated</p>', page_group: 'general', status: 'draft' } });
    assert.equal(upsertBySlug.res.status, 200, JSON.stringify(upsertBySlug.data)); assert.equal(upsertBySlug.data.id, page.data.id, 'upsert by slug must update the existing page instead of creating a duplicate');
    const pageUpdated = await DB.prepare('SELECT title_vi,status,version FROM cms_pages WHERE slug=?').bind('smoke-page').first(); assert.equal(pageUpdated.title_vi, 'Trang thử cập nhật'); assert.equal(pageUpdated.status, 'draft'); assert.ok(pageUpdated.version >= 2);
    const reserved = await DB.prepare("SELECT id FROM cms_pages WHERE slug='tong-quan'").first();
    const protectDelete = await call(`/api/cms/pages/${encodeURIComponent(reserved.id)}`, { method: 'DELETE' }); assert.equal(protectDelete.res.status, 409, 'core system pages must not be accidentally deleted');
    const deletePage = await call(`/api/cms/pages/${encodeURIComponent(page.data.id)}`, { method: 'DELETE' }); assert.equal(deletePage.res.status, 200, JSON.stringify(deletePage.data)); assert.equal(await DB.prepare('SELECT id FROM cms_pages WHERE slug=?').bind('smoke-page').first(), null);
    const menu = await call('/api/cms/menus', { method: 'POST', body: { menu_location: 'main_header', label_vi: 'Menu kiểm thử', label_en: 'Test menu', target_url: '/kiem-thu', sort_order: 99, is_visible: true } }); assert.equal(menu.res.status, 200, JSON.stringify(menu.data));
    const setting = await call('/api/cms/settings', { method: 'POST', body: { settings: { hero_title_vi: 'Tiêu đề đã cập nhật', unsafe_unapproved_key: 'ignored' } } }); assert.equal(setting.res.status, 200); assert.ok(setting.data.saved.includes('hero_title_vi')); assert.ok(!setting.data.saved.includes('unsafe_unapproved_key'));
    const layout=[{id:'hero',enabled:true,order:1},{id:'news',enabled:true,order:2},{id:'pillars',enabled:false,order:3},{id:'programs',enabled:true,order:4},{id:'assessments',enabled:true,order:5},{id:'publications',enabled:true,order:6},{id:'partners',enabled:true,order:7},{id:'cooperation',enabled:true,order:8},{id:'longform',enabled:true,order:9}];
    const savedLayout=await call('/api/cms/settings',{method:'POST',body:{settings:{homepage_layout:layout}}});assert.equal(savedLayout.res.status,200,JSON.stringify(savedLayout.data));assert.ok(savedLayout.data.saved.includes('homepage_layout'));
    const storedLayout=JSON.parse((await DB.prepare("SELECT config_value FROM system_config WHERE config_key='homepage_layout'").first()).config_value);assert.equal(storedLayout[1].id,'news');assert.equal(storedLayout[2].enabled,false);
    const badLayout=await call('/api/cms/settings',{method:'POST',body:{settings:{homepage_layout:layout.map((x,i)=>i===1?{...x,id:'hero'}:x)}}});assert.equal(badLayout.res.status,400,'invalid duplicate layout blocks must be rejected');
    const heroMoved=await call('/api/cms/settings',{method:'POST',body:{settings:{homepage_layout:[...layout.slice(1),layout[0]]}}});assert.equal(heroMoved.res.status,400,'hero must remain first');
    const redir = await call('/api/cms/redirects', { method: 'POST', body: { old_path: '/duong-cu-kiem-thu', new_path: '/gioi-thieu', status_code: 301 } }); assert.equal(redir.res.status, 200, JSON.stringify(redir.data));
    const pageRows=await DB.prepare('SELECT COUNT(*) n FROM cms_pages WHERE slug=?').bind('smoke-page').first(); assert.equal(pageRows.n,0, 'deleted CMS page must be removed from D1');
  });

  let publicMediaId = '';
  await test('R2 public media upload and public download work through backend metadata', async () => {
    const form = new FormData(); form.set('file', new File(['public test media'], 'test.txt', { type: 'text/plain' })); form.set('visibility', 'public');
    const { res, data } = await call('/api/media/upload', { method: 'POST', form }); assert.equal(res.status, 201, JSON.stringify(data)); publicMediaId=data.id;
    const dl=await call(`/api/media/${encodeURIComponent(publicMediaId)}`, { headers: {} }); assert.equal(dl.res.status, 200); assert.match(String(dl.data), /public test media/);
  });

  await test('private account uploads are not publicly accessible and image fields enforce image MIME', async () => {
    const bad = new FormData(); bad.set('file', new File(['not-an-image'], 'fake.txt', {type:'text/plain'})); bad.set('purpose','personal_photo');
    const denied=await call('/api/account-requests/upload',{method:'POST',form:bad}); assert.equal(denied.res.status,415,JSON.stringify(denied.data));
    const idImage = new FormData(); idImage.set('file', new File([Uint8Array.from([137,80,78,71,13,10,26,10,0,0,0,0])], 'id.png', {type:'image/png'})); idImage.set('purpose','id_front');
    const idRejected=await call('/api/account-requests/upload',{method:'POST',form:idImage}); assert.equal(idRejected.res.status,400,JSON.stringify(idRejected.data));
    const good = new FormData(); good.set('file', new File(['supporting document'], 'support.txt', {type:'text/plain'})); good.set('purpose','supporting_doc');
    const up=await call('/api/account-requests/upload',{method:'POST',form:good}); assert.equal(up.res.status,201,JSON.stringify(up.data));
    // The staging object must not be available to an anonymous caller even when its metadata ID is known.
    token=''; csrf='';
    const blocked=await call(`/api/media/${encodeURIComponent(up.data.id)}`); assert.equal(blocked.res.status,404,'unattached staging object should be indistinguishable from a missing file');
    // Even an accidental/public metadata-scope change must not publish an unattached staging object.
    await DB.prepare("UPDATE r2_files SET access_scope='public' WHERE id=?").bind(up.data.id).run();
    const misconfiguredPublic=await call(`/api/media/${encodeURIComponent(up.data.id)}`);
    assert.equal(misconfiguredPublic.res.status,404,'staging guard must run before the public-scope check');
    await DB.prepare("UPDATE r2_files SET access_scope='identity_private' WHERE id=?").bind(up.data.id).run();
    // Restore admin session after verifying private access control.
    const login=await call('/api/auth/login',{method:'POST',body:{email:'admin@example.test',password:'TestAdminPassword123!'}});assert.equal(login.res.status,200);token=login.data.token;csrf=login.data.csrf_token;
    const deniedStagingReviewer=await call(`/api/media/${encodeURIComponent(up.data.id)}`);
    assert.equal(deniedStagingReviewer.res.status,404,'reviewers must not read unattached staging uploads before submission');
  });

  await test('reviewer workflow updates public status without exposing internal notes', async () => {
    const review=await call('/api/admin/account-requests/review',{method:'POST',body:{request_id:requestId,new_status:'Đang xem xét',review_notes_public:'Hồ sơ đang được xem xét.',internal_reviewer_notes:'Nội bộ test — không trả ra công khai.'}});
    assert.equal(review.res.status,200,JSON.stringify(review.data));
    const lookup=await call('/api/account-requests/lookup',{method:'POST',body:{request_code:requestCode,email:'applicant@example.test'}});assert.equal(lookup.res.status,200);assert.equal(lookup.data.request.status,'Đang xem xét');assert.doesNotMatch(JSON.stringify(lookup.data),/Nội bộ test/);
  });

  await test('account approval, activation status, and administrator-issued temporary password stay synchronized', async () => {
    const approved = await call('/api/admin/account-requests/review', { method: 'POST', body: { request_id: requestId, new_status: 'Đã duyệt', review_notes_public: 'Hồ sơ đủ điều kiện.' } });
    assert.equal(approved.res.status, 200, JSON.stringify(approved.data));
    const approvedUserId = approved.data.approved_user_id;
    assert.ok(approvedUserId, 'approved request must be linked to the created user');
    assert.equal((await DB.prepare('SELECT status FROM users WHERE id=?').bind(approvedUserId).first()).status, 'pending');
    const activated = await call('/api/admin/account-requests/review', { method: 'POST', body: { request_id: requestId, new_status: 'Đã kích hoạt tài khoản', review_notes_public: 'Vui lòng liên hệ quản trị viên để nhận thông tin truy cập an toàn.' } });
    assert.equal(activated.res.status, 200, JSON.stringify(activated.data));
    assert.equal((await DB.prepare('SELECT status FROM users WHERE id=?').bind(approvedUserId).first()).status, 'active');
    assert.equal((await DB.prepare('SELECT status FROM account_requests WHERE id=?').bind(requestId).first()).status, 'Đã kích hoạt tài khoản');
    const temp = await call(`/api/admin/users/${encodeURIComponent(approvedUserId)}/temporary-password`, { method: 'POST', body: {} });
    assert.equal(temp.res.status, 200, JSON.stringify(temp.data));
    assert.equal(temp.data.must_change_password, true);
    assert.equal((await DB.prepare('SELECT must_change_password FROM users WHERE id=?').bind(approvedUserId).first()).must_change_password, 1);
  });

  await test('research/project/task CRUD endpoints persist rows and update progress', async () => {
    const research=await call('/api/research',{method:'POST',body:{title_vi:'Nghiên cứu thử',title_en:'Test research',code:'TEST-R1',slug:'test-r1',summary_vi:'Tóm tắt kiểm thử',summary_en:'Test summary',status:'Đề xuất',is_public:true}});
    assert.equal(research.res.status,200,JSON.stringify(research.data));
    const project=await call('/api/projects',{method:'POST',body:{title_vi:'Dự án thử',title_en:'Test project',code:'TEST-P1',slug:'test-p1',summary_vi:'Tóm tắt',summary_en:'Summary',status:'Đang thực hiện',is_public:true}});
    assert.equal(project.res.status,200,JSON.stringify(project.data));
    const orphanTask=await call('/api/tasks',{method:'POST',body:{parent_type:'research',parent_id:'NO-SUCH-PROGRAM',title:'Không được tạo',status:'completed',weight:1}});
    assert.equal(orphanTask.res.status,404,'tasks must reference an existing program');
    const invalidWeight=await call('/api/tasks',{method:'POST',body:{parent_type:'research',parent_id:research.data.id,title:'Trọng số sai',status:'completed',weight:1001}});
    assert.equal(invalidWeight.res.status,400,'task weight must be bounded');
    const task=await call('/api/tasks',{method:'POST',body:{parent_type:'research',parent_id:research.data.id,title:'Nhiệm vụ thử',status:'completed',weight:1}});
    assert.equal(task.res.status,200,JSON.stringify(task.data)); assert.equal(task.data.parent_progress_percent,100);
    const blockedDelete=await call(`/api/research/${encodeURIComponent(research.data.id)}`,{method:'DELETE'});assert.equal(blockedDelete.res.status,409,'program deletion must be blocked while tasks are linked');
    const taskUpdate=await call('/api/tasks',{method:'POST',body:{id:task.data.id,parent_type:'research',parent_id:research.data.id,title:'Nhiệm vụ đã sửa',status:'todo',weight:2}});
    assert.equal(taskUpdate.res.status,200);assert.equal(taskUpdate.data.parent_progress_percent,0,'task update must recalculate progress');
    const taskDelete=await call(`/api/tasks/${encodeURIComponent(task.data.id)}`,{method:'DELETE'});assert.equal(taskDelete.res.status,200);assert.equal(taskDelete.data.parent_progress_percent,0);
    const researchDelete=await call(`/api/research/${encodeURIComponent(research.data.id)}`,{method:'DELETE'});assert.equal(researchDelete.res.status,200,JSON.stringify(researchDelete.data));
    const projectDelete=await call(`/api/projects/${encodeURIComponent(project.data.id)}`,{method:'DELETE'});assert.equal(projectDelete.res.status,200,JSON.stringify(projectDelete.data));
  });

  await test('exam start creates launch token, returns exam-domain launch URL, and submit stores receipt', async () => {
    const examId='exam-smoke-001';
    await DB.prepare(`INSERT INTO exams(id,code,title,title_en,duration_minutes,time_limit_enabled,show_score,pass_score,status,question_json,created_at,updated_at) VALUES(?,?,?,?,60,1,1,70,'published',?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)`)
      .bind(examId,'SMOKE-EXAM','Bài thi kiểm thử','Smoke exam',JSON.stringify([{id:'q1',type:'mcq',question:'2+2?',options:['3','4'],answer:'4',points:1}])).run();
    const start=await call(`/api/exams/${examId}/start`,{method:'POST',body:{}});assert.equal(start.res.status,201,JSON.stringify(start.data));assert.match(start.data.launch_url,/^https:\/\/exam\.skyfirst\.io\.vn\/\?launch=/);
    const row=await DB.prepare('SELECT id FROM exam_attempts WHERE id=?').bind(start.data.attempt_id).first();assert.ok(row);
    const submit=await call(`/api/my/exam-attempts/${start.data.attempt_id}/submit`,{method:'POST',body:{answers:{q1:'4'}}});assert.equal(submit.res.status,200,JSON.stringify(submit.data));assert.equal(submit.data.score,1);assert.ok(submit.data.receipt_code);
  });

  await test('route errors and unknown APIs never disclose internals', async () => {
    const bad=await call('/api/no-such-endpoint');assert.equal(bad.res.status,404);assert.ok(bad.data.error);
    const x=await call('/api/files/not-a-file/download');assert.equal(x.res.status,404);
  });

  console.log(`SCRD WORKER + D1 SQLITE + R2 SMOKE: ${passes}/${passes} PASS`);
} catch (error) {
  console.error(`FAIL after ${passes} passed checks:`, error?.stack || error);
  process.exitCode = 1;
} finally {
  DB.close();
}
