import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const html = read('public/index.html');
const app = read('public/app.js');
const css = read('public/styles.css');
const examCss = read('EXAM/public/styles.css');
const migration = read('d1_schema_migration.sql');
const logo = 'public/assets/sky-first-logo-trimmed.webp';

const tests = [
  ['public shell includes a mobile navigation control connected accessibly to the menu', () => {
    assert.match(html, /id="mobileNavToggle"/);
    assert.match(html, /aria-controls="publicMainNav"/);
    assert.match(app, /classList\.toggle\('is-open'\)/);
    assert.match(app, /aria-expanded/);
  }],
  ['public menu contains all required route seeds', () => {
    for (const url of ['/', '/gioi-thieu', '/nghien-cuu-khoa-hoc', '/du-an-cong-dong', '/khao-thi-danh-gia', '/cong-bo-tai-lieu', '/hop-tac-doi-tac', '/tin-tuc-hoat-dong']) {
      assert.ok(migration.includes(`'${url}'`), `Missing required public route ${url}`);
    }
  }],
  ['mobile layout rules reflow navigation, forms, grids and footer', () => {
    assert.match(css, /@media\s*\(max-width:\s*760px\)/);
    assert.match(css, /\.main-nav\.is-open\s*\{\s*display:\s*flex/);
    assert.match(css, /\.grid-2,\s*\.grid-3,\s*\.grid-4\s*\{\s*grid-template-columns:\s*minmax\(0,1fr\)/);
    assert.match(css, /\.footer-grid\s*\{\s*grid-template-columns:\s*minmax\(0,1fr\)/);
  }],
  ['desktop/tablet layouts use fluid grid tracks instead of fixed 360px cards', () => {
    assert.match(css, /\.grid-2\s*\{\s*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)/);
    assert.match(css, /\.grid-3\s*\{\s*grid-template-columns:\s*repeat\(3,\s*minmax\(0,\s*1fr\)\)/);
  }],
  ['navigation links reject javascript/data protocols before rendering', () => {
    assert.match(app, /function getSafeMenuTarget/);
    assert.match(app, /parsed\.protocol === 'https:'/);
    assert.match(app, /parsed\.protocol === 'mailto:'/);
    assert.match(app, /return null;/);
  }],
  ['network errors use branded retry state and do not print backend error details in public UI', () => {
    assert.match(app, /page-state-spinner/);
    assert.match(app, /Retry connection/);
    assert.match(app, /support@skyfirst\.io\.vn/);
    assert.doesNotMatch(app, /<strong>\$\{isVi \? 'Chi tiết:' : 'Details:'\}<\/strong>/);
  }],
  ['Vietnamese and English controls and official support address remain present', () => {
    assert.match(html, /id="btnLangVi"/);
    assert.match(html, /id="btnLangEn"/);
    assert.match(html, /support@skyfirst\.io\.vn/);
    assert.match(app, /localStorage\.setItem\('skyfirst_lang'/);
  }],
  ['official logo asset exists and no generated hero image is required', () => {
    assert.ok(fs.existsSync(path.join(root, logo)));
    assert.match(html, /sky-first-logo-trimmed\.webp/);
    assert.match(css, /\.hero-visual img/);
  }],
  ['Exam portal has responsive UI refinements and reduced-motion support', () => {
    assert.match(examCss, /@media\(max-width:500px\)/);
    assert.match(examCss, /prefers-reduced-motion/);
    assert.match(examCss, /focus-visible/);
  }],
  ['public header removes technical utility bar and account/CMS CTA buttons', () => {
    assert.doesNotMatch(html, /class=\"utility-bar\"/);
    assert.doesNotMatch(html, /headerRegisterBtn|headerPortalBtn/);
    assert.doesNotMatch(app, /utilityBar\.innerHTML|headerRegisterBtn|headerPortalBtn/);
  }],
  ['approved hero title and official Vietnamese/English summaries are in frontend defaults', () => {
    assert.match(app, /NGHIÊN CỨU KHOA HỌC & PHÁT TRIỂN CỘNG ĐỒNG/);
    assert.match(app, /Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững/);
    assert.match(app, /SCIENTIFIC RESEARCH & COMMUNITY DEVELOPMENT/);
    assert.match(app, /Connecting academic knowledge, standardized assessment/);
  }],
  ['registration requires a portrait, visible terms, direct/upload signature and all three confirmations', () => {
    assert.match(app, /Ảnh chân dung cá nhân/);
    assert.doesNotMatch(app, /fileIdFront|fileIdBack/);
    assert.match(app, /Điều khoản đăng ký và sử dụng tài khoản Sky First/);
    assert.match(app, /signatureCanvas/);
    assert.match(app, /fileSignatureImage/);
    assert.match(app, /Vui lòng ký trực tiếp hoặc tải ảnh chữ ký cá nhân trước khi gửi hồ sơ/);
  }],
  ['registration steps and step-five terms/signature have English translations', () => {
    assert.match(app, /localizeRegistrationMarkup/);
    assert.match(app, /Step 1 — Personal information/);
    assert.match(app, /Sky First account registration and use terms/);
    assert.match(app, /I have read, understood and agree to comply with/);
    assert.match(app, /Applicant signature/);
    assert.match(app, /Your account application has been received/);
  }],
  ['forgot password directs to the published hotline instead of token reset flow', () => {
    assert.match(app, /0924 910 210/);
    assert.doesNotMatch(app, /apiFetch\('\/api\/auth\/forgot-password'/);
    assert.doesNotMatch(app, /reset_token=/);
  }],
  ['private chat supports contact search, direct rooms, group members and membership-scoped messages', () => {
    assert.match(app, /api\/chat\/contacts\?q=/);
    assert.match(app, /room_type: 'direct'/);
    assert.match(app, /room_type: 'group'/);
    assert.match(app, /btnAddMembersToRoom/);
    assert.match(app, /data-remove-chat-member/);
  }],
  ['protected admin pages include request detail review and user/role management', () => {
    assert.match(app, /Xem hồ sơ, ảnh chân dung & chữ ký/);
    assert.match(app, /data-dash-tab=\"users\"/);
    assert.match(app, /temporary-password/);
    assert.match(css, /body\.admin-route \.main-nav-wrap/);
  }],
  ['Exam assets use a release-specific cache-busting version and approved SCRD origin', () => {
    const examHtml = read('EXAM/public/index.html');
    const examHeaders = read('EXAM/public/_headers');
    const health = read('EXAM/functions/health.js');
    assert.match(examHtml, /20261022-ultra-repair-r2/);
    assert.match(examHeaders, /https:\/\/scrd\.skyfirst\.io\.vn/);
    assert.doesNotMatch(examHeaders, /slc\.skyfirst\.io\.vn/);
    assert.match(health, /https:\/\/scrd\.skyfirst\.io\.vn\/api\/health/);
    assert.doesNotMatch(health, /slc\.skyfirst\.io\.vn/);
  }],
  ['temporary-password flow has forced-change screen, endpoint and schema migration', () => {
    assert.match(app, /renderForcePasswordChangeView/);
    assert.match(app, /path === '\/doi-mat-khau'/);
    assert.match(app, /api\/auth\/change-password/);
    assert.match(read('backend_worker.js'), /must_change_password=1/);
    assert.match(read('migrations/0005_temporary_password_guard.sql'), /ALTER TABLE users ADD COLUMN must_change_password/);
  }],
  ['chat file sharing is submitted with the message and server checks member-scoped media access', () => {
    assert.match(app, /id=\"inpChatAttachment\"/);
    assert.match(app, /form.set\('file',selectedFile\)/);
    assert.match(app, /data-download-chat-file/);
    assert.match(read('backend_worker.js'), /scope==='chat_attachment'&&session/);
    assert.match(read('backend_worker.js'), /chat_messages cm JOIN chat_room_members rm/);
    assert.match(read('backend_worker.js'), /related_entity_id!==roomId/);
  }],
  ['hero supporting descriptions render independently and are editable through CMS settings', () => {
    assert.match(app, /class=\"hero-description\"/);
    assert.match(app, /hero_description_vi/);
    assert.match(app, /hero_description_en/);
    assert.match(app, /id=\"setHeroDescVi\"/);
    assert.match(app, /id=\"setHeroDescEn\"/);
    assert.match(read('migrations/0006_hero_description_split.sql'), /hero_description_vi/);
    assert.match(read('migrations/0006_hero_description_split.sql'), /hero_description_en/);
  }],
  ['admin settings deep link routes to CMS settings and keeps authentication/role checks', () => {
    assert.match(app, /path === '\/admin\/settings'/);
    assert.match(app, /You do not have permission to access CMS settings/);
    assert.match(app, /activeDashboardTab = 'cms_menus'/);
    assert.match(app, /401 — Yêu cầu xác thực/);
  }],
  ['temporary password UI does not claim to activate an account', () => {
    assert.doesNotMatch(app, /Tạo mật khẩu tạm mới, kích hoạt tài khoản/);
    assert.match(app, /Chỉ áp dụng cho tài khoản đang hoạt động/);
    assert.match(read('backend_worker.js'), /Chỉ cấp mật khẩu tạm thời cho tài khoản đang hoạt động/);
  }],
  ['registration preview includes the portrait in Step 3 and the full review in Step 5', () => {
    assert.match(app, /personalPhotoPreviewWrap/);
    assert.match(app, /personal_photo_preview_data_url/);
    assert.match(app, /registration-review-photo/);
    for (const label of ['Ngày \/ nơi cấp:', 'Hạn sử dụng:', 'Lĩnh vực quan tâm:', 'Mục đích xin cấp tài khoản:']) assert.ok(app.includes(label), `Step 5 review misses ${label}`);
  }],
  ['registration submits an explicit allowlist and does not transmit local preview/legacy ID photo keys', () => {
    assert.match(app, /const payloadKeys = \[/);
    assert.match(app, /JSON\.stringify\(submission\)/);
    assert.doesNotMatch(app, /JSON\.stringify\(d\)/);
    assert.doesNotMatch(app, /id_front_r2_key|id_back_r2_key/);
  }],
  ['starting a second account application resets the previous applicant data and signature', () => {
    assert.match(app, /AppState\.regDraft = createEmptyRegDraft\(\)/);
    assert.match(app, /function createEmptyRegDraft\(\)/);
  }],
  ['applicant-facing terms do not contain internal implementation notes', () => {
    assert.match(app, /Điều khoản đăng ký và sử dụng tài khoản Sky First/);
    const termsNote = app.match(/<p class="registration-terms-note">([\s\S]*?)<\/p>/)?.[1] || '';
    assert.ok(termsNote, 'applicant should have a visible link to full terms and privacy notice');
    assert.doesNotMatch(termsNote, /Nội dung điều khoản chính thức cần được Trung tâm phê duyệt/);
  }],
  ['homepage includes data-driven assessment, verified publication and verified partner blocks', () => {
    assert.match(app, /data-home-block="assessments"/);
    assert.match(app, /data-home-block="publications"/);
    assert.match(app, /data-home-block="partners"/);
    assert.match(app, /No verified publications are available for public display yet/);
    assert.match(app, /Unverified logos or partnerships are not displayed/);
  }],
  ['CMS includes a persisted homepage layout manager with ordering and visibility controls', () => {
    assert.match(app, /data-dash-tab="cms_home_layout"/);
    assert.match(app, /data-layout-move="up"/);
    assert.match(app, /data-layout-enabled/);
    assert.match(app, /btnSaveHomeLayout/);
    assert.match(app, /settings:\{homepage_layout:normalized\}/);
    assert.match(css, /\.home-layout-row/);
    assert.match(read('backend_worker.js'), /function normalizeHomeLayout/);
  }],
  ['research, project and task admin UI provides edit/delete actions and safe task fields', () => {
    assert.match(app, /data-edit-program=/);
    assert.match(app, /data-delete-program=/);
    assert.match(app, /data-edit-task=/);
    assert.match(app, /data-delete-task=/);
    assert.match(app, /id="tkDueDate"/);
    assert.match(read('backend_worker.js'), /const taskDelete=path\.match/);
    assert.match(read('backend_worker.js'), /Không thể xóa đề tài khi còn nhiệm vụ liên kết/);
  }]
];

let passed = 0;
for (const [name, run] of tests) {
  run();
  passed++;
  console.log(`PASS UI ${passed}: ${name}`);
}
console.log(`UI REGRESSION: ${passed}/${tests.length} PASS`);
