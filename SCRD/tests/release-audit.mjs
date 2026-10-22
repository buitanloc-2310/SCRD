import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const exists = p => fs.existsSync(path.join(root, p));
const files = [];
function walk(dir, rel='') {
  for (const entry of fs.readdirSync(dir, {withFileTypes:true})) {
    const child = path.join(dir, entry.name), r = path.posix.join(rel, entry.name);
    if (entry.isDirectory()) walk(child, r); else files.push(r);
  }
}
walk(root);
let passed = 0;
const test = (name, run) => { run(); passed++; console.log(`PASS RELEASE ${passed}: ${name}`); };

const html = read('public/index.html');
const app = read('public/app.js');
const css = read('public/styles.css');
const worker = read('backend_worker.js');
const schema = read('d1_schema_migration.sql');
const migrationFiles = fs.readdirSync(path.join(root,'migrations')).filter(x => /^\d+.*\.sql$/.test(x)).sort();
const uiTests = read('tests/ui-regression.mjs');
const examHtml = read('EXAM/public/index.html');
const examHeaders = read('EXAM/public/_headers');
const scrdHeaders = read('public/_headers');

const requiredRoutes = [
  '/', '/gioi-thieu', '/nghien-cuu-khoa-hoc', '/du-an-cong-dong',
  '/khao-thi-danh-gia', '/cong-bo-tai-lieu', '/hop-tac-doi-tac', '/tin-tuc-hoat-dong'
];

test('release contains SCRD, Exam, backend, migrations, tests and operator docs', () => {
  for (const p of ['public/index.html','public/app.js','public/styles.css','backend_worker.js','EXAM/src/index.js','EXAM/public/index.html','EXAM/public/exam.js','d1_schema_migration.sql','README_VI.md','SECURITY_AUDIT_VI.md','SCRD_EXAM_RELEASE_CHECKLIST_12_PARTS_VI.md','SUPER_COMPREHENSIVE_AUDIT_VI.md','REQUIREMENT_TRACEABILITY_12_PARTS_VI.md','RELEASE_BUILD_INFO.md','RELEASE_MANIFEST_SUPER_COMPREHENSIVE_VI.md','CHANGELOG_SUPER_COMPREHENSIVE_VI.md','RELEASE_MANIFEST.json','RELEASE_FILE_HASHES_SHA256.txt']) assert.ok(exists(p), `missing ${p}`);
  assert.ok(migrationFiles.length >= 6, `expected versioned migrations; got ${migrationFiles.length}`);
  assert.ok(exists('tests/smoke.mjs') && exists('tests/integration.mjs') && exists('tests/release-audit.mjs'));
});

test('public header is clean and contains only brand, VI/EN and eight-item navigation shell', () => {
  assert.doesNotMatch(html, /class="utility-bar"|headerRegisterBtn|headerPortalBtn|Khởi tạo Quản trị viên đầu tiên/);
  assert.match(html, /brand-identity/); assert.match(html, /id="btnLangVi"/); assert.match(html, /id="btnLangEn"/); assert.match(html, /id="publicMainNav"/);
  for (const route of requiredRoutes) assert.ok(worker.includes(`'${route}'`) || worker.includes(`"${route}"`) || read('migrations/0002_cleanup_unverified_content.sql').includes(route) || read('migrations/0003_home_about_longform.sql').includes(route) || read('migrations/0001_initial_schema.sql').includes(route) || read('tests/ui-regression.mjs').includes(route), `required route not found in source/test set: ${route}`);
});

test('public header renderer does not reconstruct technical utility or account/CMS CTA', () => {
  assert.doesNotMatch(app, /utilityBar\.innerHTML|headerRegisterBtn|headerPortalBtn/);
  assert.match(app, /function renderShell\(/);
  assert.match(html, /id="footerCol4Links"/);
});

test('hero defaults match the approved Vietnamese/English title, subtitle and description', () => {
  assert.match(app, /NGHIÊN CỨU KHOA HỌC & PHÁT TRIỂN CỘNG ĐỒNG/);
  assert.match(app, /Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững/);
  assert.match(app, /SCIENTIFIC RESEARCH & COMMUNITY DEVELOPMENT/);
  assert.match(app, /hero_description_vi/); assert.match(app, /hero_description_en/);
});

test('registration, lookup, login and forgot-password have distinct URL routes, not header popovers', () => {
  for (const route of ["path === '/dang-ky'", "path === '/tra-cuu'", "path === '/dang-nhap'", "path === '/quen-mat-khau'"]) assert.ok(app.includes(route), `missing route ${route}`);
  assert.match(app, /function renderForgotPasswordView/);
  assert.match(app, /function renderRegister5StepsView/);
});

test('step 3 only uploads portrait/supporting document and backend rejects legacy ID-photo purposes', () => {
  assert.match(app, /Ảnh chân dung cá nhân/);
  assert.doesNotMatch(app, /fileIdFront|fileIdBack/);
  assert.match(worker, /\['personal_photo','supporting_doc'\]/);
  assert.match(worker, /không tải ảnh giấy tờ định danh vào trường ảnh chân dung/);
  assert.match(worker, /personal_photo_r2_key/);
});

test('step 5 has readable terms, three separate confirmations, signature draw/upload and server validation', () => {
  for (const x of ['registration-terms','chkAccuracy','chkPrivacy','chkTerms','signatureCanvas','fileSignatureImage']) assert.ok(app.includes(x), `missing ${x}`);
  assert.match(worker, /if\(!boolInt\(b\.privacy_policy_accepted\)\|\|!boolInt\(b\.terms_accepted\)\|\|!boolInt\(b\.data_accuracy_confirmed\)\)/);
  assert.match(worker, /const encSignature=await encryptSensitive\(signature,env\.ID_ENCRYPTION_KEY\)/);
  assert.match(app, /localizeRegistrationMarkup/);
});

test('public lookup does not return sensitive identity or internal review fields', () => {
  assert.match(worker, /SELECT request_code,status,review_notes_public,submitted_at,updated_at FROM account_requests/);
  assert.doesNotMatch(worker.match(/if\(path==='\/api\/account-requests\/lookup'&&method==='POST'\)[\s\S]*?\n  }/ )?.[0] || '', /id_number_encrypted|signature_data|review_notes_internal|guardian_phone/);
});

test('forgot-password is hotline guidance and legacy token endpoints are disabled', () => {
  assert.match(app, /0924 910 210/);
  assert.doesNotMatch(app, /apiFetch\('\/api\/auth\/forgot-password'/);
  assert.match(worker, /path==='\/api\/auth\/forgot-password'\|\|path==='\/api\/auth\/reset-password'/);
  assert.match(worker, /410/);
});

test('session, CSRF, role and forced-temporary-password checks remain server-side', () => {
  assert.match(worker, /async function requireSession/);
  assert.match(worker, /CSRF_INVALID/);
  assert.match(worker, /MUST_CHANGE_PASSWORD/);
  assert.match(worker, /if\(session\.role!=='super_admin'\)return fail\('Chỉ super admin được quản lý người dùng/);
});

test('chat messages, room membership and attachments are member-scoped in backend', () => {
  assert.match(worker, /SELECT room_id FROM chat_room_members WHERE room_id=\? AND user_id=\?/);
  assert.match(worker, /chat_messages cm JOIN chat_room_members rm/);
  assert.match(worker, /related_entity_id!==roomId/);
  assert.match(worker, /CHAT_GROUP_CREATED/);
});

test('unsubmitted account-upload staging files cannot be fetched even if metadata scope is accidentally public', () => {
  assert.match(worker, /if\(row\.related_entity_type==='account_request_staging'\)/);
  assert.match(worker, /Use a not-found response for all callers/);
});

test('low-entropy identity number is encrypted at rest and not stored as an unsalted hash', () => {
  assert.match(worker, /encryptSensitive\(idNumber,env\.ID_ENCRYPTION_KEY\)/);
  assert.match(worker, /idType,encNumber,null,maskedId\(idNumber,idType\)/);
  assert.match(read('tests/smoke.mjs'), /row\.id_number_hash, null/);
});

test('Exam source keeps server-controlled attempt/scoring integration and no answer leak in public view', () => {
  assert.match(worker, /createExamAttempt/);
  assert.match(worker, /scoreAndSubmit/);
  assert.match(read('EXAM/src/index.js'), /answer_revision|revision/);
  assert.match(read('tests/integration.mjs'), /without exposing answers/);
});

test('security headers and SPA route fallbacks are present', () => {
  for (const h of ['X-Content-Type-Options','Referrer-Policy','Content-Security-Policy','object-src']) assert.ok(scrdHeaders.includes(h), `SCRD missing ${h}`);
  for (const h of ['X-Content-Type-Options','Referrer-Policy','Content-Security-Policy','frame-ancestors']) assert.ok(examHeaders.includes(h), `Exam missing ${h}`);
  assert.match(read('public/_redirects'), /\/\* \/index\.html 200/);
  assert.match(read('EXAM/public/_redirects'), /\/join\/\* \/index\.html 200/);
});

test('release does not include secrets, local environment files, dependency trees or build caches', () => {
  for (const f of files) {
    const parts = f.split('/');
    assert.ok(!parts.includes('node_modules'), `node_modules shipped: ${f}`);
    assert.ok(!parts.includes('.git') && !parts.includes('.wrangler'), `cache/repository data shipped: ${f}`);
    assert.ok(!/^\.env($|\.)/.test(parts.at(-1)), `environment file shipped: ${f}`);
    assert.ok(!parts.includes('dist'), `generated dist shipped: ${f}`);
  }
  assert.ok(!files.some(f => /(^|\/)(id_rsa|credentials\.json|service-account\.json|\.dev\.vars)$/.test(f)), 'possible secret-bearing file included');
});

test('CMS has persisted home block ordering plus guarded CRUD for programs/tasks', () => {
  assert.match(app, /data-home-block=\"assessments\"/);
  assert.match(app, /data-dash-tab=\"cms_home_layout\"/);
  assert.match(app, /data-delete-program=/); assert.match(app, /data-delete-task=/);
  assert.match(worker, /const researchDelete=path\.match/); assert.match(worker, /const projectDelete=path\.match/); assert.match(worker, /const taskDelete=path\.match/);
  assert.match(worker, /parentRow=await env\.DB\.prepare/);
  assert.match(worker, /Không thể xóa dự án khi còn nhiệm vụ liên kết/);
});

test('static HTML/CSS assets resolve inside both SCRD and Exam packages', () => {
  const resolveAppAsset = (appRoot, raw) => {
    const value = raw.split(/[?#]/,1)[0];
    if (!value || value.startsWith('data:') || value.startsWith('mailto:') || value.startsWith('tel:') || value.startsWith('#') || /^https?:\/\//i.test(value)) return;
    const relative = value.startsWith('/') ? value.slice(1) : value;
    assert.ok(fs.existsSync(path.join(root,appRoot,relative)), `${appRoot}: missing asset ${raw}`);
  };
  for (const [appRoot, htmlPath, cssPaths] of [
    ['public', 'public/index.html', ['styles.css']],
    ['EXAM/public', 'EXAM/public/index.html', ['styles.css','exam.css']]
  ]) {
    const page=read(htmlPath);
    for (const match of page.matchAll(/(?:src|href)=[\"']([^\"']+)[\"']/g)) resolveAppAsset(appRoot,match[1]);
    for (const cssPath of cssPaths) {
      if (!fs.existsSync(path.join(root,appRoot,cssPath))) continue;
      const css=fs.readFileSync(path.join(root,appRoot,cssPath),'utf8');
      for (const match of css.matchAll(/url\([\"']?([^\"')]+)[\"']?\)/g)) resolveAppAsset(appRoot,match[1]);
    }
  }
  assert.ok(exists('public/assets/sky-first-logo-trimmed.webp'));
  assert.ok(exists('public/assets/sky-first-logo.png'));
});

test('D1 name placeholders are explicitly documented rather than guessed', () => {
  assert.match(read('wrangler.toml'), /REPLACE_WITH_ACTUAL_D1_DATABASE_NAME/);
  assert.match(read('EXAM/wrangler.json'), /CONFIRM_ACTUAL_D1_DATABASE_NAME/);
  assert.match(read('README_VI.md'), /không được đoán|không đoán/i);
});

console.log(`RELEASE AUDIT: ${passed}/${passed} PASS`);
console.log(`Release files inspected: ${files.length}`);
console.log(`Versioned migrations inspected: ${migrationFiles.length}`);
console.log('Note: these are local source/release checks, not production deployment or browser E2E proof.');
