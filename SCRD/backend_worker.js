/**
 * Sky First Center for Research and Development — Cloudflare Worker
 * Uses the current 0001 schema in d1_schema_migration.sql.
 * Bindings: DB (D1), FILES (R2), ASSETS (Workers Static Assets).
 * Required secrets: BOOTSTRAP_SECRET_TOKEN, ID_ENCRYPTION_KEY.
 * Optional mail secrets: EMAIL_WEBHOOK_URL, EMAIL_API_KEY, EMAIL_FROM.
 */
const SITE = {
  vi: 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First',
  en: 'Sky First Center for Research and Development',
  domain: 'https://scrd.skyfirst.io.vn',
  exam: 'https://exam.skyfirst.io.vn',
  email: 'support@skyfirst.io.vn'
};
const ROLES = new Set(['super_admin','cms_editor','reviewer','research_lead','researcher','project_manager','project_lead','examiner','member','student']);
const CMS_ROLES = new Set(['super_admin','cms_editor']);
const ADMIN_ROLES = new Set(['super_admin']);
const REVIEW_ROLES = new Set(['super_admin','reviewer']);
const RESEARCH_ROLES = new Set(['super_admin','research_lead','researcher','project_manager','project_lead']);
const MAX_UPLOAD = 25 * 1024 * 1024;
const MIME_EXT = new Map([
  ['image/jpeg','jpg'],['image/png','png'],['image/webp','webp'],['application/pdf','pdf'],
  ['text/plain','txt'],['text/csv','csv'],['application/vnd.openxmlformats-officedocument.wordprocessingml.document','docx'],
  ['application/msword','doc'],['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','xlsx'],['application/vnd.ms-excel','xls'],
  ['application/vnd.openxmlformats-officedocument.presentationml.presentation','pptx'],['application/vnd.ms-powerpoint','ppt']
]);
const DEFAULT_SETTINGS = {
  site_name_vi: SITE.vi, site_name_en: SITE.en, site_domain: SITE.domain, exam_portal_url: SITE.exam,
  support_email: SITE.email,
  hero_eyebrow_vi: 'TRUNG TÂM NGHIÊN CỨU VÀ PHÁT TRIỂN CỘNG ĐỒNG SKY FIRST',
  hero_eyebrow_en: 'SKY FIRST CENTER FOR RESEARCH AND DEVELOPMENT',
  hero_title_vi: 'NGHIÊN CỨU KHOA HỌC & PHÁT TRIỂN CỘNG ĐỒNG',
  hero_title_en: 'SCIENTIFIC RESEARCH & COMMUNITY DEVELOPMENT',
  hero_subtitle_vi: 'Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững.',
  hero_subtitle_en: 'Connecting academic knowledge, standardized assessment, and sustainable community initiatives.',
  hero_description_vi: 'Nền tảng chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
  hero_description_en: 'The official platform of Sky First Center for Research and Development.',
  copyright_vi: '© Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
  copyright_en: '© Sky First Center for Research and Development.',
  homepage_layout: [
    {id:'hero',enabled:true,order:1},{id:'pillars',enabled:true,order:2},{id:'programs',enabled:true,order:3},
    {id:'assessments',enabled:true,order:4},{id:'publications',enabled:true,order:5},{id:'news',enabled:true,order:6},
    {id:'partners',enabled:true,order:7},{id:'cooperation',enabled:true,order:8},{id:'longform',enabled:true,order:9}
  ]
};
const DEFAULT_MENUS = [
  ['menu_main_1','main_header','Trang chủ','Home','/','1'],
  ['menu_main_2','main_header','Giới thiệu','About','/gioi-thieu','2'],
  ['menu_main_3','main_header','Nghiên cứu khoa học','Scientific Research','/nghien-cuu-khoa-hoc','3'],
  ['menu_main_4','main_header','Dự án cộng đồng','Community Projects','/du-an-cong-dong','4'],
  ['menu_main_5','main_header','Khảo thí và Đánh giá học thuật','Academic Assessment','/khao-thi-danh-gia','5'],
  ['menu_main_6','main_header','Công bố và Tài liệu','Publications and Resources','/cong-bo-tai-lieu','6'],
  ['menu_main_7','main_header','Hợp tác và Đối tác','Cooperation and Partners','/hop-tac-doi-tac','7'],
  ['menu_main_8','main_header','Tin tức và Hoạt động','News and Activities','/tin-tuc-hoat-dong','8'],
  ['menu_f2_1','footer_col_2','Giới thiệu Trung tâm','About the Center','/gioi-thieu?section=tong-quan','1'],
  ['menu_f2_2','footer_col_2','Sứ mệnh và tầm nhìn','Mission and Vision','/gioi-thieu?section=su-menh-tam-nhin','2'],
  ['menu_f2_3','footer_col_2','Cơ cấu tổ chức','Organizational Structure','/gioi-thieu?section=co-cau-to-chuc','3'],
  ['menu_f2_4','footer_col_2','Lĩnh vực hoạt động','Core Areas of Activity','/gioi-thieu?section=linh-vuc-hoat-dong','4'],
  ['menu_f2_5','footer_col_2','Liên hệ','Contact Us','/gioi-thieu?section=lien-he','5'],
  ['menu_f3_1','footer_col_3','Email hỗ trợ','Support email','mailto:support@skyfirst.io.vn','1'],
  ['menu_f3_2','footer_col_3','Website Sky First','Sky First website','https://www.skyfirst.io.vn','2'],
  ['menu_f3_3','footer_col_3','Facebook Sky First Network','Sky First Network on Facebook','https://fb.com/skyfirstnetwork','3'],
  ['menu_f4_1','footer_col_4','Đăng nhập','Sign in','/dang-nhap','1'],
  ['menu_f4_2','footer_col_4','Tra cứu hồ sơ','Track a request','/tra-cuu','2'],
  ['menu_f4_3','footer_col_4','Yêu cầu cấp tài khoản','Request an account','/dang-ky','3'],
  ['menu_f4_4','footer_col_4','Quên mật khẩu','Forgot password','/quen-mat-khau','4'],
  ['menu_f4_5','footer_col_4','Hướng dẫn sử dụng','User guide','/gioi-thieu?section=huong-dan-su-dung','5'],
  ['menu_fb_1','footer_bottom','Bảo vệ dữ liệu cá nhân','Personal Data Protection','/gioi-thieu?section=chinh-sach-bao-ve-du-lieu','1'],
  ['menu_fb_2','footer_bottom','Điều khoản sử dụng','Terms of Use','/gioi-thieu?section=dieu-khoan-su-dung','2'],
  ['menu_fb_3','footer_bottom','Hỗ trợ người dùng','User Support','/gioi-thieu?section=ho-tro-nguoi-dung','3']
].map(([id,loc,vi,en,url,order]) => ({id,loc,vi,en,url,order:Number(order)}));
const DEFAULT_PAGES = []; // Canonical bilingual pages are seeded by the versioned D1 migration.
const now = () => new Date().toISOString();
const uuid = () => crypto.randomUUID();
const enc = new TextEncoder();
const str = v => String(v ?? '').trim();
const cleanText = (v, max=5000) => String(v ?? '').replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g,'').trim().slice(0,max);
const boolInt = v => v === true || v === 1 || v === '1' || v === 'true' ? 1 : 0;
const parseJson = (s, fallback=null) => { try { return JSON.parse(s); } catch { return fallback; } };
const hex = b => [...new Uint8Array(b)].map(x=>x.toString(16).padStart(2,'0')).join('');
const hashText = async v => hex(await crypto.subtle.digest('SHA-256', enc.encode(String(v))));
const randomToken = (n=32) => { const b=crypto.getRandomValues(new Uint8Array(n)); return [...b].map(x=>x.toString(16).padStart(2,'0')).join(''); };
const jsonResponse = (body,status=200,request=null,extra={}) => {
  const h = new Headers({'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'strict-origin-when-cross-origin','X-Frame-Options':'DENY',...extra});
  const origin = request?.headers?.get('Origin') || '';
  const allowed = new Set(['https://scrd.skyfirst.io.vn','https://www.scrd.skyfirst.io.vn','https://exam.skyfirst.io.vn','http://localhost:8787','http://127.0.0.1:8787','http://localhost:8788','http://127.0.0.1:8788']);
  if (origin && (allowed.has(origin) || (request && origin === new URL(request.url).origin))) {
    h.set('Access-Control-Allow-Origin', origin); h.set('Vary','Origin'); h.set('Access-Control-Allow-Credentials','false');
  }
  h.set('Access-Control-Allow-Methods','GET, POST, PUT, PATCH, DELETE, OPTIONS');
  h.set('Access-Control-Allow-Headers','Content-Type, Authorization, X-Bootstrap-Token, X-CSRF-Token, X-Exam-Session');
  h.set('Access-Control-Max-Age','86400');
  return new Response(JSON.stringify(body),{status,headers:h});
};
const ok = (data={},status=200,request=null) => jsonResponse({ok:true,...data},status,request);
const fail = (message,status=400,request=null,extra={}) => jsonResponse({ok:false,error:message,...extra},status,request);
function sanitizeHtml(html='') {
  // Server-side conservative HTML filter for authored CMS content. Frontend also applies a render-time filter.
  let s=String(html??'').slice(0,200000);
  s=s.replace(/<!--[\s\S]*?-->/g,'').replace(/<(script|style|iframe|object|embed|form|input|button|textarea|select|meta|base|link|svg|math)\b[^>]*>[\s\S]*?<\/\1\s*>/gi,'')
    .replace(/<(script|style|iframe|object|embed|form|input|button|textarea|select|meta|base|link|svg|math)\b[^>]*\/?>/gi,'')
    .replace(/\s+on[a-z]+\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi,'')
    .replace(/\s+(src|href)\s*=\s*(["'])\s*(?:javascript|vbscript|data):[\s\S]*?\2/gi,'')
    .replace(/expression\s*\(/gi,'blocked(').replace(/url\s*\(\s*["']?\s*javascript:/gi,'url(blocked:');
  return s;
}
function safeUrl(value) {
  const s=str(value); if (!s) return false;
  if (s.startsWith('/') && !s.startsWith('//')) return true;
  if (s.startsWith('#')) return true;
  try { return ['https:','http:','mailto:','tel:'].includes(new URL(s).protocol); } catch { return false; }
}
async function hashPassword(password, saltHex=null) {
  const salt = saltHex ? new Uint8Array(saltHex.match(/.{1,2}/g).map(x=>parseInt(x,16))) : crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey('raw',enc.encode(password),{name:'PBKDF2'},false,['deriveBits']);
  const bits = await crypto.subtle.deriveBits({name:'PBKDF2',salt,iterations:210000,hash:'SHA-256'},key,256);
  return `pbkdf2_sha256$210000$${hex(salt)}$${hex(bits)}`;
}
async function verifyPassword(password, stored) {
  if (typeof stored !== 'string') return false;
  const p=stored.split('$'); if (p.length!==4 || p[0]!=='pbkdf2_sha256') return false;
  const iterations=Number(p[1]); if (!Number.isFinite(iterations)||iterations<100000||iterations>500000) return false;
  const key=await crypto.subtle.importKey('raw',enc.encode(password),{name:'PBKDF2'},false,['deriveBits']);
  const bits=await crypto.subtle.deriveBits({name:'PBKDF2',salt:new Uint8Array(p[2].match(/.{1,2}/g).map(x=>parseInt(x,16))),iterations,hash:'SHA-256'},key,256);
  return constantEqual(hex(bits),p[3]);
}
function constantEqual(a,b) { if(typeof a!=='string'||typeof b!=='string'||a.length!==b.length)return false;let d=0;for(let i=0;i<a.length;i++)d|=a.charCodeAt(i)^b.charCodeAt(i);return d===0; }
async function encryptSensitive(value, secret) {
  if (!secret || String(secret).length < 32) throw new Error('ID_ENCRYPTION_KEY_NOT_CONFIGURED');
  const keyBytes=await crypto.subtle.digest('SHA-256',enc.encode(String(secret)));
  const key=await crypto.subtle.importKey('raw',keyBytes,{name:'AES-GCM'},false,['encrypt']);
  const iv=crypto.getRandomValues(new Uint8Array(12));
  const ciphertext=await crypto.subtle.encrypt({name:'AES-GCM',iv},key,enc.encode(String(value)));
  const b64=a=>{const bytes=new Uint8Array(a);let binary='';for(let i=0;i<bytes.length;i+=0x8000)binary+=String.fromCharCode(...bytes.subarray(i,i+0x8000));return btoa(binary);};
  return JSON.stringify({v:1,alg:'A256GCM',iv:b64(iv),data:b64(ciphertext)});
}
async function decryptSensitive(value, secret) {
  if (!secret || String(secret).length < 32) throw Object.assign(new Error('ID_ENCRYPTION_KEY_NOT_CONFIGURED'), { httpStatus: 503 });
  let envelope; try { envelope = JSON.parse(str(value)); } catch { throw Object.assign(new Error('Dữ liệu được mã hóa không hợp lệ.'), { httpStatus: 500 }); }
  if (!envelope || envelope.v !== 1 || envelope.alg !== 'A256GCM' || !envelope.iv || !envelope.data) throw Object.assign(new Error('Định dạng dữ liệu được mã hóa không được hỗ trợ.'), { httpStatus: 500 });
  const fromB64 = input => Uint8Array.from(atob(input), c => c.charCodeAt(0));
  const keyBytes = await crypto.subtle.digest('SHA-256', enc.encode(String(secret)));
  const key = await crypto.subtle.importKey('raw', keyBytes, { name: 'AES-GCM' }, false, ['decrypt']);
  const plaintext = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: fromB64(envelope.iv) }, key, fromB64(envelope.data));
  return new TextDecoder().decode(plaintext);
}
function requestIp(request){return request?.headers?.get('CF-Connecting-IP')||'unknown';}
async function writeAudit(db,request,actor,action,type,id,details={}) {
  try {
    const safe={...details}; for(const k of ['password','password_hash','reset_token','launch_token','bootstrap_token','id_number','national_id_number','id_number_encrypted','signature_data','guardian_phone'])delete safe[k];
    await db.prepare(`INSERT INTO audit_logs(id,actor_user_id,action,resource_type,resource_id,ip_address,user_agent,details_sanitized,created_at) VALUES(?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)`)
      .bind(uuid(),actor||null,cleanText(action,100),cleanText(type,100),id||null,requestIp(request),cleanText(request?.headers?.get('User-Agent'),300),JSON.stringify(safe)).run();
  } catch { /* audit failure is not allowed to leak information or replace the primary response */ }
}
async function currentSession(request,env) {
  const m=str(request.headers.get('Authorization')).match(/^Bearer\s+([A-Za-z0-9._~-]{32,256})$/i); if(!m)return null;
  const tokenHash=await hashText(m[1]);
  const s=await env.DB.prepare(`SELECT s.session_id,s.csrf_token,s.expires_at,u.id AS user_id,u.sfn_id,u.email,u.full_name,u.role,u.status,u.avatar_r2_key,u.avatar_url,u.phone,u.organization,u.department,u.academic_title,u.bio_vi,u.bio_en,u.must_change_password
    FROM user_sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.revoked=0 AND s.expires_at>CURRENT_TIMESTAMP LIMIT 1`).bind(tokenHash).first();
  return s && s.status==='active' ? s : null;
}
function needsCsrf(request,session) {
  // Mutating authenticated requests must explicitly carry the session-bound CSRF token.
  // The bearer token is not cookie-ambient; requiring both headers adds defense in depth against confused clients.
  const token=request.headers.get('X-CSRF-Token');
  return Boolean(token) && constantEqual(token,session.csrf_token||'');
}
async function requireSession(request,env,roles=null) {
  const session=await currentSession(request,env);
  if(!session)throw Object.assign(new Error('UNAUTHORIZED'),{httpStatus:401});
  if(Number(session.must_change_password||0)===1)throw Object.assign(new Error('MUST_CHANGE_PASSWORD'),{httpStatus:428});
  if(!needsCsrf(request,session) && !['GET','HEAD','OPTIONS'].includes(request.method)) throw Object.assign(new Error('CSRF_INVALID'),{httpStatus:403});
  if(roles && !roles.has(session.role))throw Object.assign(new Error('FORBIDDEN'),{httpStatus:403});
  return session;
}
async function safeBody(request,max=1_000_000) {
  const len=Number(request.headers.get('Content-Length')||0); if(len>max)throw Object.assign(new Error('Dữ liệu gửi vượt giới hạn.'),{httpStatus:413});
  try { const text=await request.text(); if(text.length>max)throw Object.assign(new Error('Dữ liệu gửi vượt giới hạn.'),{httpStatus:413}); return text?JSON.parse(text):{}; }
  catch(e){if(e.httpStatus)throw e;throw Object.assign(new Error('Dữ liệu JSON không hợp lệ.'),{httpStatus:400});}
}
async function rateLimit(db,key,limit=8,windowSec=900) {
  const nowSec=Math.floor(Date.now()/1000);
  const row=await db.prepare('SELECT window_start,attempt_count,blocked_until FROM rate_limits WHERE rate_key=?').bind(key).first();
  if(row?.blocked_until && Date.parse(row.blocked_until)>Date.now())return false;
  if(!row || nowSec-Number(row.window_start)>=windowSec) {
    await db.prepare(`INSERT INTO rate_limits(rate_key,window_start,attempt_count,blocked_until) VALUES(?,?,1,NULL) ON CONFLICT(rate_key) DO UPDATE SET window_start=excluded.window_start,attempt_count=1,blocked_until=NULL`).bind(key,nowSec).run(); return true;
  }
  const count=Number(row.attempt_count||0)+1;
  const blocked=count>limit ? new Date(Date.now()+windowSec*1000).toISOString() : null;
  await db.prepare('UPDATE rate_limits SET attempt_count=?,blocked_until=? WHERE rate_key=?').bind(count,blocked,key).run();
  return !blocked;
}
async function uniqueRequestCode(db) {
  for(let attempt=0;attempt<12;attempt++) {
    let digits=''; while(digits.length<10){const bytes=crypto.getRandomValues(new Uint8Array(16));for(const b of bytes){if(b<250)digits+=String(b%10);if(digits.length===10)break;}}
    const code=`SCRD-SFN-${digits}`;
    const found=await db.prepare('SELECT id FROM account_requests WHERE request_code=?').bind(code).first();
    if(!found)return code;
  }
  throw Object.assign(new Error('Không thể tạo mã hồ sơ duy nhất. Vui lòng thử lại.'),{httpStatus:503});
}
async function dispatchEmail(env, type, recipient, subject, variables={}, reference=null) {
  let status='pending_smtp_config', provider='Email service not configured';
  const safeVariables={...variables};
  for(const k of ['id_number','national_id_number','id_number_encrypted','signature_data','personal_photo_r2_key','id_front_r2_key','id_back_r2_key','supporting_doc_r2_key','guardian_phone'])delete safeVariables[k];
  if(env.EMAIL_WEBHOOK_URL && env.EMAIL_API_KEY) {
    try {
      const response=await fetch(env.EMAIL_WEBHOOK_URL,{method:'POST',headers:{'Content-Type':'application/json','Authorization':`Bearer ${env.EMAIL_API_KEY}`},body:JSON.stringify({from:env.EMAIL_FROM||SITE.email,to:recipient,subject,template_key:type,variables:safeVariables})});
      if(response.ok){status='sent';provider=`HTTP ${response.status}`;}else{status='failed';provider=`HTTP ${response.status}`;}
    } catch { status='failed'; provider='provider_unreachable'; }
  }
  const allowedTypes=new Set(['account_request_received','account_request_supplement','account_request_approved','account_request_rejected','account_activated','account_request_status_update','password_reset','research_notification','project_notification','assessment_notification','task_assignment','support_ticket_received','security_alert']);
  try { await env.DB.prepare(`INSERT INTO email_dispatch_logs(id,event_type,recipient_email,subject,reference_code,delivery_status,provider_response,contains_sensitive_id,created_at) VALUES(?,?,?,?,?,?,?,0,CURRENT_TIMESTAMP)`)
    .bind(uuid(),allowedTypes.has(type)?type:'security_alert',cleanText(recipient,220),cleanText(subject,250),reference, status,provider).run(); } catch {}
  return {status,configured:Boolean(env.EMAIL_WEBHOOK_URL&&env.EMAIL_API_KEY)};
}
async function ensureDefaults(db) {
  for(const [key,value] of Object.entries(DEFAULT_SETTINGS)) await db.prepare(`INSERT OR IGNORE INTO system_config(config_key,config_value,is_public,updated_at) VALUES(?,?,1,CURRENT_TIMESTAMP)`).bind(key,JSON.stringify(value)).run();
  for(const m of DEFAULT_MENUS) await db.prepare(`INSERT OR IGNORE INTO cms_menus(id,menu_location,label_vi,label_en,target_url,link_type,sort_order,is_visible,open_in_new_tab,updated_at) VALUES(?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)`)
    .bind(m.id,m.loc,m.vi,m.en,m.url,m.url.startsWith('/')?'internal':'external',m.order,1,m.url.startsWith('http')||m.url.startsWith('mailto:')?1:0).run();
  for(const p of DEFAULT_PAGES) await db.prepare(`INSERT OR IGNORE INTO cms_pages(id,slug,title_vi,title_en,summary_vi,summary_en,content_vi,content_en,page_group,sort_order,status,version,published_at,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?, 'published',1,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)`)
    .bind(`seed-page-${p.slug}`,p.slug,p.vi,p.en,p.vi,p.en,p.viBody,p.enBody,p.group,p.order).run();
}
async function loadPublicData(env) {
  await ensureDefaults(env.DB);
  const [settingRows,menus,redirects,pages,posts,research,projects,pubs,exams,partners]=await Promise.all([
    env.DB.prepare('SELECT config_key,config_value FROM system_config WHERE is_public=1').all(),
    env.DB.prepare('SELECT id,menu_location,parent_id,label_vi,label_en,target_url,link_type,sort_order,is_visible,open_in_new_tab FROM cms_menus WHERE is_visible=1 ORDER BY menu_location,sort_order').all(),
    env.DB.prepare('SELECT old_path,new_path,status_code,is_active FROM cms_redirects WHERE is_active=1').all(),
    env.DB.prepare(`SELECT id,slug,title_vi,title_en,summary_vi,summary_en,content_vi,content_en,page_group,seo_title_vi,seo_title_en,seo_description_vi,seo_description_en,updated_at FROM cms_pages WHERE status='published' ORDER BY sort_order`).all(),
    env.DB.prepare(`SELECT id,slug,custom_path,title_vi,title_en,excerpt_vi,excerpt_en,content_vi,content_en,category,tags_json,featured_image_url,featured_media_id,display_author,is_ai_generated,status,seo_title,seo_description,published_at,updated_at FROM cms_posts WHERE status='published' ORDER BY published_at DESC`).all(),
    env.DB.prepare(`SELECT id,code,slug,title_vi,title_en,field_vi,field_en,summary_vi,summary_en,methodology_vi,methodology_en,findings_summary_vi,findings_summary_en,status,progress_percent,start_date,end_date FROM research_studies WHERE is_public=1 ORDER BY created_at DESC`).all(),
    env.DB.prepare(`SELECT id,code,slug,title_vi,title_en,objective_vi,objective_en,summary_vi,summary_en,activities_vi,activities_en,location,status,progress_percent,start_date,end_date,public_evidence_summary FROM community_projects WHERE is_public=1 ORDER BY created_at DESC`).all(),
    env.DB.prepare(`SELECT id,code,slug,title_vi,title_en,category,summary_vi,summary_en,authors_text,access_level,published_date,download_count FROM publications_documents WHERE access_level='public' AND is_verified=1 ORDER BY published_date DESC`).all(),
    env.DB.prepare(`SELECT id,code,title,title_en,public_overview_vi,public_overview_en,duration_minutes,pass_score,assessment_label,status,opens_at,closes_at FROM exams WHERE status='published' AND (opens_at IS NULL OR datetime(opens_at)<=CURRENT_TIMESTAMP) AND (closes_at IS NULL OR datetime(closes_at)>CURRENT_TIMESTAMP) ORDER BY created_at DESC`).all(),
    env.DB.prepare(`SELECT id,organization_name_vi,organization_name_en,partner_type,website_url,description_vi,description_en FROM partners WHERE is_verified=1 AND is_public=1 ORDER BY created_at DESC`).all()
  ]);
  const settings={...DEFAULT_SETTINGS}; for(const row of settingRows.results||[]){settings[row.config_key]=parseJson(row.config_value,row.config_value);}
  return {settings,menus:menus.results||[],redirects:redirects.results||[],pages:pages.results||[],posts:posts.results||[],research_studies:research.results||[],community_projects:projects.results||[],publications:pubs.results||[],exams:exams.results||[],partners:partners.results||[]};
}
function validDateOnly(value) { const v=str(value);if(!/^\d{4}-\d{2}-\d{2}$/.test(v))return false;const [y,m,d]=v.split('-').map(Number);const date=new Date(Date.UTC(y,m-1,d));return y>=1900&&date.getUTCFullYear()===y&&date.getUTCMonth()===m-1&&date.getUTCDate()===d; }
function calcAge(dob) { if(!validDateOnly(dob))return null;const [y,m,d]=dob.split('-').map(Number);const nowDate=new Date();let age=nowDate.getUTCFullYear()-y;if(nowDate.getUTCMonth()<m-1||(nowDate.getUTCMonth()===m-1&&nowDate.getUTCDate()<d))age--;return age; }
function validEmail(v){return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(str(v)) && str(v).length<=220;}
function maskedId(v,type){const s=str(v).replace(/\s/g,'');return s.length<=4?'•'.repeat(s.length):`${'•'.repeat(Math.max(4,s.length-4))}${s.slice(-4)}`;}
async function validateUploadFile(file) {
  if(!file||typeof file.arrayBuffer!=='function'||!file.size)throw Object.assign(new Error('Vui lòng chọn tệp tải lên.'),{httpStatus:400});
  if(file.size>MAX_UPLOAD)throw Object.assign(new Error('Tệp vượt quá 25 MB.'),{httpStatus:413});
  const mime=str(file.type).toLowerCase(); if(!MIME_EXT.has(mime))throw Object.assign(new Error('Định dạng tệp chưa được hỗ trợ.'),{httpStatus:415});
  const prefix=new Uint8Array(await file.slice(0,Math.min(file.size,1024*1024)).arrayBuffer());
  const tail=new Uint8Array(await file.slice(Math.max(0,file.size-12)).arrayBuffer());
  const u32be=(b,o)=>((b[o]*0x1000000)+(b[o+1]<<16)+(b[o+2]<<8)+b[o+3])>>>0;
  const u24le=(b,o)=>(b[o]|(b[o+1]<<8)|(b[o+2]<<16))>>>0;
  const checkDimensions=(w,h,format)=>{if(!w||!h||w>12000||h>12000||w*h>40000000)throw Object.assign(new Error(`${format}: kích thước ảnh không hợp lệ hoặc vượt quá giới hạn 40 megapixel.`),{httpStatus:413});};
  if(mime==='image/png'){
    const validSignature=prefix.length>=24&&prefix.slice(0,8).join(',')==='137,80,78,71,13,10,26,10';
    const validHeader=validSignature&&u32be(prefix,8)===13&&String.fromCharCode(...prefix.slice(12,16))==='IHDR';
    const hasImageData=new TextDecoder('ascii').decode(prefix).includes('IDAT');
    const hasEnd=tail.length===12&&tail.join(',')==='0,0,0,0,73,69,78,68,174,66,96,130';
    if(file.size<45||!validHeader||!hasImageData||!hasEnd)throw Object.assign(new Error('Cấu trúc PNG không hợp lệ hoặc tệp ảnh bị cắt cụt.'),{httpStatus:415});
    checkDimensions(u32be(prefix,16),u32be(prefix,20),'PNG');
  }
  if(mime==='image/jpeg'){
    if(file.size<20||prefix[0]!==0xff||prefix[1]!==0xd8||tail[tail.length-2]!==0xff||tail[tail.length-1]!==0xd9)throw Object.assign(new Error('Cấu trúc JPEG không hợp lệ hoặc tệp ảnh bị cắt cụt.'),{httpStatus:415});
    let pos=2,dimensions=null;
    const sof=new Set([0xc0,0xc1,0xc2,0xc3,0xc5,0xc6,0xc7,0xc9,0xca,0xcb,0xcd,0xce,0xcf]);
    while(pos+3<prefix.length){
      while(pos<prefix.length&&prefix[pos]!==0xff)pos++;
      while(pos<prefix.length&&prefix[pos]===0xff)pos++;
      if(pos>=prefix.length)break;
      const marker=prefix[pos++];
      if(marker===0xd9||marker===0xda)break;
      if(marker===0x01||(marker>=0xd0&&marker<=0xd7))continue;
      if(pos+1>=prefix.length)break;
      const length=(prefix[pos]<<8)|prefix[pos+1];
      if(length<2||pos+length>prefix.length)break;
      if(sof.has(marker)&&length>=7){dimensions={h:(prefix[pos+3]<<8)|prefix[pos+4],w:(prefix[pos+5]<<8)|prefix[pos+6]};break;}
      pos+=length;
    }
    if(!dimensions)throw Object.assign(new Error('Không xác định được kích thước ảnh JPEG; tệp có thể hỏng hoặc không được hỗ trợ.'),{httpStatus:415});
    checkDimensions(dimensions.w,dimensions.h,'JPEG');
  }
  if(mime==='image/webp'){
    if(file.size<30||String.fromCharCode(...prefix.slice(0,4))!=='RIFF'||String.fromCharCode(...prefix.slice(8,12))!=='WEBP'||(prefix[4]+(prefix[5]<<8)+(prefix[6]<<16)+(prefix[7]*0x1000000))!==file.size-8)throw Object.assign(new Error('Cấu trúc WebP không hợp lệ hoặc tệp ảnh bị cắt cụt.'),{httpStatus:415});
    const chunk=String.fromCharCode(...prefix.slice(12,16));let w=0,h=0;
    if(chunk==='VP8X'&&prefix.length>=30){w=u24le(prefix,24)+1;h=u24le(prefix,27)+1;}
    else if(chunk==='VP8L'&&prefix.length>=25&&prefix[20]===0x2f){w=1+prefix[21]+((prefix[22]&0x3f)<<8);h=1+(prefix[22]>>6)+(prefix[23]<<2)+((prefix[24]&0x0f)<<10);}
    else if(chunk==='VP8 '&&prefix.length>=30&&prefix[23]===0x9d&&prefix[24]===0x01&&prefix[25]===0x2a){w=((prefix[26]|(prefix[27]<<8))&0x3fff);h=((prefix[28]|(prefix[29]<<8))&0x3fff);}
    if(!w||!h)throw Object.assign(new Error('Không xác định được kích thước ảnh WebP; tệp có thể hỏng hoặc không được hỗ trợ.'),{httpStatus:415});
    checkDimensions(w,h,'WebP');
  }
  if(mime==='application/pdf' && (prefix.length<8||String.fromCharCode(...prefix.slice(0,4))!=='%PDF'))throw Object.assign(new Error('Chữ ký PDF không hợp lệ.'),{httpStatus:415});
  if(mime.includes('openxmlformats') && !(prefix[0]===0x50&&prefix[1]===0x4b))throw Object.assign(new Error('Chữ ký Office không hợp lệ.'),{httpStatus:415});
  return {file,mime,bytes:prefix};
}
async function getUploadFile(request) { const fd=await request.formData(); return validateUploadFile(fd.get('file')); }
function safeFilename(name,mime){const base=String(name||'file').normalize('NFKD').replace(/[^a-zA-Z0-9._-]+/g,'_').replace(/^\.+/,'').slice(-120)||'file';return /\.[a-zA-Z0-9]{2,5}$/.test(base)?base:`${base}.${MIME_EXT.get(mime)||'bin'}`;}
async function uploadToR2(env, request, {purpose='general',scope='private',owner=null,relatedType=null,relatedId=null,anonymous=false,fileData=null}={}) {
  const {file,mime,bytes}=fileData || await getUploadFile(request);
  if(!env.FILES)throw Object.assign(new Error('Kho tệp R2 chưa được cấu hình.'),{httpStatus:503});
  const id=uuid(),filename=safeFilename(file.name,mime),date=new Date().toISOString().slice(0,10);
  const prefix=anonymous?'account-request-staging':purpose==='exam_response'?'exam-attachments':purpose==='avatar'?'avatars':'uploads';
  const key=`${prefix}/${date}/${id}-${filename}`;
  const checksum=hex(await crypto.subtle.digest('SHA-256', await file.arrayBuffer()));
  await env.FILES.put(key,await file.arrayBuffer(),{httpMetadata:{contentType:mime,cacheControl:scope==='public'?'public, max-age=3600':'private, no-store'},customMetadata:{purpose,accessScope:scope,ownerUserId:owner||''}});
  try {
    await env.DB.prepare(`INSERT INTO r2_files(id,r2_key,bucket_name,original_filename,mime_type,size_bytes,sha256_checksum,access_scope,purpose,owner_user_id,related_entity_type,related_entity_id,created_at) VALUES(?,?,'scrd-files',?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP)`)
      .bind(id,key,filename,mime,file.size,checksum,scope, purpose,owner,relatedType,relatedId).run();
  } catch(e) { await env.FILES.delete(key).catch(()=>{}); throw e; }
  return {id,r2_key:key,original_filename:filename,mime_type:mime,size_bytes:file.size,access_scope:scope};
}
async function fileResponse(request,env,row) {
  const session=await currentSession(request,env).catch(()=>null);
  const scope=row.access_scope;
  // Enforce staging isolation before evaluating access_scope, so an accidental/unsafe public
  // metadata change cannot publish a file that has not been attached to a submitted request.
  if(row.related_entity_type==='account_request_staging') {
    // Use a not-found response for all callers to avoid confirming existence of a staged upload.
    return fail('Không tìm thấy tệp được yêu cầu.',404,request);
  }
  if(scope!=='public') {
    if(!session)return fail('Bạn cần đăng nhập để xem tệp này.',401,request);
    if(Number(session.must_change_password||0)===1)return fail('Tài khoản đang dùng mật khẩu tạm thời. Vui lòng đổi mật khẩu trước khi tiếp tục.',428,request);
    let allowed=scope==='authenticated' && row.owner_user_id===session.user_id;
    allowed ||= scope==='research_team' && (RESEARCH_ROLES.has(session.role)||ADMIN_ROLES.has(session.role));
    allowed ||= scope==='project_team' && (RESEARCH_ROLES.has(session.role)||ADMIN_ROLES.has(session.role));
    allowed ||= scope==='admin_only' && ADMIN_ROLES.has(session.role);
    allowed ||= scope==='identity_private' && REVIEW_ROLES.has(session.role);
    allowed ||= scope==='exam_protected' && (session.role==='examiner'||ADMIN_ROLES.has(session.role));
    if(scope==='chat_attachment'&&session){
      const attachmentMembership=await env.DB.prepare(`SELECT 1 AS allowed FROM chat_messages cm JOIN chat_room_members rm ON rm.room_id=cm.room_id AND rm.user_id=? WHERE cm.attachment_r2_file_id=? AND cm.is_deleted=0 LIMIT 1`).bind(session.user_id,row.id).first().catch(()=>null);
      allowed ||= Boolean(attachmentMembership);
    }
    // Private account files remain accessible only to reviewers/admins, not just any logged-in user.
    allowed ||= row.related_entity_type==='account_request' && REVIEW_ROLES.has(session.role);
    if(!allowed)return fail('Bạn không có quyền xem tệp này.',403,request);
  }
  const object=await env.FILES.get(row.r2_key); if(!object)return fail('Không tìm thấy tệp trong kho lưu trữ.',404,request);
  const headers={'Content-Type':row.mime_type||'application/octet-stream','Content-Length':String(object.size??row.size_bytes),'X-Content-Type-Options':'nosniff','Cache-Control':scope==='public'?'public, max-age=3600':'private, no-store','Content-Disposition':`inline; filename="${safeFilename(row.original_filename,row.mime_type)}"`};
  return new Response(object.body,{status:200,headers});
}
async function createSession(env,request,user) {
  const raw=randomToken(32),tokenHash=await hashText(raw),csrf=randomToken(24),sessionId=uuid();
  await env.DB.prepare(`INSERT INTO user_sessions(session_id,user_id,token_hash,csrf_token,ip_address,user_agent,expires_at,revoked,created_at) VALUES(?,?,?,?,?,?,datetime('now','+7 days'),0,CURRENT_TIMESTAMP)`)
    .bind(sessionId,user.id,tokenHash,csrf,requestIp(request),cleanText(request?.headers?.get('User-Agent'),300)).run();
  return {token:raw,csrf_token:csrf,session_id:sessionId};
}
function publicUser(user) { return {id:user.id||user.user_id,sfn_id:user.sfn_id||null,email:user.email,full_name:user.full_name,role:user.role,status:user.status,must_change_password:Boolean(Number(user.must_change_password||0)),avatar_r2_key:user.avatar_r2_key||null,avatar_url:user.avatar_url||null,phone:user.phone||'',organization:user.organization||'',department:user.department||'',academic_title:user.academic_title||'',bio_vi:user.bio_vi||'',bio_en:user.bio_en||''}; }
function validatePostStatus(status,existing) { const s=str(status||existing||'draft'); if(!['draft','pending_review','published','unpublished'].includes(s))throw Object.assign(new Error('Trạng thái bài viết không hợp lệ.'),{httpStatus:400}); return s; }
async function reviewRequest(env,request,session,body) {
  const requestId=str(body.request_id); const newStatus=str(body.new_status);
  const statuses=['Đã tiếp nhận','Đang xem xét','Cần bổ sung thông tin','Đã duyệt','Từ chối','Đã kích hoạt tài khoản'];
  if(!requestId||!statuses.includes(newStatus))throw Object.assign(new Error('Mã hồ sơ hoặc trạng thái xét duyệt không hợp lệ.'),{httpStatus:400});
  const row=await env.DB.prepare('SELECT * FROM account_requests WHERE id=?').bind(requestId).first(); if(!row)throw Object.assign(new Error('Không tìm thấy hồ sơ.'),{httpStatus:404});
  const pub=cleanText(body.public_review_message ?? body.review_notes_public,3000),internal=cleanText(body.internal_reviewer_notes,5000);
  let approvedUserId=row.approved_user_id||null;
  if(newStatus==='Đã kích hoạt tài khoản') {
    if(!approvedUserId)throw Object.assign(new Error('Cần duyệt hồ sơ trước khi đánh dấu tài khoản đã kích hoạt.'),{httpStatus:409});
    const activationTarget=await env.DB.prepare('SELECT id,status FROM users WHERE id=? LIMIT 1').bind(approvedUserId).first();
    if(!activationTarget)throw Object.assign(new Error('Không tìm thấy tài khoản được liên kết với hồ sơ.'),{httpStatus:409});
    if(!['pending','active'].includes(activationTarget.status))throw Object.assign(new Error('Tài khoản đang bị tạm khóa hoặc khóa. Hãy xử lý trạng thái tài khoản riêng trước khi kích hoạt.'),{httpStatus:409});
  }
  if(newStatus==='Đã duyệt' && !approvedUserId) {
    const role=ROLES.has(row.requested_role)&&!['super_admin','cms_editor','reviewer'].includes(row.requested_role)?row.requested_role:'member';
    const uid=uuid(),sfnId=`SFN-${randomToken(6).toUpperCase()}`;
    const randomPassword=randomToken(40),passwordHash=await hashPassword(randomPassword);
    await env.DB.prepare(`INSERT INTO users(id,sfn_id,email,password_hash,password_salt,full_name,role,status,phone,gender,date_of_birth,organization,department,is_minor,guardian_name,guardian_phone,guardian_email,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)`)
      .bind(uid,sfnId,row.email,passwordHash,'',row.full_name,role,'pending',row.phone,row.gender,row.date_of_birth,row.institution_name,row.faculty_department,row.is_minor,row.guardian_full_name,row.guardian_phone,row.guardian_email).run();
    approvedUserId=uid;
    // Account approval does not issue password-reset/activation tokens: the applicant is directed to the administrator/hotline workflow.
    await dispatchEmail(env,'account_request_approved',row.email,`Hồ sơ ${row.request_code} đã được duyệt`,{full_name:row.full_name,request_code:row.request_code,support_phone:'0924 910 210',support_email:SITE.email,next_step:'Liên hệ quản trị viên hoặc hotline để xác minh và hoàn tất thiết lập tài khoản.'},row.request_code);
  }
  if(newStatus==='Từ chối') await dispatchEmail(env,'account_request_rejected',row.email,`Cập nhật hồ sơ ${row.request_code}`,{full_name:row.full_name,request_code:row.request_code,review_message:pub},row.request_code);
  else if(!['Đã duyệt'].includes(newStatus)) await dispatchEmail(env,'account_request_status_update',row.email,`Cập nhật hồ sơ ${row.request_code}`,{full_name:row.full_name,request_code:row.request_code,request_status:newStatus,review_message:pub},row.request_code);
  const reviewStatements=[];
  if(newStatus==='Đã kích hoạt tài khoản') {
    // Keep user and request statuses in the same D1 batch; locked/suspended accounts are not silently re-enabled.
    reviewStatements.push(env.DB.prepare(`UPDATE users SET status='active',updated_at=CURRENT_TIMESTAMP WHERE id=? AND status IN ('pending','active')`).bind(approvedUserId));
  }
  reviewStatements.push(
    env.DB.prepare(`UPDATE account_requests SET status=?,assigned_role=COALESCE(?,assigned_role),reviewer_id=?,review_notes_public=?,review_notes_internal=?,approved_user_id=?,reviewed_at=CURRENT_TIMESTAMP,updated_at=CURRENT_TIMESTAMP WHERE id=? AND (?<>'Đã kích hoạt tài khoản' OR EXISTS(SELECT 1 FROM users WHERE id=? AND status='active'))`).bind(newStatus,newStatus==='Đã duyệt'?(ROLES.has(row.requested_role)&&!['super_admin','cms_editor','reviewer'].includes(row.requested_role)?row.requested_role:'member'):null,session.user_id,pub,internal,approvedUserId,requestId,newStatus,approvedUserId),
    env.DB.prepare(`INSERT INTO account_request_history(id,request_id,actor_user_id,old_status,new_status,note_public,note_internal,created_at) SELECT ?,?,?,?,?,?,?,CURRENT_TIMESTAMP WHERE ?<>'Đã kích hoạt tài khoản' OR EXISTS(SELECT 1 FROM users WHERE id=? AND status='active')`).bind(uuid(),requestId,session.user_id,row.status,newStatus,pub,internal,newStatus,approvedUserId)
  );
  const reviewResults=await env.DB.batch(reviewStatements);
  const requestUpdateResult=reviewResults[reviewStatements.length-(newStatus==='Đã kích hoạt tài khoản'?2:1)];
  if(newStatus==='Đã kích hoạt tài khoản'&&Number(requestUpdateResult?.meta?.changes||0)!==1)throw Object.assign(new Error('Không thể đồng bộ trạng thái kích hoạt. Tải lại hồ sơ và kiểm tra trạng thái tài khoản.'),{httpStatus:409});
  await writeAudit(env.DB,request,session.user_id,'ACCOUNT_REQUEST_REVIEWED','account_requests',requestId,{new_status:newStatus,request_code:row.request_code});
  return {ok:true,status:newStatus,email_dispatch_configured:Boolean(env.EMAIL_WEBHOOK_URL&&env.EMAIL_API_KEY),approved_user_id:approvedUserId};
}
async function createExamAttempt(env,request,session,examId) {
  const exam=await env.DB.prepare(`SELECT * FROM exams WHERE id=? AND status='published'`).bind(examId).first();
  if(!exam)throw Object.assign(new Error('Không tìm thấy kỳ thi đang được công bố.'),{httpStatus:404});
  const nowMs=Date.now();const parseTime=s=>s?Date.parse(String(s).includes('Z')?s:String(s).replace(' ','T')+'Z'):null;
  const opens=parseTime(exam.opens_at),closes=parseTime(exam.closes_at);
  if(opens&&nowMs<opens)throw Object.assign(new Error('Kỳ thi chưa đến giờ mở.'),{httpStatus:409});
  if(closes&&nowMs>=closes)throw Object.assign(new Error('Kỳ thi đã đóng.'),{httpStatus:409});
  const existing=await env.DB.prepare(`SELECT id,status FROM exam_attempts WHERE exam_id=? AND user_id=? AND status='in_progress' ORDER BY started_at DESC LIMIT 1`).bind(exam.id,session.user_id).first();
  const attemptId=existing?.id||uuid();
  if(!existing) {
    const versionId=exam.sealed_version_id||null;
    await env.DB.prepare(`INSERT INTO exam_attempts(id,exam_id,user_id,exam_version_id,status,started_at,duration_minutes,extra_time_minutes,time_limit_enabled,question_snapshot_json,answers_json,event_log_json,answer_revision,created_at) VALUES(?,?,?,?,'in_progress',CURRENT_TIMESTAMP,?,0,?,?, '{}','[]',0,CURRENT_TIMESTAMP)`)
      .bind(attemptId,exam.id,session.user_id,versionId,exam.duration_minutes,exam.time_limit_enabled,exam.question_json||'[]').run();
  }
  const raw=randomToken(32),tokenHash=await hashText(raw);
  await env.DB.prepare(`INSERT INTO exam_launch_tokens(token_hash,user_id,attempt_id,expires_at,used_at,created_at) VALUES(?,?,?,datetime('now','+10 minutes'),NULL,CURRENT_TIMESTAMP)`).bind(tokenHash,session.user_id,attemptId).run();
  const launchUrl=`${env.EXAM_PORTAL_URL||SITE.exam}/?launch=${encodeURIComponent(raw)}`;
  await writeAudit(env.DB,request,session.user_id,'EXAM_ATTEMPT_STARTED','exam_attempts',attemptId,{exam_id:exam.id,exam_code:exam.code});
  return {attempt_id:attemptId,launch_url:launchUrl,expires_in_seconds:600};
}
async function getAttemptForUser(env,session,id) {
  const row=await env.DB.prepare(`SELECT a.*,e.title,e.title_en,e.code exam_code,e.show_score,e.result_policy,e.result_release_at,e.closes_at FROM exam_attempts a JOIN exams e ON e.id=a.exam_id WHERE a.id=? AND a.user_id=?`).bind(id,session.user_id).first();
  if(!row)return null;
  const questions=parseJson(row.question_snapshot_json,'[]');
  const safeQuestions=(Array.isArray(questions)?questions:[]).map(q=>{const x={...q};for(const k of ['answer','correct','solution','explanation','rubric','rubric_json','scoring','scoring_config','answer_json'])delete x[k];return x;});
  const receipt=await env.DB.prepare('SELECT receipt_code FROM assessment_receipts WHERE attempt_id=? ORDER BY created_at DESC LIMIT 1').bind(id).first().catch(()=>null);
  const released=!row.result_release_at || Date.parse(row.result_release_at)<=Date.now();
  const showScore=Number(row.show_score)!==0&&released;
  return {id:row.id,exam_id:row.exam_id,exam_code:row.exam_code,title:row.title,title_en:row.title_en,status:row.status,started_at:row.started_at,submitted_at:row.submitted_at,duration_minutes:row.duration_minutes,time_limit_enabled:row.time_limit_enabled,answer_revision:row.answer_revision,questions:safeQuestions,answers:parseJson(row.answers_json,{}),score:showScore?row.score:null,max_score:showScore?row.max_score:null,receipt_code:receipt?.receipt_code||null};
}
async function scoreAndSubmit(env,session,id,answers) {
  const row=await env.DB.prepare(`SELECT a.*,e.title,e.question_json,e.pass_score,e.show_score,e.result_policy,e.result_release_at FROM exam_attempts a JOIN exams e ON e.id=a.exam_id WHERE a.id=? AND a.user_id=?`).bind(id,session.user_id).first();
  if(!row)throw Object.assign(new Error('Không tìm thấy lượt thi.'),{httpStatus:404});
  if(row.status==='submitted')return await getAttemptForUser(env,session,id);
  if(row.status!=='in_progress')throw Object.assign(new Error('Lượt thi không còn hoạt động.'),{httpStatus:409});
  const questions=parseJson(row.question_snapshot_json||row.question_json,'[]');let score=0,max=0,manual=0;
  for(const q of (Array.isArray(questions)?questions:[])) {
    const pts=Math.max(0,Number(q.points||1));max+=pts;const t=str(q.type);if(['essay','long','structured','file','image','audio','math'].includes(t)){manual++;continue;}
    const a=answers?.[q.id],expected=q.answer??q.correct??q.answer_json;
    if(['mcq','truefalse'].includes(t)&&String(a??'')===String(expected??''))score+=pts;
    else if(['fill','short'].includes(t)){let accepted=[];try{accepted=Array.isArray(expected)?expected:JSON.parse(expected)}catch{accepted=String(expected??'').split('|')}if(accepted.some(v=>String(v).trim().toLowerCase()===String(a??'').trim().toLowerCase()))score+=pts;}
    else if(t==='numeric'&&Number.isFinite(Number(a))&&Math.abs(Number(a)-Number(expected))<=Math.max(0,Number(q.numeric_tolerance||q.tolerance||0)))score+=pts;
    else if(t==='multi'){let exp=[];try{exp=Array.isArray(expected)?expected:JSON.parse(expected||'[]')}catch{}const av=Array.isArray(a)?a:[];if(JSON.stringify([...av].map(String).sort())===JSON.stringify([...exp].map(String).sort()))score+=pts;}
  }
  const canScore=manual===0;
  const nextScore=canScore?score:null;const code=`SCRD-${randomToken(6).toUpperCase()}`;
  await env.DB.batch([
    env.DB.prepare(`UPDATE exam_attempts SET status='submitted',submitted_at=CURRENT_TIMESTAMP,last_saved_at=CURRENT_TIMESTAMP,answers_json=?,answer_revision=answer_revision+1,score=?,max_score=? WHERE id=? AND status='in_progress'`).bind(JSON.stringify(answers||{}),nextScore,max,id),
    env.DB.prepare(`INSERT INTO assessment_receipts(id,attempt_id,receipt_code,payload_json,created_at) VALUES(?,?,?,?,CURRENT_TIMESTAMP)`).bind(uuid(),id,code,JSON.stringify({attempt_id:id,exam_id:row.exam_id,status:'submitted'})),
    env.DB.prepare(`INSERT OR REPLACE INTO assessment_result_workflows(attempt_id,source,state,updated_at) VALUES(?,'internal',?,CURRENT_TIMESTAMP)`).bind(id,manual?'awaiting_manual_grading':'scored')
  ]);
  await writeAudit(env.DB,null,session.user_id,'EXAM_ATTEMPT_SUBMITTED','exam_attempts',id,{manual_grading:manual>0});
  return await getAttemptForUser(env,session,id);
}
const HOME_LAYOUT_IDS = ['hero','pillars','programs','assessments','publications','news','partners','cooperation','longform'];
function normalizeHomeLayout(input) {
  if (!Array.isArray(input) || input.length !== HOME_LAYOUT_IDS.length) throw Object.assign(new Error('Bố cục trang chủ phải chứa đầy đủ các khối được hỗ trợ.'), { httpStatus: 400 });
  if (str(input[0]?.id) !== 'hero') throw Object.assign(new Error('Khối Hero phải đứng đầu trang chủ.'), { httpStatus: 400 });
  const seen = new Set();
  const normalized = input.map((item, index) => {
    if (!item || typeof item !== 'object' || !HOME_LAYOUT_IDS.includes(str(item.id)) || seen.has(str(item.id))) throw Object.assign(new Error('Bố cục trang chủ có khối không hợp lệ hoặc bị lặp.'), { httpStatus: 400 });
    const id = str(item.id); seen.add(id);
    return { id, enabled: id === 'hero' ? true : boolInt(item.enabled) === 1, order: index + 1 };
  });
  if (seen.size !== HOME_LAYOUT_IDS.length) throw Object.assign(new Error('Bố cục trang chủ còn thiếu khối bắt buộc.'), { httpStatus: 400 });
  return normalized;
}

async function routeApi(request,env) {
  const url=new URL(request.url),path=url.pathname,method=request.method.toUpperCase();
  if(method==='OPTIONS')return new Response(null,{status:204,headers:{'Access-Control-Allow-Methods':'GET, POST, PUT, PATCH, DELETE, OPTIONS','Access-Control-Allow-Headers':'Content-Type, Authorization, X-Bootstrap-Token, X-CSRF-Token, X-Exam-Session','Access-Control-Max-Age':'86400'}});
  if(path==='/api/health'&&method==='GET') {
    let d1='connected',r2=env.FILES?'configured':'missing';try{await env.DB.prepare('SELECT 1 AS ok').first();}catch{d1='error';}
    return ok({service:SITE.en,domain:SITE.domain,d1_binding:d1,r2_binding:r2,bootstrap_completed:Boolean((await env.DB.prepare('SELECT is_bootstrapped FROM bootstrap_state WHERE id=1').first())?.is_bootstrapped),timestamp:now()},200,request);
  }
  if(path==='/api/bootstrap/status'&&method==='GET'){
    const s=await env.DB.prepare('SELECT is_bootstrapped,bootstrapped_at FROM bootstrap_state WHERE id=1').first();const c=await env.DB.prepare("SELECT COUNT(*) cnt FROM users WHERE role='super_admin'").first();const done=Boolean(s?.is_bootstrapped||Number(c?.cnt)>0);
    return ok({bootstrap_allowed:!done&&Boolean(env.BOOTSTRAP_SECRET_TOKEN),is_completed:done,completed_at:s?.bootstrapped_at||null},200,request);
  }
  if(path==='/api/bootstrap/init'&&method==='POST'){
    const body=await safeBody(request);const secret=env.BOOTSTRAP_SECRET_TOKEN||'';const supplied=request.headers.get('X-Bootstrap-Token')||'';
    if(!secret||!constantEqual(supplied,secret)){await writeAudit(env.DB,request,null,'BOOTSTRAP_INVALID_TOKEN','bootstrap_state','1',{});return fail('Mã khởi tạo không hợp lệ hoặc chưa được cấu hình.',401,request);}
    const email=str(body.email).toLowerCase(),name=cleanText(body.full_name,160),password=str(body.password);
    if(!validEmail(email)||name.length<3||password.length<12)return fail('Cần email hợp lệ, họ tên từ 3 ký tự và mật khẩu tối thiểu 12 ký tự.',400,request);
    const state=await env.DB.prepare('SELECT is_bootstrapped FROM bootstrap_state WHERE id=1').first();const count=await env.DB.prepare("SELECT COUNT(*) cnt FROM users WHERE role='super_admin'").first();
    if(state?.is_bootstrapped||Number(count?.cnt)>0)return fail('Khởi tạo quản trị đã khóa vì hệ thống đã có quản trị viên.',403,request);
    const id=uuid(),hash=await hashPassword(password),sfn=`SFN-${randomToken(6).toUpperCase()}`;
    try {
      const ins=await env.DB.prepare(`INSERT INTO users(id,sfn_id,email,password_hash,password_salt,full_name,role,status,created_at,updated_at) SELECT ?,?,?,?,'',?,'super_admin','active',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP WHERE (SELECT is_bootstrapped FROM bootstrap_state WHERE id=1)=0 AND NOT EXISTS(SELECT 1 FROM users WHERE role='super_admin')`).bind(id,sfn,email,hash,name).run();
      if(Number(ins.meta?.changes||0)!==1)return fail('Khởi tạo quản trị đã được sử dụng hoặc không thể hoàn tất.',409,request);
      await env.DB.prepare(`UPDATE bootstrap_state SET is_bootstrapped=1,bootstrapped_at=CURRENT_TIMESTAMP,bootstrapped_admin_id=?,bootstrap_ip=?,integrity_hash=? WHERE id=1 AND is_bootstrapped=0`).bind(id,requestIp(request),await hashText(`${id}:${email}:${secret}`)).run();
      await writeAudit(env.DB,request,id,'BOOTSTRAP_ADMIN_CREATED','users',id,{email});return ok({message:'Đã khởi tạo quản trị viên đầu tiên. Bootstrap đã khóa.',admin_user:{id,email,full_name:name,role:'super_admin'}},201,request);
    } catch {return fail('Không thể khởi tạo quản trị viên. Kiểm tra email đã được sử dụng chưa.',409,request);}
  }
  if(path==='/api/public/bootstrap-data'&&method==='GET'){
    const data=await loadPublicData(env);return ok(data,200,request);
  }
  if(path==='/api/public/support-tickets'&&method==='POST'){
    if(!await rateLimit(env.DB,`support:${requestIp(request)}`,6,900))return fail('Bạn đã gửi nhiều yêu cầu trong thời gian ngắn. Vui lòng thử lại sau.',429,request);
    const b=await safeBody(request);const name=cleanText(b.sender_name||b.name,160),email=str(b.sender_email||b.email).toLowerCase(),subject=cleanText(b.subject,200),message=cleanText(b.message,5000),category=cleanText(b.category||'general',80);
    if(name.length<2||!validEmail(email)||subject.length<3||message.length<10)return fail('Vui lòng kiểm tra họ tên, email, tiêu đề và nội dung yêu cầu.',400,request);
    const id=uuid(),code=`SFN-SUP-${randomToken(5).toUpperCase()}`;
    await env.DB.prepare(`INSERT INTO support_requests(id,ticket_code,user_id,sender_name,sender_email,subject,category,message,status,created_at,updated_at) VALUES(?,?,NULL,?,?,?,?,?,'open',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)`).bind(id,code,name,email,subject,category,message).run();
    const mail=await dispatchEmail(env,'support_ticket_received',email,`Đã tiếp nhận yêu cầu hỗ trợ ${code}`,{sender_name:name,ticket_code:code,subject,message},code);
    await writeAudit(env.DB,request,null,'SUPPORT_REQUEST_CREATED','support_requests',id,{ticket_code:code});return ok({ticket_code:code,status:'open',message:'Yêu cầu hỗ trợ đã được ghi nhận.',email_dispatch_configured:mail.configured},201,request);
  }
  if(path==='/api/account-requests/upload'&&method==='POST'){
    if(!await rateLimit(env.DB,`anon_upload:${requestIp(request)}`,12,900))return fail('Đã vượt giới hạn tải tệp. Vui lòng thử lại sau.',429,request);
    const fd=await request.formData(),purpose=str(fd.get('purpose')||'supporting_doc');
    if(!['personal_photo','supporting_doc'].includes(purpose))return fail('Bước đăng ký chỉ nhận ảnh chân dung cá nhân và tài liệu minh chứng bổ sung; không tải ảnh giấy tờ định danh vào trường ảnh chân dung.',400,request);
    const uploaded=fd.get('file');
    if(!uploaded||typeof uploaded.arrayBuffer!=='function'||!uploaded.size)return fail('Vui lòng chọn tệp tải lên.',400,request);
    const purposeMaxBytes=purpose==='personal_photo'?8*1024*1024:15*1024*1024;
    if(uploaded.size>purposeMaxBytes)return fail(purpose==='personal_photo'?'Ảnh chân dung không được vượt quá 8 MB.':'Tài liệu minh chứng không được vượt quá 15 MB.',413,request);
    const uploadMime=str(uploaded.type).toLowerCase();
    if(purpose==='personal_photo'&&!['image/jpeg','image/png','image/webp'].includes(uploadMime))return fail('Ảnh chân dung cá nhân chỉ chấp nhận JPEG, PNG hoặc WebP.',415,request);
    // File is kept private and tied to a random staging key until a submitted request claims it.
    const fileData=await validateUploadFile(uploaded);
    const result=await uploadToR2(env,request,{purpose,scope:'identity_private',relatedType:'account_request_staging',relatedId:uuid(),anonymous:true,fileData});
    return ok({id:result.id,r2_key:result.r2_key,original_filename:result.original_filename,mime_type:result.mime_type},201,request);
  }
  if(path==='/api/account-requests'&&method==='POST'){
    if(!await rateLimit(env.DB,`account_request:${requestIp(request)}`,5,3600))return fail('Bạn đã gửi nhiều hồ sơ trong thời gian ngắn. Vui lòng liên hệ bộ phận hỗ trợ nếu cần trợ giúp.',429,request);
    const b=await safeBody(request,400000);
    const full=cleanText(b.full_name,160),email=str(b.email).toLowerCase(),phone=cleanText(b.phone,32),gender=str(b.gender),dob=str(b.date_of_birth),age=calcAge(dob),minor=age!==null&&age<18;
    if(full.length<3||!validEmail(email)||!phone||!['Nam','Nữ','male','female'].includes(gender)||age===null||age<0)return fail('Bước 1: Vui lòng kiểm tra họ tên, email, số điện thoại, giới tính và ngày sinh.',400,request);
    if(minor&&(!cleanText(b.guardian_full_name,160)||!cleanText(b.guardian_relationship,100)||!cleanText(b.guardian_phone,32)||!boolInt(b.guardian_consent)))return fail('Người dưới 18 tuổi cần thông tin và xác nhận đồng ý của người giám hộ.',400,request);
    if(!str(b.education_level)||!str(b.institution_name)||!str(b.current_occupation)||!str(b.major_or_field))return fail('Bước 2: Cần trình độ học vấn, trường/đơn vị, nghề nghiệp và ngành/lĩnh vực.',400,request);
    const group=str(b.applicant_group||'general');
    if(group==='student_school'&&!str(b.class_name))return fail('Học sinh phổ thông cần cung cấp lớp.',400,request);
    if(['student_uni','researcher_lecturer'].includes(group)&&!str(b.faculty_department))return fail('Nhóm đăng ký này cần cung cấp khoa/bộ môn.',400,request);
    if(group==='specialist_staff'&&!str(b.position_title))return fail('Nhân sự/chuyên viên cần cung cấp chức vụ.',400,request);
    const idType=str(b.id_document_type||'CCCD'),idNumber=str(b.id_number).replace(/\s/g,'');
    const issuedDate=str(b.id_issued_date),expiryDate=str(b.id_expiry_date||'');
    const todayIso=new Date().toISOString().slice(0,10);
    const validIdNumber=idType==='CCCD'?/^\d{12}$/.test(idNumber):/^[\p{L}\p{N}./-]{6,64}$/u.test(idNumber);
    if(!['CCCD','Passport','StudentCard','BirthCertificate'].includes(idType)||!validIdNumber||idNumber.length>64||!validDateOnly(issuedDate)||issuedDate>todayIso||!cleanText(b.id_issued_place,200)||(expiryDate&&(!validDateOnly(expiryDate)||expiryDate<issuedDate)))return fail('Bước 3: Thông tin giấy tờ định danh, ngày cấp, nơi cấp hoặc hạn sử dụng không hợp lệ.',400,request);
    if(!str(b.registration_purpose)||str(b.registration_purpose).length<10||!str(b.research_or_project_interest))return fail('Bước 4: Cần mục đích đăng ký và lĩnh vực quan tâm.',400,request);
    if(!boolInt(b.privacy_policy_accepted)||!boolInt(b.terms_accepted)||!boolInt(b.data_accuracy_confirmed))return fail('Bước 5: Cần xác nhận thông báo dữ liệu cá nhân, điều khoản và tính chính xác của dữ liệu.',400,request);
    const signature=str(b.signature_data);if(!signature||!/^data:image\/png;base64,[A-Za-z0-9+/=]{1,350000}$/.test(signature))return fail('Bước 5: Cần ký trực tiếp hoặc tải ảnh chữ ký PNG hợp lệ trước khi gửi hồ sơ.',400,request);
    if(!env.ID_ENCRYPTION_KEY||String(env.ID_ENCRYPTION_KEY).length<32)return fail('Hệ thống chưa cấu hình khóa mã hóa dữ liệu định danh. Hồ sơ chưa được lưu; vui lòng liên hệ hỗ trợ.',503,request);
    const encNumber=await encryptSensitive(idNumber,env.ID_ENCRYPTION_KEY),requestCode=await uniqueRequestCode(env.DB),id=uuid();
    // Do not persist an unsalted SHA-256 hash of a low-entropy government identifier.
    // The field remains nullable for schema compatibility; encrypted ciphertext is the stored identifier.
    const requestedRole=ROLES.has(str(b.requested_role))&&!['super_admin','cms_editor','reviewer'].includes(str(b.requested_role))?str(b.requested_role):'member';
    const keyFields=['personal_photo_r2_key','supporting_doc_r2_key'];
    if(!str(b.personal_photo_r2_key))return fail('Bước 3: Cần tải lên ảnh chân dung cá nhân trước khi gửi hồ sơ.',400,request);
    const expectedPurpose={personal_photo_r2_key:'personal_photo',supporting_doc_r2_key:'supporting_doc'};
    for(const field of keyFields){const key=str(b[field]);if(key){const f=await env.DB.prepare(`SELECT id,purpose,related_entity_type FROM r2_files WHERE r2_key=? AND related_entity_type='account_request_staging'`).bind(key).first();if(!f||f.purpose!==expectedPurpose[field]) return fail('Một tệp đính kèm không hợp lệ hoặc không đúng loại. Vui lòng tải lại tệp.',400,request);}}
    const encSignature=await encryptSensitive(signature,env.ID_ENCRYPTION_KEY);
    await env.DB.prepare(`INSERT INTO account_requests(id,request_code,full_name,email,phone,gender,date_of_birth,calculated_age,is_minor,guardian_full_name,guardian_relationship,guardian_phone,guardian_email,guardian_consent,personal_photo_r2_key,applicant_group,education_level,institution_name,major_or_field,current_occupation,work_unit,class_name,faculty_department,position_title,id_document_type,id_number_encrypted,id_number_hash,id_number_masked,id_issued_date,id_issued_place,id_expiry_date,id_front_r2_key,id_back_r2_key,requested_role,registration_purpose,research_or_project_interest,experience_summary,supporting_doc_r2_key,privacy_policy_accepted,terms_accepted,data_accuracy_confirmed,signature_data,status,submitted_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'Đã tiếp nhận',CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)`)
      .bind(id,requestCode,full,email,phone,gender,dob,age,minor?1:0,minor?cleanText(b.guardian_full_name,160):null,minor?cleanText(b.guardian_relationship,100):null,minor?cleanText(b.guardian_phone,32):null,minor?str(b.guardian_email).toLowerCase()||null:null,minor?1:0,str(b.personal_photo_r2_key)||null,group,cleanText(b.education_level,120),cleanText(b.institution_name,220),cleanText(b.major_or_field,220),cleanText(b.current_occupation,160),cleanText(b.work_unit,220)||null,cleanText(b.class_name,120)||null,cleanText(b.faculty_department,160)||null,cleanText(b.position_title,160)||null,idType,encNumber,null,maskedId(idNumber,idType),str(b.id_issued_date),cleanText(b.id_issued_place,200),str(b.id_expiry_date)||null,null,null,requestedRole,cleanText(b.registration_purpose,4000),cleanText(b.research_or_project_interest,1500),cleanText(b.experience_summary,4000)||null,str(b.supporting_doc_r2_key)||null,1,1,1,encSignature).run();
    for(const field of keyFields){const key=str(b[field]);if(key)await env.DB.prepare(`UPDATE r2_files SET related_entity_type='account_request',related_entity_id=?,purpose=?,access_scope='identity_private' WHERE r2_key=?`).bind(id,field,key).run();}
    await env.DB.prepare(`INSERT INTO account_request_history(id,request_id,actor_user_id,old_status,new_status,note_public,note_internal,created_at) VALUES(?,?,NULL,NULL,'Đã tiếp nhận','Hồ sơ đã được tiếp nhận.','',CURRENT_TIMESTAMP)`).bind(uuid(),id).run();
    const mail=await dispatchEmail(env,'account_request_received',email,`Xác nhận tiếp nhận hồ sơ ${requestCode}`,{full_name:full,request_code:requestCode,status:'Đã tiếp nhận'},requestCode);
    await writeAudit(env.DB,request,null,'ACCOUNT_REQUEST_SUBMITTED','account_requests',id,{request_code:requestCode,applicant_group:group});
    return ok({request_code:requestCode,status:'Đã tiếp nhận',submitted_at:now(),email_dispatch_configured:mail.configured},201,request);
  }
  if(path==='/api/account-requests/lookup'&&method==='POST'){
    if(!await rateLimit(env.DB,`lookup:${requestIp(request)}`,12,900))return fail('Bạn đã thực hiện quá nhiều lần tra cứu. Vui lòng thử lại sau.',429,request);
    const b=await safeBody(request),code=str(b.request_code).toUpperCase(),email=str(b.email).toLowerCase();
    if(!/^SCRD-SFN-\d{10}$/.test(code)||!validEmail(email))return fail('Vui lòng nhập đúng mã hồ sơ và email đăng ký.',400,request);
    const r=await env.DB.prepare(`SELECT request_code,status,review_notes_public,submitted_at,updated_at FROM account_requests WHERE request_code=? AND lower(email)=? LIMIT 1`).bind(code,email).first();
    if(!r)return fail('Không tìm thấy hồ sơ khớp với mã và email đã cung cấp.',404,request);
    const guidance=({ 'Đã tiếp nhận':'Hồ sơ đã được tiếp nhận. Vui lòng theo dõi trạng thái tại đây.','Đang xem xét':'Hồ sơ đang được xem xét. Bạn chưa cần gửi lại hồ sơ.','Cần bổ sung thông tin':r.review_notes_public||'Vui lòng đọc thông báo từ bộ phận xét duyệt và bổ sung theo hướng dẫn.','Đã duyệt':'Hồ sơ đã được duyệt. Vui lòng liên hệ quản trị viên hoặc hotline 0924 910 210 để xác minh danh tính và hoàn tất thiết lập tài khoản.','Từ chối':r.review_notes_public||'Hồ sơ chưa được chấp thuận. Liên hệ hỗ trợ nếu cần làm rõ.','Đã kích hoạt tài khoản':'Tài khoản đã được kích hoạt.'})[r.status]||'Vui lòng theo dõi cập nhật tiếp theo.';
    return ok({request:{request_code:r.request_code,status:r.status,public_review_message:r.review_notes_public||'',submitted_at:r.submitted_at,updated_at:r.updated_at,next_step_guidance:guidance}},200,request);
  }
  if(path==='/api/auth/login'&&method==='POST'){
    if(!await rateLimit(env.DB,`login:${requestIp(request)}`,10,900))return fail('Quá nhiều lần thử đăng nhập. Vui lòng thử lại sau.',429,request);
    const b=await safeBody(request),email=str(b.email).toLowerCase(),password=String(b.password||'');
    if(!validEmail(email)||!password)return fail('Vui lòng nhập email và mật khẩu.',400,request);
    const user=await env.DB.prepare('SELECT * FROM users WHERE email=? COLLATE NOCASE LIMIT 1').bind(email).first();
    const locked=user?.locked_until&&Date.parse(user.locked_until)>Date.now();
    const verified=user&&!locked&&user.status==='active'&&await verifyPassword(password,user.password_hash);
    if(!verified){if(user){const attempts=Number(user.failed_login_attempts||0)+1;const lock=attempts>=8?new Date(Date.now()+15*60*1000).toISOString():null;await env.DB.prepare('UPDATE users SET failed_login_attempts=?,locked_until=?,updated_at=CURRENT_TIMESTAMP WHERE id=?').bind(attempts,lock,user.id).run().catch(()=>{});await writeAudit(env.DB,request,user.id,'AUTH_LOGIN_FAILED','users',user.id,{});}return fail('Thông tin đăng nhập không chính xác hoặc tài khoản chưa được kích hoạt.',401,request);}
    await env.DB.prepare('UPDATE users SET failed_login_attempts=0,locked_until=NULL,last_login_at=CURRENT_TIMESTAMP,updated_at=CURRENT_TIMESTAMP WHERE id=?').bind(user.id).run();
    const session=await createSession(env,request,user);await writeAudit(env.DB,request,user.id,'AUTH_LOGIN_SUCCESS','users',user.id,{});
    return ok({...session,user:publicUser(user)},200,request);
  }
  if(path==='/api/auth/logout'&&method==='POST'){
    const session=await currentSession(request,env);if(session)await env.DB.prepare('UPDATE user_sessions SET revoked=1,revoked_at=CURRENT_TIMESTAMP WHERE session_id=?').bind(session.session_id).run();return ok({},200,request);
  }
  if(path==='/api/auth/me'&&method==='GET'){
    const session=await currentSession(request,env);if(!session)return fail('Phiên đăng nhập đã hết hạn.',401,request);return ok({user:publicUser(session),csrf_token:session.csrf_token},200,request);
  }
  if(path==='/api/auth/change-password'&&method==='POST'){
    const session=await currentSession(request,env);
    if(!session)return fail('Phiên đăng nhập đã hết hạn.',401,request);
    if(!needsCsrf(request,session))return fail('Mã bảo vệ yêu cầu không hợp lệ.',403,request);
    if(!await rateLimit(env.DB,`password-change:${session.user_id}`,8,900))return fail('Quá nhiều lần thử đổi mật khẩu. Vui lòng thử lại sau.',429,request);
    const b=await safeBody(request),currentPassword=String(b.current_password||''),newPassword=String(b.new_password||''),confirmPassword=String(b.confirm_password||'');
    const user=await env.DB.prepare('SELECT id,password_hash,must_change_password FROM users WHERE id=? LIMIT 1').bind(session.user_id).first();
    if(!user||!await verifyPassword(currentPassword,user.password_hash))return fail('Mật khẩu hiện tại không chính xác.',401,request);
    if(newPassword.length<12||newPassword.length>256)return fail('Mật khẩu mới phải có từ 12 đến 256 ký tự.',400,request);
    if(newPassword!==confirmPassword)return fail('Mật khẩu mới và xác nhận không khớp.',400,request);
    if(await verifyPassword(newPassword,user.password_hash))return fail('Mật khẩu mới phải khác mật khẩu hiện tại.',400,request);
    const hashed=await hashPassword(newPassword);
    await env.DB.batch([
      env.DB.prepare("UPDATE users SET password_hash=?,password_salt='',must_change_password=0,failed_login_attempts=0,locked_until=NULL,updated_at=CURRENT_TIMESTAMP WHERE id=?").bind(hashed,session.user_id),
      env.DB.prepare('UPDATE user_sessions SET revoked=1,revoked_at=CURRENT_TIMESTAMP WHERE user_id=? AND session_id<>? AND revoked=0').bind(session.user_id,session.session_id)
    ]);
    await writeAudit(env.DB,request,session.user_id,'AUTH_PASSWORD_CHANGED','users',session.user_id,{forced:Boolean(Number(user.must_change_password||0))});
    return ok({changed:true,must_change_password:false,message:'Đổi mật khẩu thành công. Các phiên đăng nhập khác đã được thu hồi.'},200,request);
  }
  // Password recovery is intentionally handled by the official administrator/hotline workflow.
  // Keep the legacy password_reset_tokens table for non-destructive compatibility, but never issue or accept reset tokens.
  if((path==='/api/auth/forgot-password'||path==='/api/auth/reset-password')&&['POST','GET'].includes(method)){
    return fail('Khôi phục mật khẩu được hỗ trợ trực tiếp bởi quản trị viên. Vui lòng liên hệ quản trị viên hoặc gọi hotline 0924 910 210.',410,request);
  }
  if(path==='/api/profile'&&['PUT','PATCH'].includes(method)){
    const s=await requireSession(request,env),b=await safeBody(request),name=cleanText(b.full_name,160);if(name.length<3)return fail('Họ tên cần ít nhất 3 ký tự.',400,request);
    await env.DB.prepare(`UPDATE users SET full_name=?,organization=?,department=?,academic_title=?,updated_at=CURRENT_TIMESTAMP WHERE id=?`).bind(name,cleanText(b.organization,220),cleanText(b.department,160),cleanText(b.academic_title,160),s.user_id).run();
    const user=await env.DB.prepare('SELECT * FROM users WHERE id=?').bind(s.user_id).first();await writeAudit(env.DB,request,s.user_id,'PROFILE_UPDATED','users',s.user_id,{});return ok({full_name:user.full_name,organization:user.organization,department:user.department,academic_title:user.academic_title},200,request);
  }
  if(path==='/api/profile/avatar'&&method==='POST'){
    const s=await requireSession(request,env),r=await uploadToR2(env,request,{purpose:'avatar',scope:'public',owner:s.user_id,relatedType:'user_avatar',relatedId:s.user_id});
    await env.DB.prepare('UPDATE users SET avatar_r2_key=?,avatar_url=?,updated_at=CURRENT_TIMESTAMP WHERE id=?').bind(r.r2_key,`/api/media/${encodeURIComponent(r.id)}`,s.user_id).run();await writeAudit(env.DB,request,s.user_id,'PROFILE_AVATAR_UPDATED','users',s.user_id,{});return ok({avatar_url:`/api/media/${encodeURIComponent(r.id)}`,r2_key:r.r2_key},201,request);
  }
  // The following routes require an authenticated session unless explicitly public above.
  const protectedPrefixes=['/api/dashboard/','/api/cms/','/api/media/','/api/files/','/api/admin/','/api/research','/api/projects','/api/tasks','/api/chat/','/api/exams/','/api/my/','/api/profile'];
  const publicObjectRead=(method==='GET' && (/^\/api\/media\/[^/]+$/.test(path) || /^\/api\/files\/[^/]+\/download$/.test(path)));
  const isProtected=!publicObjectRead && protectedPrefixes.some(p=>path.startsWith(p));
  let session=null;
  if(isProtected){try{session=await requireSession(request,env);}catch(e){return fail(e.message==='FORBIDDEN'?'Bạn không có quyền thực hiện thao tác này.':e.message==='CSRF_INVALID'?'Mã bảo vệ yêu cầu không hợp lệ.':e.message==='MUST_CHANGE_PASSWORD'?'Tài khoản đang dùng mật khẩu tạm thời. Vui lòng đổi mật khẩu trước khi tiếp tục.':'Bạn cần đăng nhập để thực hiện thao tác này.',e.httpStatus||401,request);}}
  if(path==='/api/dashboard/overview'&&method==='GET'){
    const s=session;
    const [research,projects,tasks,myAttempts,allPosts,allPages,menus,media,requests,rooms]=await Promise.all([
      env.DB.prepare('SELECT id,code,title_vi,title_en,summary_vi,summary_en,status,is_public,progress_percent,lead_user_id FROM research_studies ORDER BY updated_at DESC LIMIT 200').all(),
      env.DB.prepare('SELECT id,code,title_vi,title_en,objective_vi,objective_en,summary_vi,summary_en,status,is_public,progress_percent,manager_user_id FROM community_projects ORDER BY updated_at DESC LIMIT 200').all(),
      env.DB.prepare('SELECT id,parent_type,parent_id,title,description,assignee_user_id,due_date,status,weight,milestone_name,evidence_note,created_by,created_at,updated_at FROM work_tasks WHERE created_by=? OR assignee_user_id=? ORDER BY updated_at DESC LIMIT 300').bind(s.user_id,s.user_id).all(),
      env.DB.prepare(`SELECT a.id,a.exam_id,a.status,a.started_at,a.submitted_at,a.score,a.max_score,e.title exam_title,e.code exam_code,r.receipt_code FROM exam_attempts a JOIN exams e ON e.id=a.exam_id LEFT JOIN assessment_receipts r ON r.attempt_id=a.id WHERE a.user_id=? ORDER BY a.created_at DESC LIMIT 100`).bind(s.user_id).all(),
      CMS_ROLES.has(s.role)?env.DB.prepare('SELECT id,slug,title_vi,title_en,excerpt_vi,excerpt_en,content_vi,content_en,category,tags_json,featured_image_url,featured_media_id,display_author,is_ai_generated,status,seo_title,seo_description,published_at,updated_at FROM cms_posts ORDER BY updated_at DESC LIMIT 300').all():Promise.resolve({results:[]}),
      CMS_ROLES.has(s.role)?env.DB.prepare('SELECT * FROM cms_pages ORDER BY sort_order,updated_at DESC LIMIT 300').all():Promise.resolve({results:[]}),
      CMS_ROLES.has(s.role)?env.DB.prepare('SELECT * FROM cms_menus ORDER BY menu_location,sort_order').all():Promise.resolve({results:[]}),
      CMS_ROLES.has(s.role)?env.DB.prepare(`SELECT id,r2_key,original_filename,mime_type,size_bytes,access_scope,purpose,owner_user_id,created_at FROM r2_files ORDER BY created_at DESC LIMIT 300`).all():Promise.resolve({results:[]}),
      REVIEW_ROLES.has(s.role)?env.DB.prepare(`SELECT id,request_code,full_name,email,phone,gender,date_of_birth,calculated_age,is_minor,guardian_full_name,guardian_relationship,guardian_phone,guardian_email,applicant_group,education_level,institution_name,major_or_field,current_occupation,work_unit,class_name,faculty_department,position_title,id_document_type,id_number_masked,id_issued_date,id_issued_place,id_expiry_date,requested_role,registration_purpose,research_or_project_interest,experience_summary,status,review_notes_public,review_notes_internal,submitted_at,reviewed_at FROM account_requests ORDER BY submitted_at DESC LIMIT 300`).all():Promise.resolve({results:[]}),
      env.DB.prepare(`SELECT r.id,r.room_type,r.name,r.created_by,r.is_private,r.created_at FROM chat_rooms r JOIN chat_room_members m ON m.room_id=r.id WHERE m.user_id=? ORDER BY r.created_at DESC`).bind(s.user_id).all()
    ]);
    const admin={};if(REVIEW_ROLES.has(s.role))admin.account_requests=requests.results||[];
    const cms=CMS_ROLES.has(s.role)?{posts:allPosts.results||[],pages:allPages.results||[],menus:menus.results||[],media:media.results||[]}:{};
    return ok({user:publicUser(s),research_studies:research.results||[],community_projects:projects.results||[],tasks:tasks.results||[],my_exam_attempts:myAttempts.results||[],admin,cms,chat_rooms:rooms.results||[]},200,request);
  }
  // CMS article upsert/delete
  if(path==='/api/cms/posts'&&method==='POST'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền biên tập nội dung.',403,request);const b=await safeBody(request);const id=str(b.id)||uuid(),slug=cleanText(b.slug,180).toLowerCase().replace(/[^a-z0-9\-_/]/g,'-').replace(/-+/g,'-');
    if(!slug||!cleanText(b.title_vi,250))return fail('Cần tiêu đề tiếng Việt và slug hợp lệ.',400,request);const status=validatePostStatus(b.status);
    if(status==='published'&&Boolean(b.is_ai_generated)&&!Boolean(b.explicit_publish))return fail('Bài viết do AI hỗ trợ cần được biên tập viên duyệt rõ ràng trước khi xuất bản.',400,request);
    const values=[id,slug,cleanText(b.custom_path,240)||null,cleanText(b.title_vi,250),cleanText(b.title_en,250),cleanText(b.excerpt_vi,3000),cleanText(b.excerpt_en,3000),sanitizeHtml(b.content_vi),sanitizeHtml(b.content_en),cleanText(b.category,100)||'Tin tức và Hoạt động',JSON.stringify(Array.isArray(b.tags)?b.tags.slice(0,30):parseJson(b.tags_json,'[]')),cleanText(b.featured_image_url,1000)||null,b.featured_media_id||null,cleanText(b.display_author||session.full_name,160),session.user_id,boolInt(b.is_ai_generated),0,status,cleanText(b.seo_title||b.title_vi,250),cleanText(b.seo_description||b.excerpt_vi,500)];
    await env.DB.prepare(`INSERT INTO cms_posts(id,slug,custom_path,title_vi,title_en,excerpt_vi,excerpt_en,content_vi,content_en,category,tags_json,featured_image_url,featured_media_id,display_author,author_id,is_ai_generated,is_locked,status,seo_title,seo_description,published_at,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?, ?,CASE WHEN ?='published' THEN CURRENT_TIMESTAMP ELSE NULL END,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP) ON CONFLICT(id) DO UPDATE SET slug=excluded.slug,custom_path=excluded.custom_path,title_vi=excluded.title_vi,title_en=excluded.title_en,excerpt_vi=excluded.excerpt_vi,excerpt_en=excluded.excerpt_en,content_vi=excluded.content_vi,content_en=excluded.content_en,category=excluded.category,tags_json=excluded.tags_json,featured_image_url=excluded.featured_image_url,featured_media_id=excluded.featured_media_id,display_author=excluded.display_author,is_ai_generated=excluded.is_ai_generated,is_locked=excluded.is_locked,status=excluded.status,seo_title=excluded.seo_title,seo_description=excluded.seo_description,published_at=CASE WHEN excluded.status='published' AND cms_posts.published_at IS NULL THEN CURRENT_TIMESTAMP WHEN excluded.status!='published' THEN NULL ELSE cms_posts.published_at END,updated_at=CURRENT_TIMESTAMP`)
      .bind(...values,status).run();await writeAudit(env.DB,request,session.user_id,'CMS_POST_UPSERT','cms_posts',id,{slug,status,is_ai_generated:Boolean(b.is_ai_generated)});return ok({id,slug,status},200,request);
  }
  const postDelete=path.match(/^\/api\/cms\/posts\/([^/]+)$/);if(postDelete&&method==='DELETE'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền xóa bài viết.',403,request);const id=decodeURIComponent(postDelete[1]);await env.DB.prepare('DELETE FROM cms_posts WHERE id=?').bind(id).run();await writeAudit(env.DB,request,session.user_id,'CMS_POST_DELETED','cms_posts',id,{});return ok({},200,request);
  }
  if(path==='/api/cms/pages'&&method==='POST'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền biên tập trang.',403,request);const b=await safeBody(request),slug=cleanText(b.slug,180).toLowerCase().replace(/[^a-z0-9\-_/]/g,'-');if(!slug||!cleanText(b.title_vi,250)||!cleanText(b.title_en,250))return fail('Cần slug và tiêu đề bằng cả hai ngôn ngữ.',400,request);
    const prev=await env.DB.prepare('SELECT * FROM cms_pages WHERE id=? OR slug=? LIMIT 1').bind(str(b.id)||'__no_such_page_id__',slug).first();const id=str(b.id)||prev?.id||uuid();const version=Number(prev?.version||0)+1;const status=['draft','published','unpublished','archived'].includes(b.status)?b.status:(prev?.status||'draft');
    if(prev){await env.DB.prepare(`INSERT INTO cms_page_revisions(id,page_id,version,title_vi,content_vi,edited_by,edited_at) VALUES(?,?,?,?,?,?,CURRENT_TIMESTAMP)`).bind(uuid(),prev.id,prev.version||1,prev.title_vi,prev.content_vi,session.user_id).run();}
    await env.DB.prepare(`INSERT INTO cms_pages(id,slug,title_vi,title_en,summary_vi,summary_en,content_vi,content_en,page_group,featured_media_id,seo_title_vi,seo_title_en,seo_description_vi,seo_description_en,sort_order,status,version,author_id,published_at,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,CASE WHEN ?='published' THEN CURRENT_TIMESTAMP ELSE NULL END,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP) ON CONFLICT(id) DO UPDATE SET slug=excluded.slug,title_vi=excluded.title_vi,title_en=excluded.title_en,summary_vi=excluded.summary_vi,summary_en=excluded.summary_en,content_vi=excluded.content_vi,content_en=excluded.content_en,page_group=excluded.page_group,seo_title_vi=excluded.seo_title_vi,seo_title_en=excluded.seo_title_en,seo_description_vi=excluded.seo_description_vi,seo_description_en=excluded.seo_description_en,sort_order=excluded.sort_order,status=excluded.status,version=excluded.version,published_at=CASE WHEN excluded.status='published' AND cms_pages.published_at IS NULL THEN CURRENT_TIMESTAMP WHEN excluded.status!='published' THEN NULL ELSE cms_pages.published_at END,updated_at=CURRENT_TIMESTAMP`)
      .bind(id,slug,cleanText(b.title_vi,250),cleanText(b.title_en,250),cleanText(b.summary_vi,3000),cleanText(b.summary_en,3000),sanitizeHtml(b.content_vi),sanitizeHtml(b.content_en),(['home','about','policy','support','cooperation','general'].includes(str(b.page_group))?str(b.page_group):'general'),b.featured_media_id||null,cleanText(b.seo_title_vi||b.title_vi,250),cleanText(b.seo_title_en||b.title_en,250),cleanText(b.seo_description_vi||b.summary_vi,500),cleanText(b.seo_description_en||b.summary_en,500),Number(b.sort_order||0),status,version,session.user_id,status).run();
    await writeAudit(env.DB,request,session.user_id,'CMS_PAGE_UPSERT','cms_pages',id,{slug,status,version});return ok({id,slug,status,version},200,request);
  }
  const pageDelete=path.match(/^\/api\/cms\/pages\/([^/]+)$/);if(pageDelete&&method==='DELETE'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền xóa trang.',403,request);
    const id=decodeURIComponent(pageDelete[1]),row=await env.DB.prepare('SELECT id,slug FROM cms_pages WHERE id=?').bind(id).first();
    if(!row)return fail('Không tìm thấy trang.',404,request);
    const protectedSlugs=new Set(['tong-quan','trang-chu-noi-dung','su-menh-tam-nhin','co-cau-to-chuc','linh-vuc-hoat-dong','lien-he','chinh-sach-bao-ve-du-lieu','dieu-khoan-su-dung','huong-dan-su-dung','ho-tro-nguoi-dung','an-toan-thong-tin']);
    if(protectedSlugs.has(row.slug))return fail('Đây là trang hệ thống. Hãy chuyển sang bản nháp hoặc lưu trữ thay vì xóa.',409,request);
    await env.DB.prepare('DELETE FROM cms_pages WHERE id=?').bind(id).run();
    await writeAudit(env.DB,request,session.user_id,'CMS_PAGE_DELETED','cms_pages',id,{slug:row.slug});return ok({id,slug:row.slug},200,request);
  }
  if(path==='/api/cms/menus'&&method==='POST'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền chỉnh sửa menu.',403,request);const b=await safeBody(request),id=str(b.id)||uuid(),location=str(b.menu_location||'main_header');
    if(!['main_header','footer_col_2','footer_col_3','footer_col_4','footer_bottom'].includes(location)||!safeUrl(b.target_url))return fail('Vị trí hoặc URL menu không hợp lệ.',400,request);
    await env.DB.prepare(`INSERT INTO cms_menus(id,menu_location,parent_id,label_vi,label_en,target_url,link_type,sort_order,is_visible,open_in_new_tab,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP) ON CONFLICT(id) DO UPDATE SET menu_location=excluded.menu_location,parent_id=excluded.parent_id,label_vi=excluded.label_vi,label_en=excluded.label_en,target_url=excluded.target_url,link_type=excluded.link_type,sort_order=excluded.sort_order,is_visible=excluded.is_visible,open_in_new_tab=excluded.open_in_new_tab,updated_at=CURRENT_TIMESTAMP`)
      .bind(id,location,b.parent_id||null,cleanText(b.label_vi,160),cleanText(b.label_en,160),str(b.target_url),String(b.target_url).startsWith('/')?'internal':'external',Number(b.sort_order||0),boolInt(b.is_visible===undefined?true:b.is_visible),boolInt(b.open_in_new_tab)).run();
    await writeAudit(env.DB,request,session.user_id,'CMS_MENU_UPSERT','cms_menus',id,{menu_location:location,target_url:b.target_url});return ok({id},200,request);
  }
  const menuDelete=path.match(/^\/api\/cms\/menus\/([^/]+)$/); if(menuDelete&&method==='DELETE'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền xóa mục menu.',403,request);const id=decodeURIComponent(menuDelete[1]);const row=await env.DB.prepare('SELECT id,menu_location FROM cms_menus WHERE id=?').bind(id).first();if(!row)return fail('Không tìm thấy mục menu.',404,request);if(row.menu_location==='main_header' && id.startsWith('menu_main_'))return fail('Không thể xóa mục menu điều hướng chính chuẩn; hãy ẩn hoặc đổi nhãn/đường dẫn.',409,request);await env.DB.prepare('DELETE FROM cms_menus WHERE id=?').bind(id).run();await writeAudit(env.DB,request,session.user_id,'CMS_MENU_DELETED','cms_menus',id,{menu_location:row.menu_location});return ok({},200,request);
  }
  const redirectDelete=path.match(/^\/api\/cms\/redirects\/(.+)$/); if(redirectDelete&&method==='DELETE'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền xóa chuyển hướng.',403,request);const oldPath='/'+decodeURIComponent(redirectDelete[1]).replace(/^\/+/, '');const row=await env.DB.prepare('SELECT old_path FROM cms_redirects WHERE old_path=?').bind(oldPath).first();if(!row)return fail('Không tìm thấy chuyển hướng.',404,request);await env.DB.prepare('DELETE FROM cms_redirects WHERE old_path=?').bind(oldPath).run();await writeAudit(env.DB,request,session.user_id,'CMS_REDIRECT_DELETED','cms_redirects',oldPath,{});return ok({},200,request);
  }
  if(path==='/api/cms/settings'&&method==='POST'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền chỉnh sửa cài đặt.',403,request);const b=await safeBody(request),settings=b.settings;if(!settings||typeof settings!=='object'||Array.isArray(settings))return fail('Dữ liệu cấu hình không hợp lệ.',400,request);
    const allowed=new Set(Object.keys(DEFAULT_SETTINGS));const normalizedSettings={};
    for(const [key,val] of Object.entries(settings)){
      if(!allowed.has(key))continue;
      let value=typeof val==='string'?cleanText(val,5000):val;
      if(key==='homepage_layout')value=normalizeHomeLayout(val);
      normalizedSettings[key]=value;
    }
    for(const [key,value] of Object.entries(normalizedSettings))await env.DB.prepare(`INSERT INTO system_config(config_key,config_value,is_public,updated_at,updated_by) VALUES(?,?,1,CURRENT_TIMESTAMP,?) ON CONFLICT(config_key) DO UPDATE SET config_value=excluded.config_value,updated_at=CURRENT_TIMESTAMP,updated_by=excluded.updated_by`).bind(key,JSON.stringify(value),session.user_id).run();
    await writeAudit(env.DB,request,session.user_id,'CMS_SETTINGS_UPDATED','system_config','public', {keys:Object.keys(normalizedSettings)});return ok({saved:Object.keys(normalizedSettings)},200,request);
  }
  if(path==='/api/cms/redirects'&&method==='POST'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền quản lý chuyển hướng.',403,request);const b=await safeBody(request),oldPath=str(b.old_path),newPath=str(b.new_path),code=Number(b.status_code||301);
    if(!oldPath.startsWith('/')||oldPath.startsWith('//')||!safeUrl(newPath)||![301,302].includes(code))return fail('Đường dẫn chuyển hướng không hợp lệ.',400,request);
    await env.DB.prepare(`INSERT INTO cms_redirects(id,old_path,new_path,status_code,is_active,created_at) VALUES(?,?,?,?,1,CURRENT_TIMESTAMP) ON CONFLICT(old_path) DO UPDATE SET new_path=excluded.new_path,status_code=excluded.status_code,is_active=1`).bind(uuid(),oldPath,newPath,code).run();await writeAudit(env.DB,request,session.user_id,'CMS_REDIRECT_UPSERT','cms_redirects',oldPath,{new_path:newPath,status_code:code});return ok({old_path:oldPath,new_path:newPath,status_code:code},200,request);
  }
  if(path==='/api/media/upload'&&method==='POST'){
    if(!CMS_ROLES.has(session.role))return fail('Chỉ biên tập viên hoặc quản trị viên được tải media lên.',403,request);const fd=await request.formData(),scope=str(fd.get('visibility')||'public');if(!['public','authenticated','research_team','project_team','admin_only'].includes(scope))return fail('Phạm vi truy cập không hợp lệ.',400,request);
    // Recreate request with form body already read from this request: uploadToR2 must consume the original request,
    // therefore process the file directly here.
    const file=fd.get('file');if(!file||!file.size)return fail('Chưa chọn tệp.',400,request);if(file.size>MAX_UPLOAD||!MIME_EXT.has(str(file.type).toLowerCase()))return fail('Định dạng hoặc dung lượng tệp không được hỗ trợ.',415,request);
    const mime=str(file.type).toLowerCase(),name=safeFilename(file.name,mime),id=uuid(),key=`uploads/${new Date().toISOString().slice(0,10)}/${id}-${name}`;const arrayBuffer=await file.arrayBuffer();
    if(mime==='image/png'&&new Uint8Array(arrayBuffer).slice(0,8).join(',')!=='137,80,78,71,13,10,26,10')return fail('Chữ ký PNG không hợp lệ.',415,request);
    await env.FILES.put(key,arrayBuffer,{httpMetadata:{contentType:mime,cacheControl:scope==='public'?'public, max-age=3600':'private, no-store'},customMetadata:{accessScope:scope,ownerUserId:session.user_id}});
    await env.DB.prepare(`INSERT INTO r2_files(id,r2_key,bucket_name,original_filename,mime_type,size_bytes,sha256_checksum,access_scope,purpose,owner_user_id,created_at) VALUES(?,?,'scrd-files',?,?,?,?,?,'cms_media',?,CURRENT_TIMESTAMP)`).bind(id,key,name,mime,file.size,hex(await crypto.subtle.digest('SHA-256',arrayBuffer)),scope,session.user_id).run();
    await writeAudit(env.DB,request,session.user_id,'MEDIA_UPLOADED','r2_files',id,{mime_type:mime,size_bytes:file.size,access_scope:scope});return ok({id,r2_key:key,original_filename:name,mime_type:mime,size_bytes:file.size,access_scope:scope},201,request);
  }
  const mediaMatch=path.match(/^\/api\/media\/([^/]+)$/);
  if(mediaMatch&&method==='DELETE'){
    if(!CMS_ROLES.has(session.role))return fail('Bạn không có quyền xóa media.',403,request);const id=decodeURIComponent(mediaMatch[1]);const f=await env.DB.prepare('SELECT * FROM r2_files WHERE id=?').bind(id).first();if(!f)return fail('Không tìm thấy tệp.',404,request);await env.FILES.delete(f.r2_key);await env.DB.prepare('DELETE FROM r2_files WHERE id=?').bind(id).run();await writeAudit(env.DB,request,session.user_id,'MEDIA_DELETED','r2_files',id,{});return ok({},200,request);
  }
  if(mediaMatch&&method==='GET'){
    const id=decodeURIComponent(mediaMatch[1]),f=await env.DB.prepare('SELECT * FROM r2_files WHERE id=?').bind(id).first();if(!f)return fail('Không tìm thấy tệp.',404,request);return await fileResponse(request,env,f);
  }
  const fileMatch=path.match(/^\/api\/files\/([^/]+)\/download$/);if(fileMatch&&method==='GET'){
    const id=decodeURIComponent(fileMatch[1]);const f=await env.DB.prepare('SELECT * FROM r2_files WHERE id=?').bind(id).first()||await env.DB.prepare('SELECT id,r2_key,name original_filename,mime mime_type,size size_bytes,visibility access_scope,owner_user_id,created_at FROM files WHERE id=?').bind(id).first();if(!f)return fail('Không tìm thấy tệp.',404,request);return await fileResponse(request,env,f);
  }
  const requestDetailMatch=path.match(/^\/api\/admin\/account-requests\/([^/]+)$/);
  if(requestDetailMatch&&method==='GET'){
    if(!REVIEW_ROLES.has(session.role))return fail('Bạn không có quyền xem hồ sơ đăng ký.',403,request);
    const requestId=decodeURIComponent(requestDetailMatch[1]);
    const row=await env.DB.prepare(`SELECT id,request_code,full_name,email,phone,gender,date_of_birth,calculated_age,is_minor,guardian_full_name,guardian_relationship,applicant_group,education_level,institution_name,major_or_field,current_occupation,work_unit,class_name,faculty_department,position_title,id_document_type,id_number_masked,id_issued_date,id_issued_place,id_expiry_date,registration_purpose,research_or_project_interest,experience_summary,personal_photo_r2_key,signature_data,privacy_policy_accepted,terms_accepted,data_accuracy_confirmed,status,review_notes_public,submitted_at,reviewed_at FROM account_requests WHERE id=? LIMIT 1`).bind(requestId).first();
    if(!row)return fail('Không tìm thấy hồ sơ yêu cầu cấp tài khoản.',404,request);
    let portraitMediaId=null;if(row.personal_photo_r2_key){const media=await env.DB.prepare(`SELECT id FROM r2_files WHERE r2_key=? AND related_entity_type='account_request' AND related_entity_id=? AND access_scope='identity_private' LIMIT 1`).bind(row.personal_photo_r2_key,row.id).first();portraitMediaId=media?.id||null;}
    let signatureData=null;if(row.signature_data){try{signatureData=await decryptSensitive(row.signature_data,env.ID_ENCRYPTION_KEY);}catch(e){return fail('Không thể giải mã chữ ký hồ sơ. Kiểm tra ID_ENCRYPTION_KEY và dữ liệu đã lưu.',e.httpStatus||500,request);}}
    await writeAudit(env.DB,request,session.user_id,'ACCOUNT_REQUEST_DETAIL_VIEWED','account_requests',row.id,{request_code:row.request_code});
    return ok({...row,portrait_media_id:portraitMediaId,signature_data:signatureData},200,request);
  }
  if(path==='/api/admin/users'&&method==='GET'){
    if(session.role!=='super_admin')return fail('Chỉ super admin được quản lý người dùng.',403,request);
    const rows=await env.DB.prepare(`SELECT id,sfn_id,email,full_name,role,status,organization,department,last_login_at,created_at,updated_at FROM users ORDER BY created_at DESC LIMIT 1000`).all();
    return ok({users:rows.results||[]},200,request);
  }
  const adminUserMatch=path.match(/^\/api\/admin\/users\/([^/]+)$/);
  if(adminUserMatch&&method==='PATCH'){
    if(session.role!=='super_admin')return fail('Chỉ super admin được thay đổi tài khoản người dùng.',403,request);
    const userId=decodeURIComponent(adminUserMatch[1]),b=await safeBody(request);
    const existing=await env.DB.prepare(`SELECT id,role,status FROM users WHERE id=? LIMIT 1`).bind(userId).first();if(!existing)return fail('Không tìm thấy tài khoản người dùng.',404,request);
    const role=str(b.role||existing.role),status=str(b.status||existing.status);
    if(!ROLES.has(role))return fail('Vai trò được chọn không hợp lệ.',400,request);
    if(!['active','pending','suspended','locked'].includes(status))return fail('Trạng thái người dùng không hợp lệ.',400,request);
    if(userId===session.user_id&&(role!==existing.role||status!==existing.status))return fail('Không thể tự đổi vai trò hoặc khóa tài khoản đang dùng. Hãy dùng tài khoản super admin khác.',409,request);
    if(existing.role==='super_admin'&&(role!=='super_admin'||status!=='active')){
      const count=await env.DB.prepare(`SELECT COUNT(*) n FROM users WHERE role='super_admin' AND status='active'`).first();
      if(Number(count?.n||0)<=1)return fail('Không thể hạ quyền hoặc khóa super admin cuối cùng đang hoạt động.',409,request);
    }
    await env.DB.prepare(`UPDATE users SET role=?,status=?,updated_at=CURRENT_TIMESTAMP WHERE id=?`).bind(role,status,userId).run();
    if(status!=='active')await env.DB.prepare(`UPDATE user_sessions SET revoked=1,revoked_at=CURRENT_TIMESTAMP WHERE user_id=? AND revoked=0`).bind(userId).run();
    await writeAudit(env.DB,request,session.user_id,'ADMIN_USER_UPDATED','users',userId,{role,status});
    return ok({id:userId,role,status},200,request);
  }
  const adminTempPasswordMatch=path.match(/^\/api\/admin\/users\/([^/]+)\/temporary-password$/);
  if(adminTempPasswordMatch&&method==='POST'){
    if(session.role!=='super_admin')return fail('Chỉ super admin được khởi tạo mật khẩu tạm thời.',403,request);
    const userId=decodeURIComponent(adminTempPasswordMatch[1]);
    if(userId===session.user_id)return fail('Không thể tự cấp mật khẩu tạm cho tài khoản đang dùng. Hãy nhờ một super admin khác thực hiện.',409,request);
    const target=await env.DB.prepare(`SELECT id,full_name,email,status FROM users WHERE id=? LIMIT 1`).bind(userId).first();
    if(!target)return fail('Không tìm thấy tài khoản người dùng.',404,request);
    if(target.status!=='active')return fail('Chỉ cấp mật khẩu tạm thời cho tài khoản đang hoạt động. Hãy xử lý trạng thái tài khoản theo quy trình duyệt trước.',409,request);
    const temporaryPassword=randomToken(12),passwordHash=await hashPassword(temporaryPassword);
    // Do not reactivate pending, suspended, or locked accounts as a side effect of password support.
    const updated=await env.DB.prepare(`UPDATE users SET password_hash=?,password_salt='',must_change_password=1,failed_login_attempts=0,locked_until=NULL,updated_at=CURRENT_TIMESTAMP WHERE id=? AND status='active'`).bind(passwordHash,userId).run();
    if(!Number(updated?.meta?.changes||0))return fail('Trạng thái tài khoản đã thay đổi. Vui lòng tải lại danh sách và kiểm tra trước khi cấp mật khẩu tạm.',409,request);
    await env.DB.prepare(`UPDATE user_sessions SET revoked=1,revoked_at=CURRENT_TIMESTAMP WHERE user_id=? AND revoked=0`).bind(userId).run();
    await writeAudit(env.DB,request,session.user_id,'ADMIN_TEMP_PASSWORD_ISSUED','users',userId,{target_email:target.email});
    return ok({id:userId,full_name:target.full_name,email:target.email,status:'active',must_change_password:true,temporary_password:temporaryPassword,message:'Mật khẩu tạm thời chỉ hiển thị một lần; người dùng phải đổi mật khẩu ngay lần đăng nhập đầu tiên. Xác minh danh tính người nhận qua kênh chính thức trước khi bàn giao.'},200,request);
  }
  if(path==='/api/admin/account-requests/review'&&method==='POST'){
    if(!REVIEW_ROLES.has(session.role))return fail('Bạn không có quyền xét duyệt hồ sơ.',403,request);const b=await safeBody(request);const result=await reviewRequest(env,request,session,b);return ok(result,200,request);
  }
  if(path==='/api/research'&&method==='POST'){
    if(!RESEARCH_ROLES.has(session.role)&&!ADMIN_ROLES.has(session.role))return fail('Bạn không có quyền quản lý nghiên cứu.',403,request);const b=await safeBody(request),id=str(b.id)||uuid(),code=cleanText(b.code||id,80),slug=cleanText(b.slug||code.toLowerCase(),180).toLowerCase().replace(/[^a-z0-9-]/g,'-');
    if(!cleanText(b.title_vi,250)||!cleanText(b.title_en||b.title_vi,250))return fail('Cần tiêu đề nghiên cứu.',400,request);
    await env.DB.prepare(`INSERT INTO research_studies(id,code,slug,title_vi,title_en,field_vi,field_en,summary_vi,summary_en,methodology_vi,methodology_en,findings_summary_vi,findings_summary_en,status,is_public,lead_user_id,progress_percent,start_date,end_date,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP) ON CONFLICT(id) DO UPDATE SET title_vi=excluded.title_vi,title_en=excluded.title_en,field_vi=excluded.field_vi,field_en=excluded.field_en,summary_vi=excluded.summary_vi,summary_en=excluded.summary_en,methodology_vi=excluded.methodology_vi,methodology_en=excluded.methodology_en,findings_summary_vi=excluded.findings_summary_vi,findings_summary_en=excluded.findings_summary_en,status=excluded.status,is_public=excluded.is_public,progress_percent=excluded.progress_percent,updated_at=CURRENT_TIMESTAMP`)
      .bind(id,code,slug,cleanText(b.title_vi,250),cleanText(b.title_en||b.title_vi,250),cleanText(b.field_vi||b.field||'Chưa phân loại',180),cleanText(b.field_en||b.field||'Unclassified',180),cleanText(b.summary_vi||b.objective_vi,5000),cleanText(b.summary_en||b.objective_en||b.summary_vi,5000),sanitizeHtml(b.methodology_vi),sanitizeHtml(b.methodology_en),cleanText(b.findings_summary_vi,5000),cleanText(b.findings_summary_en,5000),cleanText(b.status||'Đề xuất',80),boolInt(b.is_public===undefined?true:b.is_public),session.user_id,Math.min(100,Math.max(0,Number(b.progress_percent||0))),b.start_date||null,b.end_date||null).run();
    await writeAudit(env.DB,request,session.user_id,'RESEARCH_UPSERT','research_studies',id,{code,slug});return ok({id,code,slug},200,request);
  }
  const researchDelete=path.match(/^\/api\/research\/([^/]+)$/);
  if(researchDelete&&method==='DELETE'){
    if(!RESEARCH_ROLES.has(session.role))return fail('Bạn không có quyền xóa đề tài nghiên cứu.',403,request);
    const id=decodeURIComponent(researchDelete[1]),row=await env.DB.prepare('SELECT id,code,title_vi FROM research_studies WHERE id=?').bind(id).first();
    if(!row)return fail('Không tìm thấy đề tài nghiên cứu.',404,request);
    const linked=await env.DB.prepare("SELECT COUNT(*) n FROM work_tasks WHERE parent_type='research' AND parent_id IN (?,?)").bind(row.id,row.code).first();
    if(Number(linked?.n||0)>0)return fail('Không thể xóa đề tài khi còn nhiệm vụ liên kết. Hãy xử lý các nhiệm vụ trước.',409,request);
    await env.DB.prepare('DELETE FROM research_studies WHERE id=?').bind(id).run();
    await writeAudit(env.DB,request,session.user_id,'RESEARCH_DELETED','research_studies',id,{code:row.code});
    return ok({deleted:true,id},200,request);
  }
  if(path==='/api/projects'&&method==='POST'){
    if(!RESEARCH_ROLES.has(session.role)&&!ADMIN_ROLES.has(session.role))return fail('Bạn không có quyền quản lý dự án.',403,request);const b=await safeBody(request),id=str(b.id)||uuid(),code=cleanText(b.code||id,80),slug=cleanText(b.slug||code.toLowerCase(),180).toLowerCase().replace(/[^a-z0-9-]/g,'-');
    if(!cleanText(b.title_vi,250))return fail('Cần tên dự án.',400,request);
    await env.DB.prepare(`INSERT INTO community_projects(id,code,slug,title_vi,title_en,objective_vi,objective_en,summary_vi,summary_en,activities_vi,activities_en,public_evidence_summary,location,status,is_public,manager_user_id,progress_percent,start_date,end_date,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP) ON CONFLICT(id) DO UPDATE SET title_vi=excluded.title_vi,title_en=excluded.title_en,objective_vi=excluded.objective_vi,objective_en=excluded.objective_en,summary_vi=excluded.summary_vi,summary_en=excluded.summary_en,activities_vi=excluded.activities_vi,activities_en=excluded.activities_en,public_evidence_summary=excluded.public_evidence_summary,location=excluded.location,status=excluded.status,is_public=excluded.is_public,progress_percent=excluded.progress_percent,start_date=excluded.start_date,end_date=excluded.end_date,updated_at=CURRENT_TIMESTAMP`)
      .bind(id,code,slug,cleanText(b.title_vi,250),cleanText(b.title_en||b.title_vi,250),cleanText(b.objective_vi||b.summary_vi,3000),cleanText(b.objective_en||b.summary_en||b.summary_vi,3000),cleanText(b.summary_vi,5000),cleanText(b.summary_en||b.summary_vi,5000),sanitizeHtml(b.activities_vi),sanitizeHtml(b.activities_en),cleanText(b.public_evidence_summary,3000),cleanText(b.location,240),(['Chuẩn bị','Đang thực hiện','Hoàn thành','Tạm hoãn'].includes(str(b.status))?str(b.status):'Chuẩn bị'),boolInt(b.is_public===undefined?true:b.is_public),session.user_id,Math.min(100,Math.max(0,Number(b.progress_percent||0))),b.start_date||null,b.end_date||null).run();
    await writeAudit(env.DB,request,session.user_id,'PROJECT_UPSERT','community_projects',id,{code,slug});return ok({id,code,slug},200,request);
  }
  const projectDelete=path.match(/^\/api\/projects\/([^/]+)$/);
  if(projectDelete&&method==='DELETE'){
    if(!RESEARCH_ROLES.has(session.role))return fail('Bạn không có quyền xóa dự án.',403,request);
    const id=decodeURIComponent(projectDelete[1]),row=await env.DB.prepare('SELECT id,code,title_vi FROM community_projects WHERE id=?').bind(id).first();
    if(!row)return fail('Không tìm thấy dự án.',404,request);
    const linked=await env.DB.prepare("SELECT COUNT(*) n FROM work_tasks WHERE parent_type='project' AND parent_id IN (?,?)").bind(row.id,row.code).first();
    if(Number(linked?.n||0)>0)return fail('Không thể xóa dự án khi còn nhiệm vụ liên kết. Hãy xử lý các nhiệm vụ trước.',409,request);
    await env.DB.prepare('DELETE FROM community_projects WHERE id=?').bind(id).run();
    await writeAudit(env.DB,request,session.user_id,'PROJECT_DELETED','community_projects',id,{code:row.code});
    return ok({deleted:true,id},200,request);
  }
  if(path==='/api/tasks'&&method==='POST'){
    if(!RESEARCH_ROLES.has(session.role))return fail('Bạn không có quyền quản lý nhiệm vụ.',403,request);
    const b=await safeBody(request),id=str(b.id)||uuid(),type=str(b.parent_type),parent=str(b.parent_id),title=cleanText(b.title,250),status=['todo','in_progress','review','completed'].includes(b.status)?b.status:'todo';
    if(!['research','project'].includes(type)||!parent||!title)return fail('Loại chương trình, mã chương trình và tên nhiệm vụ là bắt buộc.',400,request);
    const table=type==='research'?'research_studies':'community_projects';
    const parentRow=await env.DB.prepare(`SELECT id,code FROM ${table} WHERE id=? OR code=? LIMIT 1`).bind(parent,parent).first();
    if(!parentRow)return fail('Không tìm thấy đề tài/dự án liên kết. Hãy chọn chương trình đã tồn tại.',404,request);
    const weight=Number(b.weight??1);if(!Number.isFinite(weight)||weight<1||weight>1000)return fail('Trọng số nhiệm vụ phải nằm trong khoảng 1–1000.',400,request);
    await env.DB.prepare(`INSERT INTO work_tasks(id,parent_type,parent_id,title,description,assignee_user_id,due_date,status,weight,milestone_name,evidence_note,created_by,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP) ON CONFLICT(id) DO UPDATE SET parent_type=excluded.parent_type,parent_id=excluded.parent_id,title=excluded.title,description=excluded.description,assignee_user_id=excluded.assignee_user_id,due_date=excluded.due_date,status=excluded.status,weight=excluded.weight,milestone_name=excluded.milestone_name,evidence_note=excluded.evidence_note,updated_at=CURRENT_TIMESTAMP`).bind(id,type,parent,title,cleanText(b.description,3000),b.assignee_user_id||null,b.due_date||null,status,weight,cleanText(b.milestone_name,200),cleanText(b.evidence_note,2000),session.user_id).run();
    const total=await env.DB.prepare('SELECT SUM(weight) total FROM work_tasks WHERE parent_type=? AND parent_id=?').bind(type,parent).first(),done=await env.DB.prepare("SELECT SUM(weight) total FROM work_tasks WHERE parent_type=? AND parent_id=? AND status='completed'").bind(type,parent).first();
    const progress=Number(total?.total)>0?Math.round(Number(done?.total||0)/Number(total.total)*100):0;
    await env.DB.prepare(`UPDATE ${table} SET progress_percent=?,updated_at=CURRENT_TIMESTAMP WHERE id=? OR code=?`).bind(progress,parent,parent).run();
    await env.DB.prepare(`INSERT INTO task_comments_history(id,task_id,user_id,action_type,content,created_at) VALUES(?,?,?,'status_change',?,CURRENT_TIMESTAMP)`).bind(uuid(),id,session.user_id,JSON.stringify({status,weight})).run();
    await writeAudit(env.DB,request,session.user_id,'TASK_UPSERT','work_tasks',id,{parent_type:type,parent_id:parent,status});return ok({id,parent_progress_percent:progress},200,request);
  }
  const taskDelete=path.match(/^\/api\/tasks\/([^/]+)$/);
  if(taskDelete&&method==='DELETE'){
    if(!RESEARCH_ROLES.has(session.role))return fail('Bạn không có quyền xóa nhiệm vụ.',403,request);
    const id=decodeURIComponent(taskDelete[1]),row=await env.DB.prepare('SELECT id,parent_type,parent_id,weight FROM work_tasks WHERE id=?').bind(id).first();
    if(!row)return fail('Không tìm thấy nhiệm vụ.',404,request);
    await env.DB.prepare('DELETE FROM work_tasks WHERE id=?').bind(id).run();
    const table=row.parent_type==='research'?'research_studies':'community_projects';
    const total=await env.DB.prepare('SELECT SUM(weight) total FROM work_tasks WHERE parent_type=? AND parent_id=?').bind(row.parent_type,row.parent_id).first();
    const done=await env.DB.prepare("SELECT SUM(weight) total FROM work_tasks WHERE parent_type=? AND parent_id=? AND status='completed'").bind(row.parent_type,row.parent_id).first();
    const progress=Number(total?.total)>0?Math.round(Number(done?.total||0)/Number(total.total)*100):0;
    await env.DB.prepare(`UPDATE ${table} SET progress_percent=?,updated_at=CURRENT_TIMESTAMP WHERE id=? OR code=?`).bind(progress,row.parent_id,row.parent_id).run();
    await writeAudit(env.DB,request,session.user_id,'TASK_DELETED','work_tasks',id,{parent_type:row.parent_type,parent_id:row.parent_id});
    return ok({deleted:true,id,parent_progress_percent:progress},200,request);
  }
  // Private chat: every listing/read/write is scoped to current membership. Room IDs alone grant no access.
  if(path==='/api/chat/contacts'&&method==='GET'){
    const q=cleanText(new URL(request.url).searchParams.get('q'),100);
    if(q.length<2)return ok({contacts:[]},200,request);
    const escapedQ=q.replace(/[\\%_]/g, ch => `\\${ch}`);const like=`%${escapedQ}%`;
    const rows=await env.DB.prepare(`SELECT id,full_name,sfn_id,role,department FROM users WHERE status='active' AND id<>? AND (full_name LIKE ? ESCAPE '\\' OR sfn_id LIKE ? ESCAPE '\\' OR email LIKE ? ESCAPE '\\') ORDER BY full_name COLLATE NOCASE LIMIT 30`).bind(session.user_id,like,like,like).all();
    return ok({contacts:(rows.results||[]).map(u=>({id:u.id,full_name:u.full_name,sfn_id:u.sfn_id,role:u.role,department:u.department}))},200,request);
  }
  if(path==='/api/chat/rooms'&&method==='GET'){
    const rooms=await env.DB.prepare(`SELECT r.id,r.room_type,CASE WHEN r.room_type='direct' THEN COALESCE((SELECT u.full_name FROM chat_room_members other JOIN users u ON u.id=other.user_id WHERE other.room_id=r.id AND other.user_id<>? LIMIT 1),r.name) ELSE r.name END AS name,r.created_by,r.is_private,r.created_at,(SELECT COUNT(*) FROM chat_room_members cm WHERE cm.room_id=r.id) member_count,(SELECT COUNT(*) FROM chat_messages msg WHERE msg.room_id=r.id) message_count,(SELECT COUNT(*) FROM chat_messages unread WHERE unread.room_id=r.id AND unread.sender_user_id<>? AND unread.is_deleted=0 AND unread.rowid>COALESCE((SELECT read_msg.rowid FROM chat_messages read_msg WHERE read_msg.id=m.last_read_message_id),0)) unread_count FROM chat_rooms r JOIN chat_room_members m ON m.room_id=r.id WHERE m.user_id=? ORDER BY COALESCE((SELECT MAX(created_at) FROM chat_messages WHERE room_id=r.id),r.created_at) DESC LIMIT 200`).bind(session.user_id,session.user_id,session.user_id).all();
    return ok({rooms:rooms.results||[]},200,request);
  }
  if(path==='/api/chat/rooms'&&method==='POST'){
    const b=await safeBody(request),roomType=b.room_type==='direct'?'direct':'group',id=uuid();
    if(roomType==='direct'){
      const targetId=str(b.target_user_id);if(!targetId||targetId===session.user_id)return fail('Vui lòng chọn một người dùng khác để trò chuyện riêng.',400,request);
      const target=await env.DB.prepare(`SELECT id,full_name,status FROM users WHERE id=? LIMIT 1`).bind(targetId).first();
      if(!target||target.status!=='active')return fail('Không tìm thấy tài khoản đang hoạt động để trò chuyện.',404,request);
      const existing=await env.DB.prepare(`SELECT r.id,r.name FROM chat_rooms r JOIN chat_room_members a ON a.room_id=r.id AND a.user_id=? JOIN chat_room_members b ON b.room_id=r.id AND b.user_id=? WHERE r.room_type='direct' AND r.is_private=1 AND (SELECT COUNT(*) FROM chat_room_members m WHERE m.room_id=r.id)=2 ORDER BY r.created_at DESC LIMIT 1`).bind(session.user_id,targetId).first();
      if(existing)return ok({id:existing.id,name:existing.name,reused:true},200,request);
      const name=cleanText(target.full_name,160)||'Trò chuyện riêng';
      await env.DB.batch([
        env.DB.prepare(`INSERT INTO chat_rooms(id,room_type,name,created_by,is_private,created_at) VALUES(?,'direct',?,?,1,CURRENT_TIMESTAMP)`).bind(id,name,session.user_id),
        env.DB.prepare(`INSERT INTO chat_room_members(room_id,user_id,role,is_muted,joined_at) VALUES(?,?,'owner',0,CURRENT_TIMESTAMP)`).bind(id,session.user_id),
        env.DB.prepare(`INSERT INTO chat_room_members(room_id,user_id,role,is_muted,joined_at) VALUES(?,?,'member',0,CURRENT_TIMESTAMP)`).bind(id,targetId)
      ]);
      await writeAudit(env.DB,request,session.user_id,'CHAT_DIRECT_CREATED','chat_rooms',id,{target_user_id:targetId});
      return ok({id,name,target_user_id:targetId},201,request);
    }
    const name=cleanText(b.name,160);if(name.length<2)return fail('Tên nhóm chat cần ít nhất 2 ký tự.',400,request);
    const rawTargetIds=Array.isArray(b.member_user_ids)?[...new Set(b.member_user_ids.map(x=>str(x)).filter(x=>x&&x!==session.user_id))]:[];
    if(rawTargetIds.length>49)return fail('Nhóm chat tối đa 50 thành viên, gồm cả người tạo.',400,request);
    const targetIds=rawTargetIds;
    if(targetIds.length){
      const placeholders=targetIds.map(()=>'?').join(',');
      const valid=await env.DB.prepare(`SELECT id FROM users WHERE status='active' AND id IN (${placeholders})`).bind(...targetIds).all();
      const validIds=(valid.results||[]).map(x=>x.id);
      if(validIds.length!==targetIds.length)return fail('Một hoặc nhiều thành viên không tồn tại hoặc không hoạt động.',400,request);
      const statements=[env.DB.prepare(`INSERT INTO chat_rooms(id,room_type,name,created_by,is_private,created_at) VALUES(?,'group',?,?,1,CURRENT_TIMESTAMP)`).bind(id,name,session.user_id),env.DB.prepare(`INSERT INTO chat_room_members(room_id,user_id,role,is_muted,joined_at) VALUES(?,?,'owner',0,CURRENT_TIMESTAMP)`).bind(id,session.user_id)];
      for(const memberId of validIds)statements.push(env.DB.prepare(`INSERT INTO chat_room_members(room_id,user_id,role,is_muted,joined_at) VALUES(?,?,'member',0,CURRENT_TIMESTAMP)`).bind(id,memberId));
      await env.DB.batch(statements);
    }else{
      await env.DB.batch([
        env.DB.prepare(`INSERT INTO chat_rooms(id,room_type,name,created_by,is_private,created_at) VALUES(?,'group',?,?,1,CURRENT_TIMESTAMP)`).bind(id,name,session.user_id),
        env.DB.prepare(`INSERT INTO chat_room_members(room_id,user_id,role,is_muted,joined_at) VALUES(?,?,'owner',0,CURRENT_TIMESTAMP)`).bind(id,session.user_id)
      ]);
    }
    await writeAudit(env.DB,request,session.user_id,'CHAT_GROUP_CREATED','chat_rooms',id,{member_count:targetIds.length+1});
    return ok({id,name,member_count:targetIds.length+1},201,request);
  }
  const chatMembers=path.match(/^\/api\/chat\/rooms\/([^/]+)\/members$/);
  if(chatMembers&&method==='GET'){
    const roomId=decodeURIComponent(chatMembers[1]);
    const room=await env.DB.prepare(`SELECT room_type FROM chat_rooms WHERE id=? AND is_private=1`).bind(roomId).first();
    const actor=await env.DB.prepare(`SELECT 1 AS member FROM chat_room_members WHERE room_id=? AND user_id=?`).bind(roomId,session.user_id).first();
    if(!room||room.room_type!=='group')return fail('Không tìm thấy nhóm chat.',404,request);
    if(!actor)return fail('Bạn không phải thành viên của nhóm này.',403,request);
    const rows=await env.DB.prepare(`SELECT m.user_id,m.role,m.joined_at,u.full_name,u.sfn_id,u.avatar_url FROM chat_room_members m JOIN users u ON u.id=m.user_id WHERE m.room_id=? ORDER BY CASE m.role WHEN 'owner' THEN 0 WHEN 'moderator' THEN 1 ELSE 2 END,u.full_name COLLATE NOCASE`).bind(roomId).all();
    return ok({members:rows.results||[]},200,request);
  }
  if(chatMembers&&method==='POST'){
    const roomId=decodeURIComponent(chatMembers[1]),b=await safeBody(request),userId=str(b.user_id);
    const actor=await env.DB.prepare(`SELECT role FROM chat_room_members WHERE room_id=? AND user_id=?`).bind(roomId,session.user_id).first();
    const room=await env.DB.prepare(`SELECT room_type FROM chat_rooms WHERE id=? AND is_private=1`).bind(roomId).first();
    if(!actor||!['owner','moderator'].includes(actor.role)||!room||room.room_type!=='group')return fail('Chỉ chủ nhóm hoặc điều phối viên nhóm được thêm thành viên.',403,request);
    if(!userId)return fail('Cần chọn tài khoản cần thêm.',400,request);
    const user=await env.DB.prepare(`SELECT id FROM users WHERE id=? AND status='active'`).bind(userId).first();if(!user)return fail('Không tìm thấy tài khoản đang hoạt động.',404,request);
    const count=await env.DB.prepare(`SELECT COUNT(*) n FROM chat_room_members WHERE room_id=?`).bind(roomId).first();if(Number(count?.n||0)>=50)return fail('Nhóm đã đạt giới hạn 50 thành viên.',409,request);
    await env.DB.prepare(`INSERT OR IGNORE INTO chat_room_members(room_id,user_id,role,is_muted,joined_at) VALUES(?,?,'member',0,CURRENT_TIMESTAMP)`).bind(roomId,userId).run();
    await writeAudit(env.DB,request,session.user_id,'CHAT_MEMBER_ADDED','chat_room_members',roomId,{added_user_id:userId});return ok({room_id:roomId,user_id:userId},200,request);
  }
  const chatMemberDelete=path.match(/^\/api\/chat\/rooms\/([^/]+)\/members\/([^/]+)$/);
  if(chatMemberDelete&&method==='DELETE'){
    const roomId=decodeURIComponent(chatMemberDelete[1]),targetId=decodeURIComponent(chatMemberDelete[2]);
    const room=await env.DB.prepare(`SELECT room_type FROM chat_rooms WHERE id=? AND is_private=1`).bind(roomId).first();
    const actor=await env.DB.prepare(`SELECT role FROM chat_room_members WHERE room_id=? AND user_id=?`).bind(roomId,session.user_id).first();
    const target=await env.DB.prepare(`SELECT role FROM chat_room_members WHERE room_id=? AND user_id=?`).bind(roomId,targetId).first();
    if(!room||room.room_type!=='group')return fail('Chức năng thành viên này chỉ áp dụng cho nhóm chat.',404,request);
    if(!actor||!target)return fail('Không tìm thấy thành viên trong nhóm.',404,request);
    if(!(actor.role==='owner'||(targetId===session.user_id&&target.role!=='owner')))return fail('Chỉ chủ nhóm được xóa thành viên; thành viên có thể tự rời nhóm nếu không phải chủ nhóm.',403,request);
    if(target.role==='owner')return fail('Không thể xóa chủ nhóm hiện tại.',409,request);
    await env.DB.prepare(`DELETE FROM chat_room_members WHERE room_id=? AND user_id=?`).bind(roomId,targetId).run();
    await writeAudit(env.DB,request,session.user_id,'CHAT_MEMBER_REMOVED','chat_room_members',roomId,{removed_user_id:targetId});return ok({room_id:roomId,removed_user_id:targetId},200,request);
  }
  const chatMessages=path.match(/^\/api\/chat\/rooms\/([^/]+)\/messages$/);
  if(chatMessages&&(method==='GET'||method==='POST')){
    const roomId=decodeURIComponent(chatMessages[1]);
    const member=await env.DB.prepare('SELECT room_id FROM chat_room_members WHERE room_id=? AND user_id=?').bind(roomId,session.user_id).first();
    if(!member)return fail('Bạn không phải thành viên của phòng này.',403,request);
    if(method==='GET'){
      const rows=await env.DB.prepare(`SELECT m.id,m.room_id,m.message_text,m.attachment_r2_file_id,m.is_deleted,m.created_at,u.full_name sender_name,f.original_filename attachment_filename,f.mime_type attachment_mime_type,f.size_bytes attachment_size_bytes FROM chat_messages m JOIN users u ON u.id=m.sender_user_id LEFT JOIN r2_files f ON f.id=m.attachment_r2_file_id WHERE m.room_id=? ORDER BY m.created_at DESC,m.rowid DESC LIMIT 200`).bind(roomId).all();
      const messages=(rows.results||[]).reverse().map(m=>({...m,message_text:m.is_deleted?'Tin nhắn đã được thu hồi.':m.message_text,attachment:(!m.is_deleted&&m.attachment_r2_file_id)?{id:m.attachment_r2_file_id,filename:m.attachment_filename||'Tệp đính kèm',mime_type:m.attachment_mime_type||'application/octet-stream',size_bytes:Number(m.attachment_size_bytes||0)}:null}));
      const latestVisible=[...messages].reverse().find(m=>!m.is_deleted);
      if(latestVisible)await env.DB.prepare('UPDATE chat_room_members SET last_read_message_id=? WHERE room_id=? AND user_id=?').bind(latestVisible.id,roomId,session.user_id).run();
      return ok({messages},200,request);
    }
    if(!await rateLimit(env.DB,`chat:${session.user_id}:${roomId}`,60,60))return fail('Bạn đang gửi tin nhắn quá nhanh. Vui lòng chờ một chút.',429,request);
    let message='',attachmentId='',uploadedFile=null;
    const contentType=str(request.headers.get('Content-Type')).toLowerCase();
    if(contentType.includes('multipart/form-data')){
      const fd=await request.formData();
      message=cleanText(fd.get('message_text'),5000);
      const file=fd.get('file');
      if(file&&typeof file.arrayBuffer==='function'&&file.size){
        if(file.size>10*1024*1024)return fail('Tệp đính kèm chat không được vượt quá 10 MB.',413,request);
        const allowedTypes=new Set(['image/jpeg','image/png','image/webp','application/pdf','text/plain']);
        if(!allowedTypes.has(str(file.type).toLowerCase()))return fail('Chat chỉ nhận ảnh JPEG/PNG/WebP, PDF hoặc tệp văn bản thuần.',415,request);
        if(!env.FILES)return fail('Kho tệp R2 chưa được cấu hình.',503,request);
        const fileData=await validateUploadFile(file);
        if(!await rateLimit(env.DB,`chat_upload:${session.user_id}:${roomId}`,10,600))return fail('Bạn tải tệp quá thường xuyên. Vui lòng thử lại sau.',429,request);
        uploadedFile=await uploadToR2(env,request,{purpose:'chat_attachment',scope:'chat_attachment',owner:session.user_id,relatedType:'chat_room',relatedId:roomId,anonymous:false,fileData});
        attachmentId=uploadedFile.id;
      }
    }else{
      const b=await safeBody(request);message=cleanText(b.message_text,5000);attachmentId=str(b.attachment_id);
    }
    if(!message&&!attachmentId)return fail('Nhập nội dung tin nhắn hoặc chọn một tệp đính kèm.',400,request);
    if(attachmentId&&!uploadedFile){
      const attachment=await env.DB.prepare(`SELECT id,owner_user_id,related_entity_type,related_entity_id,purpose,access_scope FROM r2_files WHERE id=? LIMIT 1`).bind(attachmentId).first();
      if(!attachment||attachment.purpose!=='chat_attachment'||attachment.access_scope!=='chat_attachment'||attachment.owner_user_id!==session.user_id||attachment.related_entity_type!=='chat_room'||attachment.related_entity_id!==roomId)return fail('Tệp đính kèm không hợp lệ hoặc không thuộc phòng chat này.',403,request);
      const used=await env.DB.prepare('SELECT 1 AS used FROM chat_messages WHERE attachment_r2_file_id=? LIMIT 1').bind(attachmentId).first();
      if(used)return fail('Tệp đính kèm này đã được gửi trong một tin nhắn khác.',409,request);
    }
    const id=uuid();
    try {
      await env.DB.prepare(`INSERT INTO chat_messages(id,room_id,sender_user_id,message_text,attachment_r2_file_id,is_deleted,created_at) VALUES(?,?,?,?,?,0,CURRENT_TIMESTAMP)`).bind(id,roomId,session.user_id,message,attachmentId||null).run();
    } catch(error) {
      if(uploadedFile){await env.FILES.delete(uploadedFile.r2_key).catch(()=>{});await env.DB.prepare('DELETE FROM r2_files WHERE id=? AND owner_user_id=?').bind(uploadedFile.id,session.user_id).run().catch(()=>{});}
      throw error;
    }
    await writeAudit(env.DB,request,session.user_id,'CHAT_MESSAGE_SENT','chat_rooms',roomId,{message_id:id,has_attachment:Boolean(attachmentId)});
    return ok({id,attachment_id:attachmentId||null},201,request);
  }
  // Exam control endpoints. Exam delivery/save/submit is performed by the dedicated Exam Worker.
  const startMatch=path.match(/^\/api\/exams\/([^/]+)\/start$/);if(startMatch&&method==='POST'){
    try {const result=await createExamAttempt(env,request,session,decodeURIComponent(startMatch[1]));return ok(result,201,request);}catch(e){return fail(e.message,e.httpStatus||500,request);}
  }
  const myAttemptMatch=path.match(/^\/api\/my\/exam-attempts\/([^/]+)(?:\/(save|submit))?$/);if(myAttemptMatch){const id=decodeURIComponent(myAttemptMatch[1]),action=myAttemptMatch[2]||'';
    if(!action&&method==='GET'){const a=await getAttemptForUser(env,session,id);return a?ok({attempt:a},200,request):fail('Không tìm thấy lượt thi.',404,request);}
    if(action==='save'&&method==='POST'){const b=await safeBody(request),row=await env.DB.prepare('SELECT id,status FROM exam_attempts WHERE id=? AND user_id=?').bind(id,session.user_id).first();if(!row)return fail('Không tìm thấy lượt thi.',404,request);if(row.status!=='in_progress')return fail('Lượt thi không còn hoạt động.',409,request);await env.DB.prepare(`UPDATE exam_attempts SET answers_json=?,answer_revision=answer_revision+1,last_saved_at=CURRENT_TIMESTAMP WHERE id=? AND user_id=? AND status='in_progress'`).bind(JSON.stringify(b.answers||{}),id,session.user_id).run();const saved=await env.DB.prepare('SELECT answer_revision FROM exam_attempts WHERE id=?').bind(id).first();return ok({saved:true,answer_revision:saved?.answer_revision||0},200,request);}
    if(action==='submit'&&method==='POST'){const b=await safeBody(request);const result=await scoreAndSubmit(env,session,id,b.answers||{});return ok({attempt:result,score:result?.score??null,max_score:result?.max_score??null,receipt_code:result?.receipt_code??null},200,request);}
  }
  // Exam portal control-plane guest access.
  const publicAssessment=path.match(/^\/api\/public\/assessments\/([^/]+)$/);if(publicAssessment&&method==='GET'){
    const invite=decodeURIComponent(publicAssessment[1]);const exam=await env.DB.prepare(`SELECT id,code,title,title_en,instructions,public_overview_vi,public_overview_en,duration_minutes,opens_at,closes_at,public_access,public_token,require_email_verify,status FROM exams WHERE (code=? OR public_token=?) AND status='published' AND public_access=1 LIMIT 1`).bind(invite,invite).first();if(!exam)return fail('Không tìm thấy kỳ thi hoặc liên kết mời đã hết hiệu lực.',404,request);
    return ok({exam:{id:exam.id,code:exam.code,title:exam.title,title_en:exam.title_en,instructions:exam.instructions,duration_minutes:exam.duration_minutes,schedule:{opens_at:exam.opens_at,closes_at:exam.closes_at},require_email_verify:Boolean(exam.require_email_verify),public_status:'Liên kết mời dự thi'}},200,request);
  }
  const publicStart=path.match(/^\/api\/public\/assessments\/([^/]+)\/start$/);if(publicStart&&method==='POST'){
    if(!await rateLimit(env.DB,`guest_start:${requestIp(request)}`,10,900))return fail('Quá nhiều lượt khởi tạo. Vui lòng thử lại sau.',429,request);const invite=decodeURIComponent(publicStart[1]),b=await safeBody(request);const exam=await env.DB.prepare(`SELECT * FROM exams WHERE (code=? OR public_token=?) AND status='published' AND public_access=1 LIMIT 1`).bind(invite,invite).first();if(!exam)return fail('Kỳ thi không tồn tại hoặc chưa mở cho khách.',404,request);const name=cleanText(b.full_name,160),email=str(b.email).toLowerCase(),candidate=cleanText(b.candidate_code,100),className=cleanText(b.class_name,160);if(name.length<2||!validEmail(email)||!candidate||!className)return fail('Vui lòng nhập đầy đủ thông tin thí sinh.',400,request);if(exam.require_email_verify)return fail('Kỳ thi yêu cầu xác minh email nhưng chưa cấu hình nhà cung cấp OTP. Liên hệ đơn vị tổ chức.',503,request);
    const startMs=exam.opens_at?Date.parse(String(exam.opens_at).replace(' ','T')+'Z'):null,closeMs=exam.closes_at?Date.parse(String(exam.closes_at).replace(' ','T')+'Z'):null;if(startMs&&Date.now()<startMs)return fail('Kỳ thi chưa mở.',409,request);if(closeMs&&Date.now()>=closeMs)return fail('Kỳ thi đã đóng.',409,request);
    const id=uuid(),accessKey=randomToken(32);await env.DB.prepare(`INSERT INTO exam_guest_attempts(id,exam_id,exam_version_id,access_key,full_name,email,candidate_code,class_name,status,started_at,duration_minutes,extra_time_minutes,time_limit_enabled,question_snapshot_json,answers_json,event_log_json,answer_revision,created_at) VALUES(?,?,NULL,?,?, ?,?,'in_progress',CURRENT_TIMESTAMP,?,0,?,?, '{}','[]',0,CURRENT_TIMESTAMP)`).bind(id,exam.id,accessKey,name,email,candidate,className,exam.duration_minutes,exam.time_limit_enabled,exam.question_json||'[]').run();return ok({attempt_id:id,access_key:accessKey},201,request);
  }
  if(path==='/api/public/exam-launch/redeem'&&method==='POST')return fail('Endpoint này thuộc Cổng Khảo thí exam.skyfirst.io.vn, không gọi tại SCRD.',404,request);
  if(path.startsWith('/api/'))return fail('Endpoint API không tồn tại.',404,request);
  return null;
}
export default {
  async fetch(request,env) {
    try {
      if(!env?.DB)return fail('Dịch vụ cơ sở dữ liệu chưa được cấu hình.',503,request);
      const url=new URL(request.url);
      // Apply active canonical redirects before asset routing. Only relative, same-origin paths are stored.
      if(!url.pathname.startsWith('/api/')) { const redirect=await env.DB.prepare('SELECT new_path,status_code FROM cms_redirects WHERE old_path=? AND is_active=1 LIMIT 1').bind(url.pathname).first(); if(redirect && redirect.new_path.startsWith('/') && !redirect.new_path.startsWith('//')) return Response.redirect(new URL(redirect.new_path, url.origin).toString(), Number(redirect.status_code)||301); }
      // Never expose public file objects through static paths; private documents are served only by the guarded API.
      if(url.pathname.startsWith('/api/'))return await routeApi(request,env);
      const response=await env.ASSETS.fetch(request);return response;
    } catch(error) {
      const status=Number(error?.httpStatus)||500;
      if(status>=500){console.error('SCRD worker failure', {route:new URL(request.url).pathname, status, errorType:error?.name||'Error'});if(env?.DEBUG===true)console.error('SCRD local-debug detail',String(error?.message||'').slice(0,300));}
      const message=status===401?'Bạn cần đăng nhập để thực hiện thao tác này.':status===403?'Bạn không có quyền thực hiện thao tác này.':status===409?cleanText(error.message,250):status>=500?'Dịch vụ đang gặp sự cố. Vui lòng thử lại sau hoặc liên hệ hỗ trợ.':cleanText(error?.message||'Yêu cầu không hợp lệ.',250);
      return fail(message,status,request);
    }
  }
};
