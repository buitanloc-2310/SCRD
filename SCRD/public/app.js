/**
 * TRUNG TÂM NGHIÊN CỨU VÀ PHÁT TRIỂN CỘNG ĐỒNG SKY FIRST
 * SKY FIRST CENTER FOR RESEARCH AND DEVELOPMENT
 * Frontend Application Controller (100% Real Backend API Integration)
 */

const I18N = {
  vi: {
    support_label: 'Email hỗ trợ chính thức:',
    util_track: 'Tra cứu yêu cầu',
    util_register: 'Yêu cầu cấp tài khoản',
    util_forgot: 'Quên mật khẩu',
    util_login: 'Đăng nhập',
    util_dashboard: 'Bảng điều khiển',
    util_logout: 'Đăng xuất',
    footer_col2: 'Về Trung tâm',
    footer_col3: 'Kết nối Sky First',
    footer_col4: 'Tài khoản Trung tâm',
    loading: 'Đang tải dữ liệu từ hệ thống...',
    empty_research: 'Hiện chưa có đề tài nghiên cứu nào được công bố công khai. Vui lòng quay lại sau hoặc liên hệ support@skyfirst.io.vn.',
    empty_projects: 'Hiện chưa có dự án cộng đồng nào được công bố công khai. Vui lòng quay lại sau hoặc liên hệ support@skyfirst.io.vn.',
    empty_pubs: 'Thư viện hiện chưa có tài liệu công bố công khai.',
    empty_exams: 'Hiện chưa có kỳ khảo thí nào đang mở công khai.',
    empty_partners: 'Danh sách đối tác chính thức đang trong quá trình rà soát và xác nhận văn bản pháp lý theo quy chuẩn minh bạch của Trung tâm.',
    empty_posts: 'Chưa có bài viết tin tức nào được xuất bản.'
  },
  en: {
    support_label: 'Official Support Email:',
    util_track: 'Track Request',
    util_register: 'Request Account',
    util_forgot: 'Forgot Password',
    util_login: 'Sign In',
    util_dashboard: 'Dashboard',
    util_logout: 'Sign Out',
    footer_col2: 'About the Center',
    footer_col3: 'Sky First Network',
    footer_col4: 'Center Account',
    loading: 'Loading data from server...',
    empty_research: 'No public research studies have been published yet. Please check back later or contact support@skyfirst.io.vn.',
    empty_projects: 'No public community projects have been published yet. Please check back later or contact support@skyfirst.io.vn.',
    empty_pubs: 'No public publications are currently available in the repository.',
    empty_exams: 'No public academic assessments are currently open.',
    empty_partners: 'Official partner listings are currently under formal verification in accordance with the Center transparency standards.',
    empty_posts: 'No news articles have been published yet.'
  }
};

export const AppState = {
  lang: localStorage.getItem('skyfirst_lang') === 'en' ? 'en' : 'vi',
  currentPath: window.location.pathname || '/',
  currentQuery: new URLSearchParams(window.location.search),
  loading: true,
  loadError: null,
  bootstrapStatus: { bootstrap_allowed: false, is_completed: true },
  token: sessionStorage.getItem('skyfirst_token') || '',
  csrfToken: sessionStorage.getItem('skyfirst_csrf') || '',
  currentUser: null, // Strictly null until authenticated by backend
  settings: {
    site_name_vi: 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First',
    site_name_en: 'Sky First Center for Research and Development',
    site_domain: 'https://scrd.skyfirst.io.vn',
    exam_portal_url: 'https://exam.skyfirst.io.vn',
    support_email: 'support@skyfirst.io.vn',
    hero_eyebrow_vi: 'TRUNG TÂM NGHIÊN CỨU VÀ PHÁT TRIỂN CỘNG ĐỒNG SKY FIRST',
    hero_eyebrow_en: 'SKY FIRST CENTER FOR RESEARCH AND DEVELOPMENT',
    hero_title_vi: 'NGHIÊN CỨU KHOA HỌC & PHÁT TRIỂN CỘNG ĐỒNG',
    hero_title_en: 'SCIENTIFIC RESEARCH & COMMUNITY DEVELOPMENT',
    hero_subtitle_vi: 'Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững. Nền tảng chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
    hero_subtitle_en: 'Connecting academic knowledge, standardized assessment, and sustainable community initiatives. The official platform of Sky First Center for Research and Development.',
    copyright_vi: '© Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
    copyright_en: '© Sky First Center for Research and Development.'
  },
  menus: [],
  redirects: [],
  pages: [],
  posts: [],
  researchStudies: [],
  communityProjects: [],
  publications: [],
  exams: [],
  partners: [],
  dashboardData: null,
  activeDashboardTab: 'overview',
  activeExamAttempt: null,
  chatRooms: [],
  activeChatRoomId: null,
  activeChatMessages: [],
  regDraft: {
    step: 1,
    full_name: '',
    email: '',
    phone: '',
    gender: 'Nam',
    date_of_birth: '',
    guardian_full_name: '',
    guardian_relationship: '',
    guardian_phone: '',
    guardian_email: '',
    guardian_consent: false,
    applicant_group: 'student_uni',
    education_level: 'Đại học',
    institution_name: '',
    major_or_field: '',
    current_occupation: 'Sinh viên',
    work_unit: '',
    class_name: '',
    faculty_department: '',
    position_title: '',
    id_document_type: 'CCCD',
    id_number: '',
    id_issued_date: '',
    id_issued_place: '',
    id_expiry_date: '',
    personal_photo_r2_key: '',
    personal_photo_name: '',
    id_front_r2_key: '',
    id_front_name: '',
    id_back_r2_key: '',
    id_back_name: '',
    requested_role: 'member',
    registration_purpose: '',
    research_or_project_interest: '',
    experience_summary: '',
    supporting_doc_r2_key: '',
    supporting_doc_name: '',
    privacy_policy_accepted: false,
    terms_accepted: false,
    data_accuracy_confirmed: false,
    signature_data: '',
    signature_method: '',
    submittedResult: null
  }
};

export function esc(val) {
  return String(val ?? '').replace(/[&<>"']/g, ch => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  }[ch]));
}

/** Render CMS-authored rich text without executing script, event handlers, or unsafe URLs. */
export function safeRichHtml(value) {
  const template = document.createElement('template');
  template.innerHTML = String(value ?? '').slice(0, 200000);
  const allowedTags = new Set(['P','BR','H2','H3','H4','UL','OL','LI','STRONG','B','EM','I','U','BLOCKQUOTE','A','CODE','PRE','TABLE','THEAD','TBODY','TR','TH','TD','HR','IMG','FIGURE','FIGCAPTION']);
  const removedTags = new Set(['SCRIPT','STYLE','IFRAME','OBJECT','EMBED','FORM','INPUT','BUTTON','TEXTAREA','SELECT','OPTION','SVG','MATH','META','BASE','LINK','VIDEO','AUDIO','SOURCE']);
  const allowedAttrs = new Set(['href','src','alt','title','target','rel','loading','colspan','rowspan','scope']);
  const walk = node => {
    for (const child of [...node.childNodes]) {
      if (child.nodeType !== Node.ELEMENT_NODE) continue;
      const tag = child.tagName.toUpperCase();
      if (removedTags.has(tag)) { child.remove(); continue; }
      if (!allowedTags.has(tag)) {
        child.replaceWith(...child.childNodes);
        continue;
      }
      for (const attr of [...child.attributes]) {
        const name = attr.name.toLowerCase();
        if (!allowedAttrs.has(name)) { child.removeAttribute(attr.name); continue; }
        if ((name === 'href' || name === 'src') && !safeRichUrl(attr.value, name === 'src')) { child.removeAttribute(attr.name); continue; }
      }
      if (tag === 'A' && child.getAttribute('target') === '_blank') child.setAttribute('rel', 'noopener noreferrer');
      if (tag === 'IMG') { child.setAttribute('loading','lazy'); child.setAttribute('referrerpolicy','no-referrer'); }
      walk(child);
    }
  };
  walk(template.content);
  return template.innerHTML;
}

function safeRichUrl(value, isImage = false) {
  const v = String(value || '').trim();
  if (!v || v.startsWith('//') || /^[\u0000-\u0020]*javascript:/i.test(v) || /^[\u0000-\u0020]*data:/i.test(v) || /^[\u0000-\u0020]*vbscript:/i.test(v)) return false;
  if (v.startsWith('/') || v.startsWith('#')) return !isImage || v.startsWith('/');
  try { const u = new URL(v, window.location.origin); return ['https:','http:'].includes(u.protocol) && (!isImage || u.origin === window.location.origin || u.protocol === 'https:'); } catch { return false; }
}

export function showToast(message, isError = false) {
  const wrap = document.getElementById('toastContainer');
  if (!wrap) return;
  const el = document.createElement('div');
  el.className = `toast ${isError ? 'toast-error' : ''}`;
  el.textContent = message;
  wrap.appendChild(el);
  setTimeout(() => el.remove(), 4500);
}

export async function apiFetch(path, options = {}) {
  const headers = new Headers(options.headers || {});
  if (AppState.token) {
    headers.set('Authorization', `Bearer ${AppState.token}`);
  }
  if (AppState.csrfToken) {
    headers.set('X-CSRF-Token', AppState.csrfToken);
  }
  if (options.body && !(options.body instanceof FormData) && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  let response;
  try {
    response = await fetch(path, {
      ...options,
      headers,
      cache: 'no-store'
    });
  } catch (networkErr) {
    const err = new Error('Không thể kết nối tới máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.');
    err.status = 0;
    err.network = true;
    throw err;
  }

  let data = null;
  const contentType = response.headers.get('Content-Type') || '';
  if (contentType.includes('application/json')) {
    data = await response.json().catch(() => null);
  }

  if (!response.ok || (data && data.ok === false)) {
    const errMsg = data?.error || data?.message || `Yêu cầu thất bại (HTTP ${response.status}).`;
    const err = new Error(errMsg);
    err.status = response.status;
    err.field = data?.field || null;
    err.data = data;
    throw err;
  }

  return data;
}

export function calculateAgeFromDob(dobStr) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(dobStr || '').trim())) return null;
  const [y, m, d] = dobStr.split('-').map(Number);
  const dob = new Date(Date.UTC(y, m - 1, d));
  if (dob.getUTCFullYear() !== y || dob.getUTCMonth() !== m - 1 || dob.getUTCDate() !== d || y < 1900) return null;
  const now = new Date();
  const todayUtc = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
  if (dob.getTime() > todayUtc) return -1;
  let age = now.getUTCFullYear() - y;
  const mDiff = (now.getUTCMonth() + 1) - m;
  if (mDiff < 0 || (mDiff === 0 && now.getUTCDate() < d)) age--;
  return age;
}

export async function loadInitialData() {
  AppState.loading = true;
  AppState.loadError = null;
  try {
    const [pubData, bootStatus] = await Promise.all([
      apiFetch('/api/public/bootstrap-data'),
      apiFetch('/api/bootstrap/status').catch(() => ({ bootstrap_allowed: false, is_completed: true }))
    ]);
    if (pubData.settings && Object.keys(pubData.settings).length > 0) {
      AppState.settings = { ...AppState.settings, ...pubData.settings };
    }
    // Migrate only known legacy defaults in memory; preserve any deliberate CMS-authored values.
    if (!AppState.settings.hero_title_vi || AppState.settings.hero_title_vi === 'Hệ sinh thái Nghiên cứu Khoa học, Khảo thí Học thuật và Phát triển Cộng đồng') {
      AppState.settings.hero_title_vi = 'NGHIÊN CỨU KHOA HỌC & PHÁT TRIỂN CỘNG ĐỒNG';
    }
    if (!AppState.settings.hero_title_en || AppState.settings.hero_title_en === 'Ecosystem for Scientific Research, Academic Assessment and Community Development') {
      AppState.settings.hero_title_en = 'SCIENTIFIC RESEARCH & COMMUNITY DEVELOPMENT';
    }
    // Keep the eyebrow as the Center identity; the approved scientific/community headline belongs in hero_title_vi.
    // Keep the English eyebrow as the Center identity; the approved headline belongs in hero_title_en.
    if (AppState.settings.hero_subtitle_vi === 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First xây dựng nền tảng tri thức chuẩn mực, thúc đẩy các chương trình nghiên cứu ứng dụng, khảo thí minh bạch và dự án phục vụ cộng đồng bền vững.') {
      AppState.settings.hero_subtitle_vi = 'Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững. Nền tảng chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.';
    }
    if (AppState.settings.hero_subtitle_en === 'Sky First Center for Research and Development builds a rigorous knowledge platform, advancing applied research, transparent academic assessment, and sustainable community initiatives.') {
      AppState.settings.hero_subtitle_en = 'Connecting academic knowledge, standardized assessment, and sustainable community initiatives. The official platform of Sky First Center for Research and Development.';
    }
    AppState.menus = pubData.menus || [];
    AppState.redirects = pubData.redirects || [];
    AppState.pages = pubData.pages || [];
    AppState.posts = pubData.posts || [];
    AppState.researchStudies = pubData.research_studies || [];
    AppState.communityProjects = pubData.community_projects || [];
    AppState.publications = pubData.publications || [];
    AppState.exams = pubData.exams || [];
    AppState.partners = pubData.partners || [];
    AppState.bootstrapStatus = bootStatus;

    if (AppState.token) {
      try {
        const me = await apiFetch('/api/auth/me');
        AppState.currentUser = me.user;
      } catch {
        clearAuthSession();
      }
    }
  } catch (err) {
    AppState.loadError = err.message;
  } finally {
    AppState.loading = false;
  }
}

function clearAuthSession() {
  AppState.token = '';
  AppState.csrfToken = '';
  AppState.currentUser = null;
  AppState.dashboardData = null;
  sessionStorage.removeItem('skyfirst_token');
  sessionStorage.removeItem('skyfirst_csrf');
}

function closeMobileNavigation() {
  const nav = document.getElementById('publicMainNav');
  const toggle = document.getElementById('mobileNavToggle');
  nav?.classList.remove('is-open');
  toggle?.setAttribute('aria-expanded', 'false');
  if (toggle) {
    toggle.setAttribute('aria-label', AppState.lang === 'vi' ? 'Mở menu điều hướng' : 'Open navigation menu');
    const icon = toggle.querySelector('.mobile-nav-toggle-icon');
    if (icon) icon.textContent = '☰';
    const label = toggle.querySelector('.mobile-nav-toggle-label');
    if (label) label.textContent = AppState.lang === 'vi' ? 'Menu' : 'Menu';
  }
}

export function navigateTo(urlStr, replace = false) {
  closeMobileNavigation();
  const parsed = new URL(urlStr, window.location.origin);
  // Check CMS Redirects
  const redirectMatch = AppState.redirects.find(r => r.old_path === parsed.pathname);
  const targetUrl = redirectMatch ? redirectMatch.new_path : (parsed.pathname + parsed.search);

  if (replace) {
    window.history.replaceState({}, '', targetUrl);
  } else if (window.location.pathname + window.location.search !== targetUrl) {
    window.history.pushState({}, '', targetUrl);
  }
  AppState.currentPath = window.location.pathname;
  AppState.currentQuery = new URLSearchParams(window.location.search);
  renderShell();
  renderRoute();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

export function setLanguage(lang) {
  AppState.lang = lang === 'en' ? 'en' : 'vi';
  closeMobileNavigation();
  try { localStorage.setItem('skyfirst_lang', AppState.lang); } catch {}
  document.documentElement.lang = AppState.lang;
  renderShell();
  renderRoute();
}

function updateDocumentMetadata(path, isVi) {
  const siteVi = AppState.settings.site_name_vi || 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First';
  const siteEn = AppState.settings.site_name_en || 'Sky First Center for Research and Development';
  let title = isVi ? siteVi : siteEn;
  let description = isVi
    ? 'Cổng thông tin về nghiên cứu khoa học ứng dụng, phát triển cộng đồng, khảo thí học thuật và công bố tri thức của Sky First.'
    : 'Information on applied scientific research, community development, academic assessment, and knowledge resources from Sky First.';
  const directPolicySlugs = {'/chinh-sach-bao-mat':'chinh-sach-bao-ve-du-lieu','/dieu-khoan-su-dung':'dieu-khoan-su-dung','/an-toan-thong-tin':'an-toan-thong-tin'};
  if (path === '/') {
    const home = AppState.pages.find(p => p.slug === 'trang-chu-noi-dung');
    const titleValue = home && (isVi ? home.seo_title_vi : home.seo_title_en);
    const descValue = home && (isVi ? home.seo_description_vi : home.seo_description_en);
    title = titleValue || (isVi ? 'Trang chủ | Sky First' : 'Home | Sky First');
    description = descValue || description;
  } else if (path === '/gioi-thieu' || path.startsWith('/gioi-thieu/') || directPolicySlugs[path]) {
    const subPath = path.startsWith('/gioi-thieu/') ? path.split('/').filter(Boolean)[1] : null;
    const slug = AppState.currentQuery.get('section') || subPath || directPolicySlugs[path] || 'tong-quan';
    const pg = AppState.pages.find(p => p.slug === slug);
    if (pg) {
      title = (isVi ? pg.seo_title_vi : pg.seo_title_en) || (isVi ? pg.title_vi : (pg.title_en || pg.title_vi));
      description = (isVi ? pg.seo_description_vi : pg.seo_description_en) || (isVi ? pg.summary_vi : (pg.summary_en || pg.summary_vi)) || description;
    }
  } else if (path.startsWith('/tin-tuc-hoat-dong/')) {
    const slug = path.split('/').filter(Boolean)[1];
    const post = AppState.posts.find(p => p.slug === slug || p.custom_path === path);
    if (post) {
      title = post.seo_title || (isVi ? post.title_vi : (post.title_en || post.title_vi));
      description = isVi ? (post.seo_description || post.excerpt_vi || description) : (post.excerpt_en || post.seo_description || description);
    }
  } else {
    const routeTitles = {
      '/nghien-cuu-khoa-hoc':['Nghiên cứu khoa học','Scientific Research'],
      '/du-an-cong-dong':['Dự án cộng đồng','Community Projects'],
      '/khao-thi-danh-gia':['Khảo thí và Đánh giá học thuật','Academic Assessment'],
      '/cong-bo-tai-lieu':['Công bố và Tài liệu','Publications and Resources'],
      '/hop-tac-doi-tac':['Hợp tác và Đối tác','Cooperation and Partners'],
      '/tin-tuc-hoat-dong':['Tin tức và Hoạt động','News and Activities'],
      '/dang-ky':['Yêu cầu cấp tài khoản','Account Registration'],
      '/tra-cuu':['Tra cứu hồ sơ','Track a Request'],
      '/dang-nhap':['Đăng nhập','Sign In'],
      '/quen-mat-khau':['Khôi phục mật khẩu','Password Recovery'],
      '/bang-dieu-khien':['Bảng điều khiển','Dashboard'],
      '/quan-tri':['Quản trị','Administration']
    };
    const routeTitle = routeTitles[path];
    if (routeTitle) title = isVi ? routeTitle[0] : routeTitle[1];
    else if (path !== '/') title = isVi ? 'Không tìm thấy trang | Sky First' : 'Page Not Found | Sky First';
  }
  const siteName = isVi ? siteVi : siteEn;
  document.title = title.toLocaleLowerCase().includes(siteName.toLocaleLowerCase()) ? title : `${title} | ${siteName}`;
  const meta = document.querySelector('meta[name="description"]');
  if (meta) meta.setAttribute('content', String(description).slice(0, 500));
  const ogTitle = document.querySelector('meta[property="og:title"]');
  if (ogTitle) ogTitle.setAttribute('content', document.title);
  const ogDescription = document.querySelector('meta[property="og:description"]');
  if (ogDescription) ogDescription.setAttribute('content', String(description).slice(0, 500));
}

function getSafeMenuTarget(rawTarget) {
  const value = String(rawTarget || '').trim();
  if (value.startsWith('/') && !value.startsWith('//') && !value.includes('\\')) {
    return { href: value, internal: true, externalWeb: false };
  }
  try {
    const parsed = new URL(value);
    if (parsed.username || parsed.password) return null;
    if (parsed.protocol === 'mailto:') return { href: value, internal: false, externalWeb: false };
    if (parsed.protocol === 'https:' || parsed.protocol === 'http:') {
      return { href: value, internal: false, externalWeb: true };
    }
  } catch {}
  return null;
}

function renderShell() {
  const isVi = AppState.lang === 'vi';
  const t = I18N[AppState.lang];
  const s = AppState.settings;

  document.getElementById('btnLangVi')?.classList.toggle('active', isVi);
  document.getElementById('btnLangEn')?.classList.toggle('active', !isVi);
  document.getElementById('mobileNavToggle')?.setAttribute('aria-label', isVi ? 'Mở menu điều hướng' : 'Open navigation menu');

  document.getElementById('headerTitleVi').textContent = s.site_name_vi;
  document.getElementById('headerTitleEn').textContent = s.site_name_en;
  document.getElementById('footerNameVi').textContent = s.site_name_vi;
  document.getElementById('footerNameEn').textContent = s.site_name_en;
  document.getElementById('footerCopyright').textContent = isVi ? s.copyright_vi : s.copyright_en;

  document.getElementById('footerCol2Title').textContent = t.footer_col2;
  document.getElementById('footerCol3Title').textContent = t.footer_col3;
  document.getElementById('footerCol4Title').textContent = t.footer_col4;

  // Main 8 Menu Items from D1 cms_menus
  const mainMenus = AppState.menus
    .filter(m => m.menu_location === 'main_header' && Number(m.is_visible) !== 0)
    .sort((a, b) => Number(a.sort_order) - Number(b.sort_order));

  const navEl = document.getElementById('publicMainNav');
  if (navEl) {
    navEl.innerHTML = mainMenus.map(m => {
      const target = getSafeMenuTarget(m.target_url);
      if (!target) return '';
      const label = isVi ? m.label_vi : (m.label_en || m.label_vi);
      const activeTarget = target.internal ? target.href.split('?')[0].replace(/\/$/, '') || '/' : '';
      const isActive = target.internal && ((activeTarget === '/' && AppState.currentPath === '/') ||
                       (activeTarget !== '/' && AppState.currentPath.startsWith(activeTarget)));
      const navAttr = target.internal ? `data-nav="${esc(target.href)}"` : '';
      const externalAttrs = target.externalWeb ? ' target="_blank" rel="noopener noreferrer"' : '';
      return `<a class="nav-item ${isActive ? 'active' : ''}" href="${esc(target.href)}" ${navAttr}${externalAttrs}>${esc(label)}</a>`;
    }).join('');
  }

  // Footer Columns 2, 3, 4 & Footer Bottom from D1 cms_menus
  const renderFooterList = (location, containerId) => {
    const items = AppState.menus
      .filter(m => m.menu_location === location && Number(m.is_visible) !== 0)
      .sort((a, b) => Number(a.sort_order) - Number(b.sort_order));
    const el = document.getElementById(containerId);
    if (!el) return;
    if (location === 'footer_bottom') {
      el.innerHTML = items.map(m => {
        const target = getSafeMenuTarget(m.target_url);
        if (!target) return '';
        const label = isVi ? m.label_vi : (m.label_en || m.label_vi);
        const navAttr = target.internal ? `data-nav="${esc(target.href)}"` : '';
        const externalAttrs = target.externalWeb ? ' target="_blank" rel="noopener noreferrer"' : '';
        return `<a href="${esc(target.href)}" ${navAttr}${externalAttrs}>${esc(label)}</a>`;
      }).join('');
    } else {
      el.innerHTML = items.map(m => {
        const target = getSafeMenuTarget(m.target_url);
        if (!target) return '';
        const label = isVi ? m.label_vi : (m.label_en || m.label_vi);
        const navAttr = target.internal ? `data-nav="${esc(target.href)}"` : '';
        const externalAttrs = target.externalWeb ? ' target="_blank" rel="noopener noreferrer"' : '';
        return `<li><a href="${esc(target.href)}" ${navAttr}${externalAttrs}>${esc(label)}</a></li>`;
      }).join('');
    }
  };

  renderFooterList('footer_col_2', 'footerCol2Links');
  renderFooterList('footer_col_3', 'footerCol3Links');
  renderFooterList('footer_col_4', 'footerCol4Links');
  renderFooterList('footer_bottom', 'footerBottomLinks');
}

async function handleLogout() {
  try {
    await apiFetch('/api/auth/logout', { method: 'POST' });
  } catch {}
  clearAuthSession();
  showToast(AppState.lang === 'vi' ? 'Đã đăng xuất khỏi hệ thống.' : 'Signed out successfully.');
  navigateTo('/');
}

export async function renderRoute() {
  const vp = document.getElementById('appViewport');
  if (!vp) return;
  const isVi = AppState.lang === 'vi';
  const t = I18N[AppState.lang];
  const path = AppState.currentPath;
  document.body.classList.toggle('admin-route', ['/bang-dieu-khien', '/quan-tri', '/admin', '/admin/settings'].includes(path));
  document.body.classList.toggle('login-route', path === '/dang-nhap');
  document.documentElement.lang = isVi ? 'vi' : 'en';
  updateDocumentMetadata(path, isVi);

  if (AppState.loading) {
    vp.innerHTML = `
      <section class="container page-state-shell" aria-live="polite" aria-busy="true">
        <div class="page-state-card">
          <span class="page-state-spinner" aria-hidden="true"></span>
          <p class="page-state-kicker">${isVi ? 'SKY FIRST · TRUNG TÂM NGHIÊN CỨU VÀ PHÁT TRIỂN CỘNG ĐỒNG' : 'SKY FIRST · CENTER FOR RESEARCH AND DEVELOPMENT'}</p>
          <h1>${isVi ? 'Đang chuẩn bị không gian làm việc' : 'Preparing your workspace'}</h1>
          <p>${esc(t.loading)}</p>
        </div>
      </section>
    `;
    return;
  }

  if (AppState.loadError) {
    vp.innerHTML = `
      <section class="container page-state-shell" role="alert">
        <div class="page-state-card page-state-error">
          <div class="page-state-symbol" aria-hidden="true">!</div>
          <p class="page-state-kicker">${isVi ? 'KẾT NỐI HỆ THỐNG' : 'SYSTEM CONNECTION'}</p>
          <h1>${isVi ? 'Chưa thể tải dữ liệu' : 'Unable to load data yet'}</h1>
          <p>${isVi ? 'Máy chủ chưa phản hồi như mong đợi. Hãy kiểm tra kết nối và thử lại; các dữ liệu tài khoản vẫn được bảo vệ.' : 'The server did not respond as expected. Check your connection and try again; account information remains protected.'}</p>
          <div class="alert-box alert-error">${isVi ? 'Vui lòng thử lại sau. Nếu sự cố tiếp diễn, liên hệ ' : 'Please try again later. If the issue continues, contact '}<a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a>.</div>
          <button type="button" class="btn btn-primary" id="btnRetryInit">${isVi ? 'Thử kết nối lại' : 'Retry connection'}</button>
        </div>
      </section>
    `;
    document.getElementById('btnRetryInit')?.addEventListener('click', async () => {
      await loadInitialData();
      renderShell();
      renderRoute();
    });
    return;
  }

  if (path === '/') {
    renderHomeView(vp, isVi, t);
  } else if (path === '/gioi-thieu' || path.startsWith('/gioi-thieu/')) {
    renderAboutView(vp, isVi);
  } else if (['/chinh-sach-bao-mat','/dieu-khoan-su-dung','/an-toan-thong-tin'].includes(path)) {
    renderAboutView(vp, isVi);
  } else if (path === '/nghien-cuu-khoa-hoc') {
    renderResearchView(vp, isVi, t);
  } else if (path === '/du-an-cong-dong') {
    renderProjectsView(vp, isVi, t);
  } else if (path === '/khao-thi-danh-gia') {
    renderExamsView(vp, isVi, t);
  } else if (path === '/cong-bo-tai-lieu') {
    renderPublicationsView(vp, isVi, t);
  } else if (path === '/hop-tac-doi-tac') {
    renderPartnersView(vp, isVi, t);
  } else if (path === '/tin-tuc-hoat-dong' || path.startsWith('/tin-tuc-hoat-dong/')) {
    renderNewsView(vp, isVi, t);
  } else if (path === '/dang-ky' || path === '/yeu-cau-cap-tai-khoan') {
    renderRegister5StepsView(vp, isVi);
  } else if (path === '/tra-cuu' || path === '/tra-cuu-yeu-cau') {
    renderLookupView(vp, isVi);
  } else if (path === '/quen-mat-khau') {
    renderForgotPasswordView(vp, isVi);
  } else if (path === '/dang-nhap') {
    renderLoginView(vp, isVi);
  } else if (path === '/bang-dieu-khien' || path === '/quan-tri') {
    await renderDashboardView(vp, isVi);
  } else {
    vp.innerHTML = `
      <div class="container">
        <div class="empty-state">
          <h3>404 — ${isVi ? 'Không tìm thấy trang yêu cầu' : 'Page Not Found'}</h3>
          <p style="margin-bottom:16px;">${isVi ? 'Đường dẫn bạn truy cập không tồn tại hoặc đã được chuyển hướng.' : 'The requested URL does not exist.'}</p>
          <a class="btn btn-primary" href="/" data-nav="/">${isVi ? 'Quay về Trang chủ' : 'Return Home'}</a>
        </div>
      </div>
    `;
  }
}

// ============================================================================
// VIEW 1: HOMEPAGE (/) — Clean, Non-Technical, Zero Fabricated Stats
// ============================================================================
function renderHomeView(vp, isVi, t) {
  const s = AppState.settings;
  const posts = AppState.posts.slice(0, 3);
  const studies = AppState.researchStudies.slice(0, 3);
  const projects = AppState.communityProjects.slice(0, 3);

  vp.innerHTML = `
    <section class="hero-banner">
      <div class="hero-grid">
        <div>
          <span class="eyebrow hero-eyebrow">
            ${esc(isVi ? s.hero_eyebrow_vi : s.hero_eyebrow_en)}
          </span>
          <h1 class="hero-title">${esc(isVi ? s.hero_title_vi : s.hero_title_en)}</h1>
          <p class="hero-lead">${esc(isVi ? s.hero_subtitle_vi : s.hero_subtitle_en)}</p>
          <div class="hero-btns">
            <a class="btn btn-primary hero-btn-primary" href="/gioi-thieu" data-nav="/gioi-thieu">
              ${esc(isVi ? (s.hero_cta_primary_vi || 'Giới thiệu Trung tâm') : (s.hero_cta_primary_en || 'About the Center'))}
            </a>
            <a class="btn btn-secondary hero-btn-ghost" href="/nghien-cuu-khoa-hoc" data-nav="/nghien-cuu-khoa-hoc">
              ${esc(isVi ? 'Khám phá nghiên cứu' : 'Explore Research')}
            </a>
            <a class="btn btn-secondary hero-btn-ghost" href="/hop-tac-doi-tac" data-nav="/hop-tac-doi-tac">
              ${esc(isVi ? 'Hợp tác cùng Trung tâm' : 'Work with the Center')}
            </a>
          </div>
        </div>
        <div class="hero-visual">
          <img src="/assets/sky-first-logo-trimmed.webp" onerror="this.src='/assets/sky-first-logo.png'" alt="Sky First — Education & Community Development">
          <div class="hero-visual-name">${esc(s.site_name_vi)}</div>
          <div class="hero-visual-en">${esc(s.site_name_en)}</div>
          <div class="hero-focus-points" aria-label="${isVi ? 'Lĩnh vực trọng tâm' : 'Core areas'}">
            <span>${isVi ? 'Nghiên cứu khoa học' : 'Scientific research'}</span>
            <span>${isVi ? 'Khảo thí học thuật' : 'Academic assessment'}</span>
            <span>${isVi ? 'Phát triển cộng đồng' : 'Community development'}</span>
          </div>
        </div>
      </div>
    </section>

    <section class="container">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'LĨNH VỰC HOẠT ĐỘNG TRỌNG TÂM' : 'CORE AREAS OF ACTIVITY'}</span>
          <h2 class="section-title">${isVi ? 'Bốn Trụ cột Học thuật và Cộng đồng' : 'Four Pillars of Academic & Community Development'}</h2>
          <p class="section-desc">${isVi ? 'Trung tâm vận hành trên nguyên tắc minh bạch, chuẩn mực khoa học và bảo vệ dữ liệu cá nhân.' : 'Operating on transparency, scientific rigor, and strict personal data protection.'}</p>
        </div>
        <a class="btn btn-secondary" href="/gioi-thieu" data-nav="/gioi-thieu">${isVi ? 'Tìm hiểu thêm →' : 'Learn More →'}</a>
      </div>
      <div class="grid-4">
        <div class="card">
          <div>
            <span class="card-tag">01</span>
            <h3>${isVi ? 'Nghiên cứu khoa học' : 'Scientific Research'}</h3>
            <p>${isVi ? 'Triển khai các chương trình nghiên cứu ứng dụng, phương pháp giáo dục và chuyển đổi số phục vụ cộng đồng.' : 'Conducting applied research programs, educational methodologies, and digital transformation studies.'}</p>
          </div>
          <div class="card-meta">
            <a href="/nghien-cuu-khoa-hoc" data-nav="/nghien-cuu-khoa-hoc" style="font-weight:700;">${isVi ? 'Xem chuyên mục →' : 'Explore →'}</a>
          </div>
        </div>
        <div class="card">
          <div>
            <span class="card-tag">02</span>
            <h3>${isVi ? 'Dự án cộng đồng' : 'Community Projects'}</h3>
            <p>${isVi ? 'Tổ chức các dự án nâng cao năng lực, phát triển kỹ năng và hỗ trợ cộng đồng với tiến độ theo dõi thực tế.' : 'Implementing capacity-building and community initiatives with verified milestone progress.'}</p>
          </div>
          <div class="card-meta">
            <a href="/du-an-cong-dong" data-nav="/du-an-cong-dong" style="font-weight:700;">${isVi ? 'Xem dự án →' : 'Explore →'}</a>
          </div>
        </div>
        <div class="card">
          <div>
            <span class="card-tag">03</span>
            <h3>${isVi ? 'Khảo thí và Đánh giá học thuật' : 'Academic Assessment'}</h3>
            <p>${isVi ? 'Hệ thống đánh giá học thuật tích hợp cổng khảo thí bảo mật, phân quyền chặt chẽ và bảo vệ kết quả cá nhân.' : 'Integrated secure assessment portal with strict access control and protected academic records.'}</p>
          </div>
          <div class="card-meta">
            <a href="/khao-thi-danh-gia" data-nav="/khao-thi-danh-gia" style="font-weight:700;">${isVi ? 'Cổng khảo thí →' : 'Assessment Portal →'}</a>
          </div>
        </div>
        <div class="card">
          <div>
            <span class="card-tag">04</span>
            <h3>${isVi ? 'Công bố và Tài liệu' : 'Publications & Documents'}</h3>
            <p>${isVi ? 'Kho lưu trữ tài liệu hướng dẫn học thuật, báo cáo phương pháp và ấn phẩm được kiểm duyệt theo phân quyền.' : 'Standardized repository of academic guides, methodological reports, and verified publications.'}</p>
          </div>
          <div class="card-meta">
            <a href="/cong-bo-tai-lieu" data-nav="/cong-bo-tai-lieu" style="font-weight:700;">${isVi ? 'Thư viện tài liệu →' : 'Library →'}</a>
          </div>
        </div>
      </div>
    </section>

    <section style="background:var(--bg-100);padding:8px 0;">
      <div class="container">
        <div class="section-head">
          <div>
            <span class="eyebrow">${isVi ? 'NGHIÊN CỨU & DỰ ÁN' : 'RESEARCH & PROJECTS'}</span>
            <h2 class="section-title">${isVi ? 'Chương trình Nghiên cứu và Dự án Cộng đồng' : 'Research Studies & Community Projects'}</h2>
          </div>
          <div style="display:flex;gap:10px;">
            <a class="btn btn-secondary" href="/nghien-cuu-khoa-hoc" data-nav="/nghien-cuu-khoa-hoc">${isVi ? 'Nghiên cứu khoa học' : 'Research'}</a>
            <a class="btn btn-secondary" href="/du-an-cong-dong" data-nav="/du-an-cong-dong">${isVi ? 'Dự án cộng đồng' : 'Projects'}</a>
          </div>
        </div>
        ${studies.length === 0 && projects.length === 0 ? `
          <div class="empty-state">
            <h3>${isVi ? 'Dữ liệu chương trình đang được cập nhật' : 'Program Listings Updating'}</h3>
            <p>${esc(t.empty_research)}</p>
          </div>
        ` : `
          <div class="grid-3">
            ${studies.map(r => `
              <div class="card">
                <div>
                  <span class="card-tag">${esc(r.code)} • ${esc(isVi ? r.field_vi : r.field_en)}</span>
                  <h3>${esc(isVi ? r.title_vi : r.title_en)}</h3>
                  <p>${esc(isVi ? r.summary_vi : r.summary_en)}</p>
                </div>
                <div class="card-meta">
                  <span class="status-pill status-blue">${esc(r.status)} (${Number(r.progress_percent || 0)}%)</span>
                  <a href="/nghien-cuu-khoa-hoc" data-nav="/nghien-cuu-khoa-hoc">${isVi ? 'Chi tiết →' : 'Details →'}</a>
                </div>
              </div>
            `).join('')}
            ${projects.map(p => `
              <div class="card">
                <div>
                  <span class="card-tag" style="background:#fef3c7;color:#b45309;">${esc(p.code)}</span>
                  <h3>${esc(isVi ? p.title_vi : p.title_en)}</h3>
                  <p>${esc(isVi ? p.summary_vi : p.summary_en)}</p>
                </div>
                <div class="card-meta">
                  <span class="status-pill status-green">${esc(p.status)} (${Number(p.progress_percent || 0)}%)</span>
                  <a href="/du-an-cong-dong" data-nav="/du-an-cong-dong">${isVi ? 'Chi tiết →' : 'Details →'}</a>
                </div>
              </div>
            `).join('')}
          </div>
        `}
      </div>
    </section>

    <section class="container">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'TIN TỨC & HOẠT ĐỘNG' : 'NEWS & ACTIVITIES'}</span>
          <h2 class="section-title">${isVi ? 'Thông báo và Bài viết Mới nhất' : 'Latest Announcements & Articles'}</h2>
        </div>
        <a class="btn btn-secondary" href="/tin-tuc-hoat-dong" data-nav="/tin-tuc-hoat-dong">${isVi ? 'Xem tất cả →' : 'View All →'}</a>
      </div>
      ${posts.length === 0 ? `<div class="empty-state"><p>${esc(t.empty_posts)}</p></div>` : `
        <div class="grid-3">
          ${posts.map(post => `
            <div class="card">
              <div>
                <span class="card-tag">${esc(post.category)}</span>
                <h3>${esc(isVi ? post.title_vi : (post.title_en || post.title_vi))}</h3>
                <p>${esc(isVi ? post.excerpt_vi : (post.excerpt_en || post.excerpt_vi))}</p>
              </div>
              <div class="card-meta">
                <span>${esc((post.published_at || '').slice(0, 10))} • ${esc(post.display_author)}</span>
                <a class="btn btn-sm btn-secondary" href="/tin-tuc-hoat-dong/${esc(post.slug)}" data-nav="/tin-tuc-hoat-dong/${esc(post.slug)}">${isVi ? 'Đọc bài →' : 'Read →'}</a>
              </div>
            </div>
          `).join('')}
        </div>
      `}
    </section>

    <section class="container" style="padding-top:0;">
      <div class="card" style="background:var(--bg-100);border:1px solid var(--line-200);">
        <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:20px;">
          <div>
            <span class="eyebrow">${isVi ? 'HỢP TÁC HỌC THUẬT & CỘNG ĐỒNG' : 'ACADEMIC & COMMUNITY COOPERATION'}</span>
            <h3 style="font-size:20px;">${isVi ? 'Kết nối và Hợp tác cùng Trung tâm Sky First' : 'Collaborate with Sky First Center'}</h3>
            <p style="max-width:820px;margin-bottom:0;">
              ${esc(isVi ? (s.cooperation_status_note_vi || t.empty_partners) : (s.cooperation_status_note_en || t.empty_partners))}
            </p>
          </div>
          <div style="display:flex;gap:12px;">
            <a class="btn btn-primary" href="/hop-tac-doi-tac" data-nav="/hop-tac-doi-tac">${isVi ? 'Hợp tác và Đối tác' : 'Cooperation & Partners'}</a>
            <a class="btn btn-secondary" href="/gioi-thieu?section=lien-he" data-nav="/gioi-thieu?section=lien-he">${isVi ? 'Liên hệ Trung tâm' : 'Contact Us'}</a>
          </div>
        </div>
      </div>
    </section>

    ${(() => {
      const longform = AppState.pages.find(p => p.slug === 'trang-chu-noi-dung' && p.page_group === 'home');
      if (!longform) return '';
      const longTitle = isVi ? longform.title_vi : (longform.title_en || longform.title_vi);
      const longBody = isVi ? longform.content_vi : (longform.content_en || longform.content_vi);
      return `<section class="container longform-shell"><div class="section-head"><div><span class="eyebrow">${isVi ? 'THÔNG TIN CHUYÊN SÂU' : 'IN-DEPTH INFORMATION'}</span><h2 class="section-title">${esc(longTitle)}</h2></div></div><article class="longform-content">${safeRichHtml(longBody)}</article></section>`;
    })()}
  `;
}

// ============================================================================
// VIEW 2: GIỚI THIỆU (/gioi-thieu) & 9 PUBLIC PAGES + SUPPORT TICKET FORM
// ============================================================================
function renderAboutView(vp, isVi) {
  const pathParts = AppState.currentPath.split('/').filter(Boolean);
  const slugFromPath = pathParts.length > 1 ? pathParts[1] : null;
  const directPolicySlugs = {'/chinh-sach-bao-mat':'chinh-sach-bao-ve-du-lieu','/dieu-khoan-su-dung':'dieu-khoan-su-dung','/an-toan-thong-tin':'an-toan-thong-tin'};
  const requestedSlug = AppState.currentQuery.get('section') || slugFromPath || directPolicySlugs[AppState.currentPath] || 'tong-quan';
  const activePage = AppState.pages.find(p => p.slug === requestedSlug);

  if (!activePage) {
    vp.innerHTML = `<div class="container"><div class="empty-state"><h1 class="section-title">404 — ${isVi ? 'Không tìm thấy trang' : 'Page Not Found'}</h1><p>${isVi ? 'Trang thông tin này không tồn tại hoặc chưa được xuất bản.' : 'This information page does not exist or has not been published.'}</p><a class="btn btn-primary" href="/gioi-thieu" data-nav="/gioi-thieu">${isVi ? 'Về Giới thiệu' : 'About the Center'}</a></div></div>`;
    return;
  }

  const title = isVi ? activePage.title_vi : (activePage.title_en || activePage.title_vi);
  const content = isVi ? activePage.content_vi : (activePage.content_en || activePage.content_vi);
  const showSupportForm = ['lien-he', 'ho-tro-nguoi-dung'].includes(activePage.slug);

  vp.innerHTML = `
    <div class="container">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'THÔNG TIN CHÍNH THỨC & CHÍNH SÁCH' : 'OFFICIAL INFORMATION & POLICIES'}</span>
          <h1 class="section-title">${esc(title)}</h1>
        </div>
      </div>
      <div class="subpage-layout">
        <aside class="side-menu" aria-label="Danh mục trang thông tin">
          <div class="side-menu-head">${isVi ? 'Danh mục Thông tin Trung tâm' : 'Information Directory'}</div>
          ${AppState.pages.filter(pg => pg.page_group !== 'home').map(pg => {
            const pgTitle = isVi ? pg.title_vi : (pg.title_en || pg.title_vi);
            return `
              <a class="side-menu-item ${pg.slug === activePage.slug ? 'active' : ''}"
                 href="/gioi-thieu?section=${esc(pg.slug)}"
                 data-nav="/gioi-thieu?section=${esc(pg.slug)}">
                <span>${esc(pgTitle)}</span><span>→</span>
              </a>
            `;
          }).join('')}
        </aside>
        <article class="doc-panel">
          <div class="longform-content" style="font-size:15px;line-height:1.8;">${safeRichHtml(content)}</div>

          ${showSupportForm ? `
            <div style="margin-top:32px;padding-top:24px;border-top:1px solid var(--line-200);">
              <h3>${isVi ? 'Gửi Phiếu Yêu cầu Hỗ trợ Trực tuyến' : 'Submit an Online Support Ticket'}</h3>
              <p style="font-size:13.5px;color:var(--ink-700);margin-bottom:16px;">
                ${isVi ? 'Mọi yêu cầu sẽ được lưu vào hệ thống. Việc gửi phiếu không bảo đảm thời hạn hoặc kết quả xử lý cụ thể.' : 'Your request will be recorded in the support system. Submission does not guarantee a particular response time or outcome.'}
              </p>
              <form id="publicSupportForm">
                <div class="grid-2">
                  <div class="form-group">
                    <label class="form-label" for="supSenderName">${isVi ? 'Họ và tên *' : 'Full Name *'}</label>
                    <input id="supSenderName" class="form-control" required minlength="2">
                  </div>
                  <div class="form-group">
                    <label class="form-label" for="supSenderEmail">Email *</label>
                    <input id="supSenderEmail" type="email" class="form-control" required>
                  </div>
                </div>
                <div class="grid-2">
                  <div class="form-group">
                    <label class="form-label" for="supCategory">${isVi ? 'Nhóm hỗ trợ' : 'Category'}</label>
                    <select id="supCategory" class="form-control">
                      <option value="account">${isVi ? 'Hồ sơ đăng ký / Tài khoản' : 'Account / Registration'}</option>
                      <option value="academic">${isVi ? 'Nghiên cứu / Khảo thí học thuật' : 'Research / Assessment'}</option>
                      <option value="cooperation">${isVi ? 'Đề xuất hợp tác' : 'Partnership Inquiry'}</option>
                      <option value="technical">${isVi ? 'Hỗ trợ kỹ thuật' : 'Technical Support'}</option>
                    </select>
                  </div>
                  <div class="form-group">
                    <label class="form-label" for="supSubject">${isVi ? 'Tiêu đề *' : 'Subject *'}</label>
                    <input id="supSubject" class="form-control" required minlength="3">
                  </div>
                </div>
                <div class="form-group">
                  <label class="form-label" for="supMessage">${isVi ? 'Nội dung chi tiết (tối thiểu 10 ký tự) *' : 'Message (min 10 chars) *'}</label>
                  <textarea id="supMessage" class="form-control" rows="4" required minlength="10"></textarea>
                </div>
                <div id="supStatusMsg"></div>
                <button type="submit" class="btn btn-primary" id="btnSubmitSupport">${isVi ? 'Gửi phiếu hỗ trợ' : 'Submit Support Request'}</button>
              </form>
            </div>
          ` : ''}
        </article>
      </div>
    </div>
  `;

  document.getElementById('publicSupportForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const btn = document.getElementById('btnSubmitSupport');
    const msgBox = document.getElementById('supStatusMsg');
    btn.disabled = true;
    msgBox.innerHTML = '';
    try {
      const res = await apiFetch('/api/public/support-tickets', {
        method: 'POST',
        body: JSON.stringify({
          sender_name: document.getElementById('supSenderName').value.trim(),
          sender_email: document.getElementById('supSenderEmail').value.trim(),
          category: document.getElementById('supCategory').value,
          subject: document.getElementById('supSubject').value.trim(),
          message: document.getElementById('supMessage').value.trim()
        })
      });
      msgBox.innerHTML = `<div class="alert-box alert-success">${isVi ? 'Đã ghi nhận phiếu hỗ trợ mã' : 'Support request recorded with reference'} <strong>${esc(res.ticket_code)}</strong>. ${isVi ? 'Thông tin tiếp nhận đã được lưu; thời gian phản hồi phụ thuộc nội dung và khối lượng yêu cầu.' : 'The receipt is recorded; response timing depends on the request and current workload.'}</div>`;
      e.target.reset();
    } catch (err) {
      msgBox.innerHTML = `<div class="alert-box alert-error">${esc(err.message || (isVi ? 'Không gửi được yêu cầu. Vui lòng thử lại.' : 'Could not submit the request. Please try again.'))}</div>`;
    } finally {
      btn.disabled = false;
    }
  });
}

// ============================================================================
// VIEW 3: NGHIÊN CỨU KHOA HỌC (/nghien-cuu-khoa-hoc)
// ============================================================================
function renderResearchView(vp, isVi, t) {
  const list = AppState.researchStudies;
  vp.innerHTML = `
    <div class="container">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'NGHIÊN CỨU KHOA HỌC' : 'SCIENTIFIC RESEARCH'}</span>
          <h1 class="section-title">${isVi ? 'Chương trình và Đề tài Nghiên cứu Khoa học' : 'Scientific Research Programs & Studies'}</h1>
          <p class="section-desc">${isVi ? 'Chỉ hiển thị các đề tài được đánh dấu công khai trên hệ thống cơ sở dữ liệu của Trung tâm. Tiến độ được tính tự động từ trọng số các nhiệm vụ thực tế.' : 'Showing verified public research studies with progress calculated directly from real task milestones.'}</p>
        </div>
      </div>
      ${list.length === 0 ? `
        <div class="empty-state">
          <h3>${isVi ? 'Đang cập nhật danh mục đề tài công khai' : 'Public Research Catalog Updating'}</h3>
          <p style="margin-bottom:16px;">${esc(t.empty_research)}</p>
          <a class="btn btn-secondary" href="/gioi-thieu?section=lien-he" data-nav="/gioi-thieu?section=lien-he">${isVi ? 'Liên hệ Ban Nghiên cứu' : 'Contact Research Division'}</a>
        </div>
      ` : `
        <div class="grid-3">
          ${list.map(r => {
            let members = [];
            try { members = JSON.parse(r.public_members_json || '[]'); } catch {}
            return `
              <div class="card">
                <div>
                  <span class="card-tag">${esc(r.code)} • ${esc(isVi ? r.field_vi : r.field_en)}</span>
                  <h3>${esc(isVi ? r.title_vi : r.title_en)}</h3>
                  <p>${esc(isVi ? r.summary_vi : r.summary_en)}</p>
                  ${members.length ? `<p style="font-size:12.5px;"><strong>${isVi ? 'Nhóm thực hiện:' : 'Team:'}</strong> ${esc(members.join(', '))}</p>` : ''}
                  <div style="margin:12px 0;">
                    <div style="display:flex;justify-content:space-between;font-size:12px;font-weight:700;margin-bottom:4px;">
                      <span>${isVi ? 'Tiến độ nhiệm vụ thực tế:' : 'Task Milestone Progress:'}</span>
                      <span>${Number(r.progress_percent || 0)}%</span>
                    </div>
                    <div style="height:7px;background:#e2e8f0;border-radius:999px;overflow:hidden;">
                      <div style="height:100%;width:${Math.min(100, Math.max(0, Number(r.progress_percent || 0)))}%;background:var(--blue-600);"></div>
                    </div>
                  </div>
                </div>
                <div class="card-meta">
                  <span class="status-pill status-green">${esc(r.status)}</span>
                  <span>${esc(r.start_date || '')}</span>
                </div>
              </div>
            `;
          }).join('')}
        </div>
      `}
    </div>
  `;
}

// ============================================================================
// VIEW 4: DỰ ÁN CỘNG ĐỒNG (/du-an-cong-dong)
// ============================================================================
function renderProjectsView(vp, isVi, t) {
  const list = AppState.communityProjects;
  vp.innerHTML = `
    <div class="container">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'DỰ ÁN CỘNG ĐỒNG' : 'COMMUNITY PROJECTS'}</span>
          <h1 class="section-title">${isVi ? 'Các Dự án Phát triển Cộng đồng' : 'Community Development Initiatives'}</h1>
          <p class="section-desc">${isVi ? 'Công bố mục tiêu, hoạt động triển khai và minh chứng tiến độ thực tế của các dự án phục vụ cộng đồng.' : 'Publishing objectives, field activities, and verified milestone evidence for community projects.'}</p>
        </div>
      </div>
      ${list.length === 0 ? `
        <div class="empty-state">
          <h3>${isVi ? 'Đang cập nhật danh mục dự án cộng đồng' : 'Community Projects Updating'}</h3>
          <p style="margin-bottom:16px;">${esc(t.empty_projects)}</p>
          <a class="btn btn-secondary" href="/gioi-thieu?section=lien-he" data-nav="/gioi-thieu?section=lien-he">${isVi ? 'Đề xuất dự án hợp tác' : 'Propose a Project'}</a>
        </div>
      ` : `
        <div class="grid-3">
          ${list.map(p => `
            <div class="card">
              <div>
                <span class="card-tag" style="background:#fef3c7;color:#b45309;">${esc(p.code)}</span>
                <h3>${esc(isVi ? p.title_vi : p.title_en)}</h3>
                <p><strong>${isVi ? 'Mục tiêu:' : 'Objective:'}</strong> ${esc(isVi ? p.objective_vi : p.objective_en)}</p>
                <p>${esc(isVi ? p.summary_vi : p.summary_en)}</p>
                ${p.public_evidence_summary ? `<p style="font-size:12.5px;color:var(--emerald-600);"><strong>${isVi ? 'Minh chứng:' : 'Evidence:'}</strong> ${esc(p.public_evidence_summary)}</p>` : ''}
                <div style="margin:12px 0;">
                  <div style="display:flex;justify-content:space-between;font-size:12px;font-weight:700;margin-bottom:4px;">
                    <span>${isVi ? 'Tiến độ hoàn thành:' : 'Completion Progress:'}</span>
                    <span>${Number(p.progress_percent || 0)}%</span>
                  </div>
                  <div style="height:7px;background:#e2e8f0;border-radius:999px;overflow:hidden;">
                    <div style="height:100%;width:${Math.min(100, Math.max(0, Number(p.progress_percent || 0)))}%;background:var(--emerald-600);"></div>
                  </div>
                </div>
              </div>
              <div class="card-meta">
                <span class="status-pill status-green">${esc(p.status)}</span>
                <span>${esc(p.start_date || '')}</span>
              </div>
            </div>
          `).join('')}
        </div>
      `}
    </div>
  `;
}

// ============================================================================
// VIEW 5: KHẢO THÍ VÀ ĐÁNH GIÁ HỌC THUẬT (/khao-thi-danh-gia) — Integrated with exam.skyfirst.io.vn
// ============================================================================
function renderExamsView(vp, isVi, t) {
  const examPortalUrl = AppState.settings.exam_portal_url || 'https://exam.skyfirst.io.vn';
  const exams = AppState.exams;

  vp.innerHTML = `
    <div class="container">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'KHẢO THÍ VÀ ĐÁNH GIÁ HỌC THUẬT' : 'ACADEMIC ASSESSMENT & TESTING'}</span>
          <h1 class="section-title">${isVi ? 'Hệ thống Khảo thí & Đánh giá Học thuật Sky First' : 'Sky First Academic Assessment System'}</h1>
          <p class="section-desc">
            ${isVi
              ? 'Tích hợp đồng bộ cơ sở dữ liệu với Cổng dự thi trực tuyến chính thức (exam.skyfirst.io.vn). Đề thi, bài làm và điểm số được bảo vệ nghiêm ngặt ở tầng máy chủ, chỉ mở khi người dùng đã xác thực đúng quyền.'
              : 'Integrated via shared D1 architecture with the official Sky First Exam delivery portal (exam.skyfirst.io.vn). Questions, attempts, and scores are strictly protected on the backend.'}
          </p>
        </div>
        <div style="display:flex;gap:10px;flex-wrap:wrap;">
          <a class="btn btn-secondary" href="${esc(examPortalUrl)}" target="_blank" rel="noopener">
            🔗 ${isVi ? 'Mở Cổng Dự thi (exam.skyfirst.io.vn)' : 'Open Exam Portal (exam.skyfirst.io.vn)'}
          </a>
          ${!AppState.currentUser ? `
            <a class="btn btn-primary" href="/dang-nhap" data-nav="/dang-nhap">
              🔐 ${isVi ? 'Đăng nhập để Dự thi' : 'Sign In to Take Exam'}
            </a>
          ` : `
            <a class="btn btn-primary" href="/bang-dieu-khien" data-nav="/bang-dieu-khien">
              📊 ${isVi ? 'Xem Lịch sử & Kết quả Dự thi' : 'View My Exam Results'}
            </a>
          `}
        </div>
      </div>

      ${!AppState.currentUser ? `
        <div class="alert-box alert-warning">
          <strong>${isVi ? 'Yêu cầu xác thực tài khoản:' : 'Authentication Required:'}</strong>
          ${isVi
            ? 'Bạn cần đăng nhập bằng tài khoản thành viên/học viên đã được kích hoạt để khởi tạo phiên làm bài và nhận mã khởi chạy một lần (Launch Token) sang cổng khảo thí.'
            : 'Please sign in with an activated account to start an authorized exam session and receive a one-time launch token.'}
        </div>
      ` : ''}

      <div id="examArenaContainer" style="margin-bottom:24px;"></div>

      ${exams.length === 0 ? `
        <div class="empty-state">
          <h3>${isVi ? 'Chưa có kỳ khảo thí nào đang mở' : 'No Open Assessments'}</h3>
          <p style="margin-bottom:14px;">${esc(t.empty_exams)}</p>
          <p style="font-size:13px;color:var(--ink-500);">
            ${isVi
              ? 'Nếu bạn có Mã mời dự thi (Invite Code), bạn có thể truy cập trực tiếp tại cổng:'
              : 'If you have an invitation code, you may enter it directly at:'}
            <a href="${esc(examPortalUrl)}" target="_blank" rel="noopener" style="font-weight:700;">${esc(examPortalUrl)}</a>
          </p>
        </div>
      ` : `
        <div class="grid-3">
          ${exams.map(ex => `
            <div class="card">
              <div>
                <span class="card-tag">${esc(ex.code || 'EXAM')} • ${Number(ex.duration_minutes || 60)} ${isVi ? 'phút' : 'min'}</span>
                <h3>${esc(isVi ? ex.title : (ex.title_en || ex.title))}</h3>
                <p>${esc(isVi ? (ex.public_overview_vi || ex.title) : (ex.public_overview_en || ex.title))}</p>
                <p style="font-size:12.5px;color:var(--ink-500);">
                  ${isVi ? 'Điểm chuẩn đạt:' : 'Passing Score:'} <strong>${Number(ex.pass_score || 70)}</strong>
                </p>
              </div>
              <div class="card-meta">
                <span class="status-pill status-green">${esc(ex.assessment_label || 'Đánh giá học thuật')}</span>
                ${AppState.currentUser ? `
                  <button type="button" class="btn btn-sm btn-primary btn-start-exam" data-exam-id="${esc(ex.id)}">
                    ${isVi ? 'Khởi tạo Phiên thi →' : 'Launch Assessment →'}
                  </button>
                ` : `
                  <a class="btn btn-sm btn-secondary" href="/dang-nhap" data-nav="/dang-nhap">
                    ${isVi ? 'Đăng nhập để thi' : 'Sign in to start'}
                  </a>
                `}
              </div>
            </div>
          `).join('')}
        </div>
      `}
    </div>
  `;

  vp.querySelectorAll('.btn-start-exam').forEach(btn => {
    btn.addEventListener('click', () => startRealExamSession(btn.getAttribute('data-exam-id')));
  });
}

async function startRealExamSession(examId) {
  const arena = document.getElementById('examArenaContainer');
  if (!arena) return;
  arena.innerHTML = `<div class="card"><p>Đang khởi tạo phiên dự thi bảo mật trên máy chủ...</p></div>`;
  try {
    const launchRes = await apiFetch(`/api/exams/${encodeURIComponent(examId)}/start`, {
      method: 'POST',
      body: JSON.stringify({})
    });
    if (launchRes.launch_url) {
      window.location.assign(launchRes.launch_url);
      return;
    }
    const attRes = await apiFetch(`/api/my/exam-attempts/${encodeURIComponent(launchRes.attempt_id)}`);
    AppState.activeExamAttempt = { ...attRes.attempt };
    renderActiveExamWorkspace(arena);
  } catch (err) {
    arena.innerHTML = `<div class="alert-box alert-error">${esc(err.message)}</div>`;
  }
}

function renderActiveExamWorkspace(arena) {
  const att = AppState.activeExamAttempt;
  if (!att) return;

  if (att.status === 'submitted') {
    arena.innerHTML = `
      <div class="card" style="border:2px solid var(--emerald-600);">
        <span class="eyebrow">ĐÃ NỘP BÀI THÀNH CÔNG</span>
        <h3>${esc(att.title)}</h3>
        <p style="margin-top:8px;">
          • Mã phiên thi: <code>${esc(att.id)}</code><br>
          • Mã biên nhận máy chủ: <strong>${esc(att.receipt_code || 'Đang cấp')}</strong><br>
          ${att.score !== null && att.score !== undefined ? `• Kết quả chấm tự động từ Backend: <strong>${esc(att.score)} / ${esc(att.max_score)}</strong>` : '• Trạng thái: Đã ghi nhận bài làm'}
        </p>
      </div>
    `;
    return;
  }

  const questions = att.questions || [];
  const savedAnswers = att.answers || {};

  arena.innerHTML = `
    <div class="card" style="border:2px solid var(--navy-800);">
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:12px;border-bottom:1px solid var(--line-200);padding-bottom:14px;margin-bottom:16px;">
        <div>
          <span class="eyebrow">PHIÊN DỰ THI ĐÃ XÁC THỰC (REVISION #${Number(att.answer_revision || 0)})</span>
          <h3>${esc(att.title)}</h3>
          <p style="font-size:12.5px;color:var(--ink-500);margin:0;">Mã phiên: <code>${esc(att.id)}</code> • Thời lượng: ${Number(att.duration_minutes || 60)} phút</p>
        </div>
        <div style="display:flex;gap:10px;flex-wrap:wrap;">
          ${att.launch_url ? `
            <a class="btn btn-sm btn-secondary" href="${esc(att.launch_url)}" target="_blank" rel="noopener">
              🚀 Mở trên Cổng Chuyên dụng (exam.skyfirst.io.vn)
            </a>
          ` : ''}
        </div>
      </div>
      <form id="activeExamForm">
        ${questions.map((q, idx) => `
          <div style="margin-bottom:16px;padding:14px;background:var(--bg-100);border-radius:8px;">
            <div style="font-weight:700;margin-bottom:8px;">Câu ${idx + 1} (${Number(q.points || 1)} điểm): ${esc(q.question)}</div>
            ${Array.isArray(q.options) && q.options.length > 0 ? q.options.map(opt => `
              <label style="display:block;margin-bottom:6px;cursor:pointer;font-size:13.5px;">
                <input type="radio" name="q_${esc(q.id)}" value="${esc(opt)}" ${String(savedAnswers[q.id] ?? '') === String(opt) ? 'checked' : ''}>
                ${esc(opt)}
              </label>
            `).join('') : `
              <input type="text" class="form-control" name="q_${esc(q.id)}" value="${esc(savedAnswers[q.id] ?? '')}" placeholder="Nhập câu trả lời...">
            `}
          </div>
        `).join('')}
        <div id="examActionMsg"></div>
        <div style="display:flex;gap:12px;margin-top:12px;">
          <button type="button" class="btn btn-secondary" id="btnSaveExamDraft">💾 Lưu nháp bài làm lên D1</button>
          <button type="submit" class="btn btn-emerald" id="btnSubmitExamFinal">✓ Nộp bài & Chấm điểm trên Backend</button>
        </div>
      </form>
    </div>
  `;

  const collectAnswers = () => {
    const ans = {};
    for (const q of questions) {
      const checked = arena.querySelector(`input[type="radio"][name="q_${CSS.escape(String(q.id))}"]:checked`);
      const textInp = arena.querySelector(`input[type="text"][name="q_${CSS.escape(String(q.id))}"]`);
      if (checked) ans[q.id] = checked.value;
      else if (textInp && textInp.value.trim()) ans[q.id] = textInp.value.trim();
    }
    return ans;
  };

  document.getElementById('btnSaveExamDraft')?.addEventListener('click', async () => {
    const answers = collectAnswers();
    try {
      const res = await apiFetch(`/api/my/exam-attempts/${encodeURIComponent(att.id)}/save`, {
        method: 'POST',
        body: JSON.stringify({ answers })
      });
      att.answer_revision = res.answer_revision;
      att.answers = answers;
      showToast(`Đã lưu bài làm (Revision #${res.answer_revision}) lên máy chủ D1.`);
    } catch (err) {
      showToast(err.message, true);
    }
  });

  document.getElementById('activeExamForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const answers = collectAnswers();
    const btn = document.getElementById('btnSubmitExamFinal');
    btn.disabled = true;
    try {
      const res = await apiFetch(`/api/my/exam-attempts/${encodeURIComponent(att.id)}/submit`, {
        method: 'POST',
        body: JSON.stringify({ answers })
      });
      AppState.activeExamAttempt = {
        ...att,
        status: 'submitted',
        score: res.score,
        max_score: res.max_score,
        receipt_code: res.receipt_code
      };
      renderActiveExamWorkspace(arena);
      showToast(`Đã nộp bài thành công! Mã biên nhận: ${res.receipt_code}`);
    } catch (err) {
      showToast(err.message, true);
      btn.disabled = false;
    }
  });
}

// ============================================================================
// VIEW 6: CÔNG BỐ VÀ TÀI LIỆU (/cong-bo-tai-lieu)
// ============================================================================
function renderPublicationsView(vp, isVi, t) {
  const list = AppState.publications;
  vp.innerHTML = `
    <div class="container">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'CÔNG BỐ VÀ TÀI LIỆU' : 'PUBLICATIONS & DOCUMENTS'}</span>
          <h1 class="section-title">${isVi ? 'Thư viện Công bố Khoa học & Tài liệu Chuẩn hóa' : 'Scientific Publications & Standardized Document Library'}</h1>
          <p class="section-desc">${isVi ? 'Tài liệu được kiểm soát quyền truy cập qua Backend và Cloudflare R2.' : 'Documents are access-controlled via the Backend and Cloudflare R2.'}</p>
        </div>
      </div>
      ${list.length === 0 ? `
        <div class="empty-state">
          <h3>${isVi ? 'Đang cập nhật thư viện tài liệu' : 'Document Library Updating'}</h3>
          <p>${esc(t.empty_pubs)}</p>
        </div>
      ` : `
        <div class="grid-3">
          ${list.map(pub => `
            <div class="card">
              <div>
                <span class="card-tag">${esc(pub.category)} • ${esc(pub.code)}</span>
                <h3>${esc(isVi ? pub.title_vi : (pub.title_en || pub.title_vi))}</h3>
                <p>${esc(isVi ? pub.summary_vi : (pub.summary_en || pub.summary_vi))}</p>
                <p style="font-size:12px;color:var(--ink-500);">
                  ${isVi ? 'Tác giả:' : 'Authors:'} <strong>${esc(pub.authors_text)}</strong> •
                  ${isVi ? 'Phân quyền:' : 'Access:'} <code>${esc(pub.access_level)}</code>
                </p>
              </div>
              <div class="card-meta">
                <span>📅 ${esc(pub.published_date)} (${Number(pub.download_count || 0)} lượt tải)</span>
                ${pub.r2_file_id ? `
                  <button type="button" class="btn btn-sm btn-primary btn-download-pub" data-file-id="${esc(pub.r2_file_id)}">
                    ⬇️ ${isVi ? 'Tải tài liệu' : 'Download'}
                  </button>
                ` : `<span style="font-size:12px;color:var(--ink-500);">${isVi ? 'Bản tóm tắt trực tuyến' : 'Online Abstract'}</span>`}
              </div>
            </div>
          `).join('')}
        </div>
      `}
    </div>
  `;

  vp.querySelectorAll('.btn-download-pub').forEach(btn => {
    btn.addEventListener('click', async () => {
      const fileId = btn.getAttribute('data-file-id');
      try {
        await apiFetch(`/api/files/${encodeURIComponent(fileId)}/download`);
        window.open(`/api/files/${encodeURIComponent(fileId)}/download`, '_blank', 'noopener');
      } catch (err) {
        showToast(err.message, true);
      }
    });
  });
}

// ============================================================================
// VIEW 7: HỢP TÁC VÀ ĐỐI TÁC (/hop-tac-doi-tac)
// ============================================================================
function renderPartnersView(vp, isVi, t) {
  const list = AppState.partners;
  vp.innerHTML = `
    <div class="container">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'HỢP TÁC VÀ ĐỐI TÁC' : 'COOPERATION & PARTNERS'}</span>
          <h1 class="section-title">${isVi ? 'Mạng lưới Hợp tác Học thuật và Phát triển Cộng đồng' : 'Academic & Community Collaboration Network'}</h1>
          <p class="section-desc">${esc(isVi ? (AppState.settings.cooperation_status_note_vi || t.empty_partners) : (AppState.settings.cooperation_status_note_en || t.empty_partners))}</p>
        </div>
        <a class="btn btn-primary" href="/gioi-thieu?section=lien-he" data-nav="/gioi-thieu?section=lien-he">
          ${isVi ? 'Gửi Đề xuất Hợp tác →' : 'Submit Partnership Proposal →'}
        </a>
      </div>
      ${list.length === 0 ? `
        <div class="empty-state">
          <h3>${isVi ? 'Chưa có hồ sơ đối tác công khai' : 'No Verified Public Partners Yet'}</h3>
          <p style="max-width:680px;margin:0 auto 16px;">${esc(t.empty_partners)}</p>
          <a class="btn btn-secondary" href="/gioi-thieu?section=lien-he" data-nav="/gioi-thieu?section=lien-he">${isVi ? 'Liên hệ hợp tác qua support@skyfirst.io.vn' : 'Contact support@skyfirst.io.vn'}</a>
        </div>
      ` : `
        <div class="grid-3">
          ${list.map(pt => `
            <div class="card">
              <div>
                <span class="card-tag">${esc(pt.partner_type)}</span>
                <h3>${esc(isVi ? pt.organization_name_vi : (pt.organization_name_en || pt.organization_name_vi))}</h3>
                <p>${esc(isVi ? pt.description_vi : (pt.description_en || pt.description_vi))}</p>
              </div>
              <div class="card-meta">
                <span class="status-pill status-green">${isVi ? 'Đối tác đã xác minh' : 'Verified Partner'}</span>
                ${pt.website_url ? `<a href="${esc(pt.website_url)}" target="_blank" rel="noopener">Website →</a>` : ''}
              </div>
            </div>
          `).join('')}
        </div>
      `}
    </div>
  `;
}

// ============================================================================
// VIEW 8: TIN TỨC VÀ HOẠT ĐỘNG (/tin-tuc-hoat-dong)
// ============================================================================
function renderNewsView(vp, isVi, t) {
  const parts = AppState.currentPath.split('/').filter(Boolean);
  const slug = parts.length > 1 ? parts[1] : null;

  if (slug) {
    const post = AppState.posts.find(p => p.slug === slug);
    if (!post) {
      vp.innerHTML = `
        <div class="container">
          <div class="empty-state">
            <h3>${isVi ? 'Không tìm thấy bài viết' : 'Article Not Found'}</h3>
            <p style="margin-bottom:16px;">${isVi ? 'Bài viết không tồn tại hoặc đang ở trạng thái bản nháp.' : 'This article does not exist or is currently unpublished.'}</p>
            <a class="btn btn-primary" href="/tin-tuc-hoat-dong" data-nav="/tin-tuc-hoat-dong">← ${isVi ? 'Quay lại Tin tức' : 'Back to News'}</a>
          </div>
        </div>
      `;
      return;
    }
    vp.innerHTML = `
      <div class="container">
        <a class="btn btn-sm btn-secondary" href="/tin-tuc-hoat-dong" data-nav="/tin-tuc-hoat-dong" style="margin-bottom:16px;">← ${isVi ? 'Tất cả bài viết' : 'All Articles'}</a>
        <article class="doc-panel">
          <span class="card-tag">${esc(post.category)}</span>
          <h1 class="section-title" style="margin-bottom:10px;">${esc(isVi ? post.title_vi : (post.title_en || post.title_vi))}</h1>
          <div style="font-size:13px;color:var(--ink-500);margin-bottom:20px;border-bottom:1px solid var(--line-200);padding-bottom:12px;">
            📅 ${esc((post.published_at || '').slice(0, 10))} • ✍️ ${esc(post.display_author)}
          </div>
          <div style="font-size:15.5px;line-height:1.8;">${safeRichHtml(isVi ? post.content_vi : (post.content_en || post.content_vi))}</div>
        </article>
      </div>
    `;
    return;
  }

  vp.innerHTML = `
    <div class="container">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'TIN TỨC VÀ HOẠT ĐỘNG' : 'NEWS & ACTIVITIES'}</span>
          <h1 class="section-title">${isVi ? 'Tin tức, Thông báo và Hoạt động Trung tâm' : 'Center News, Announcements & Activities'}</h1>
          <p class="section-desc">${isVi ? 'Chỉ hiển thị các bài viết đã được kiểm duyệt và xuất bản từ hệ thống CMS.' : 'Displaying published articles from the Center CMS.'}</p>
        </div>
      </div>
      ${AppState.posts.length === 0 ? `<div class="empty-state"><p>${esc(t.empty_posts)}</p></div>` : `
        <div class="grid-3">
          ${AppState.posts.map(post => `
            <div class="card">
              <div>
                <span class="card-tag">${esc(post.category)}</span>
                <h3>${esc(isVi ? post.title_vi : (post.title_en || post.title_vi))}</h3>
                <p>${esc(isVi ? post.excerpt_vi : (post.excerpt_en || post.excerpt_vi))}</p>
              </div>
              <div class="card-meta">
                <span>📅 ${esc((post.published_at || '').slice(0, 10))} • ${esc(post.display_author)}</span>
                <a class="btn btn-sm btn-primary" href="/tin-tuc-hoat-dong/${esc(post.slug)}" data-nav="/tin-tuc-hoat-dong/${esc(post.slug)}">${isVi ? 'Xem chi tiết' : 'Read More'}</a>
              </div>
            </div>
          `).join('')}
        </div>
      `}
    </div>
  `;
}

// ============================================================================
// VIEW 9: QUY TRÌNH 5 BƯỚC YÊU CẦU CẤP TÀI KHOẢN (/dang-ky)
// ============================================================================
function renderRegister5StepsView(vp, isVi) {
  const d = AppState.regDraft;

  if (d.submittedResult) {
    const res = d.submittedResult;
    vp.innerHTML = `
      <div class="container" style="max-width:780px;">
        <div class="doc-panel" style="text-align:center;border:2px solid var(--emerald-600);">
          <span class="eyebrow">${isVi ? 'ĐÃ GHI NHẬN HỒ SƠ' : 'APPLICATION RECEIVED'}</span>
          <h1 class="section-title" style="margin-bottom:10px;">${isVi ? 'Hệ thống đã tiếp nhận yêu cầu cấp tài khoản' : 'Your account application has been received'}</h1>
          <p style="font-size:14.5px;color:var(--ink-700);">
            ${isVi ? 'Lưu ý: Đây là xác nhận tiếp nhận hồ sơ để thẩm định, <strong>chưa phải quyết định phê duyệt hoặc kích hoạt tài khoản</strong>.' : 'This confirms receipt for review; <strong>it is not an approval or account activation decision</strong>.'}
          </p>
          <div style="margin:20px auto;padding:18px;background:var(--bg-100);border-radius:12px;max-width:460px;">
            <div style="font-size:12.5px;color:var(--ink-500);font-weight:700;">${isVi ? 'MÃ YÊU CẦU TRA CỨU CỦA BẠN' : 'YOUR REQUEST TRACKING CODE'}</div>
            <div style="font-size:26px;font-weight:800;color:var(--navy-800);letter-spacing:1px;margin:6px 0;" id="issuedRequestCode">${esc(res.request_code)}</div>
            <div style="font-size:12.5px;">${isVi ? 'Trạng thái hiện tại:' : 'Current status:'} <span class="status-pill status-blue">${esc(res.status)}</span></div>
          </div>
          <p style="font-size:13px;color:var(--ink-500);margin-bottom:20px;">
            ${isVi ? 'Vì lý do bảo mật, số giấy tờ định danh được mã hóa; ảnh chân dung và chữ ký được lưu trữ riêng tư theo quyền truy cập. Các dữ liệu nhạy cảm không được gửi kèm email xác nhận.' : 'For privacy, identity numbers are encrypted and portraits/signatures are stored privately with access controls. Sensitive data is not included in confirmation emails.'}
          </p>
          <div style="display:flex;justify-content:center;gap:12px;flex-wrap:wrap;">
            <a class="btn btn-primary" href="/tra-cuu?code=${encodeURIComponent(res.request_code)}" data-nav="/tra-cuu?code=${encodeURIComponent(res.request_code)}">
              🔍 ${isVi ? 'Tra cứu tiến độ hồ sơ' : 'Track application'}
            </a>
            <button type="button" class="btn btn-secondary" id="btnNewRegForm">${isVi ? 'Gửi hồ sơ khác' : 'Submit another application'}</button>
          </div>
        </div>
      </div>
    `;
    document.getElementById('btnNewRegForm')?.addEventListener('click', () => {
      AppState.regDraft.submittedResult = null;
      AppState.regDraft.step = 1;
      renderRoute();
    });
    return;
  }

  const age = calculateAgeFromDob(d.date_of_birth);
  const isMinor = age !== null && age >= 0 && age < 18;
  const stepLabels = isVi ? [
    'Bước 1: Thông tin cá nhân',
    'Bước 2: Học tập & Công tác',
    'Bước 3: Thông tin định danh',
    'Bước 4: Mục đích & Bổ sung',
    'Bước 5: Xác nhận & Ký gửi'
  ] : [
    'Step 1: Personal information',
    'Step 2: Education & employment',
    'Step 3: Identity information',
    'Step 4: Purpose & additional details',
    'Step 5: Review & signature'
  ];

  vp.innerHTML = `
    <div class="container" style="max-width:920px;">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'QUY TRÌNH XÉT DUYỆT 5 BƯỚC CHUẨN HÓA' : 'STANDARDIZED FIVE-STEP APPLICATION'}</span>
          <h1 class="section-title">${isVi ? 'Yêu cầu Cấp Tài khoản Trung tâm Sky First' : 'Request a Sky First Center Account'}</h1>
          <p class="section-desc">${isVi ? 'Vui lòng điền chính xác thông tin ở cả 5 bước. Bạn có thể quay lại các bước trước để chỉnh sửa mà không bị mất dữ liệu đã nhập.' : 'Complete all five steps accurately. You can return to previous steps to edit your information without losing the data entered.'}</p>
        </div>
      </div>

      <div class="stepper" role="tablist" aria-label="${isVi ? 'Các bước đăng ký tài khoản' : 'Account application steps'}">
        ${stepLabels.map((lbl, idx) => {
          const sNum = idx + 1;
          const cls = sNum === d.step ? 'active' : (sNum < d.step ? 'done' : '');
          return `<button type="button" class="step-pill ${cls}" data-goto-step="${sNum}">${esc(lbl)}</button>`;
        }).join('')}
      </div>

      <div class="doc-panel" id="regWizardPanel">
        <div id="regErrorBanner"></div>
        ${renderRegStepContent(d, age, isMinor)}
      </div>
    </div>
  `;

  vp.querySelectorAll('[data-goto-step]').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetStep = Number(btn.getAttribute('data-goto-step'));
      if (targetStep < d.step) {
        syncCurrentStepInputs();
        d.step = targetStep;
        renderRoute();
      }
    });
  });

  bindRegStepEvents(d, age, isMinor);
}

function localizeRegistrationMarkup(markup, english) {
  if (!english) return markup;
  const pairs = [
    ['Bước 1 — Thông tin cá nhân','Step 1 — Personal information'],
    ['Bước 2 — Học tập và công tác','Step 2 — Education and employment'],
    ['Bước 3 — Thông tin định danh và Ảnh chân dung cá nhân','Step 3 — Identity information and personal portrait'],
    ['Bước 4 — Mục đích đăng ký và thông tin bổ sung','Step 4 — Registration purpose and additional information'],
    ['Bước 5 — Kiểm tra hồ sơ, Ký xác nhận và Gửi yêu cầu','Step 5 — Review, sign and submit your application'],
    ['Họ và tên đầy đủ','Full name'], ['Địa chỉ Email','Email address'], ['Số điện thoại liên hệ','Contact phone number'],
    ['Giới tính','Gender'], ['Ngày sinh * (Tính tuổi theo thời gian thực)','Date of birth * (age calculated automatically)'],
    ['Nam</option>','Male</option>'], ['Nữ</option>','Female</option>'],
    ['Tuổi tính tại thời điểm hiện tại:','Age today:'], ['tuổi</strong>','years old</strong>'],
    ['(Dưới 18 tuổi — bắt buộc có thông tin Người giám hộ)','(Under 18 — guardian information required)'], ['(Đủ 18 tuổi)','(18 or older)'],
    ['Thông tin Người giám hộ hợp pháp (Bắt buộc đối với người dưới 18 tuổi)','Legal guardian information (required for applicants under 18)'],
    ['Họ và tên người giám hộ','Guardian full name'], ['Mối quan hệ với người đăng ký','Relationship to applicant'],
    ['Số điện thoại người giám hộ','Guardian phone number'], ['Email người giám hộ (nếu có)','Guardian email (if available)'],
    ['Họ tên cha/mẹ/người giám hộ','Parent/guardian full name'], ['Cha đẻ / Mẹ đẻ / Người giám hộ hợp pháp','Father / Mother / Legal guardian'],
    ['Tôi xác nhận người giám hộ hợp pháp đã đọc quy định và đồng ý cho đăng ký tài khoản tại Trung tâm. *','I confirm that my legal guardian has read the requirements and consents to my account application. *'],
    ['Tiếp tục Bước 2 →','Continue to Step 2 →'], ['Quay lại Bước 1','Back to Step 1'],
    ['Nhóm người đăng ký','Applicant category'], ['Học sinh phổ thông','School student'], ['Sinh viên Đại học / Cao đẳng','College / university student'],
    ['Nghiên cứu viên / Giảng viên','Researcher / lecturer'], ['Cán bộ / Chuyên gia','Staff member / specialist'], ['Tình nguyện viên / Cộng tác viên cộng đồng','Volunteer / community collaborator'],
    ['Trình độ học vấn','Education level'], ['Trung học phổ thông</option>','High school</option>'], ['Cao đẳng / Đại học</option>','College / university</option>'],
    ['Thạc sĩ</option>','Master\'s degree</option>'], ['Tiến sĩ</option>','Doctoral degree</option>'], ['Khác</option>','Other</option>'],
    ['Trường / Đơn vị học tập hoặc công tác','School / study or workplace organization'], ['Nghề nghiệp / Vai trò hiện tại','Current occupation / role'],
    ['Lớp *','Class *'], ['Lớp (nếu có)','Class (if applicable)'], ['Khoa / Bộ môn','Faculty / department'], ['Chuyên ngành / Lĩnh vực chuyên môn','Major / area of expertise'],
    ['Đơn vị / Phòng ban công tác','Organization / department'], ['Chức vụ *','Position *'], ['Chức vụ (nếu có)','Position (if applicable)'],
    ['Tiếp tục Bước 3 →','Continue to Step 3 →'], ['Quay lại Bước 2','Back to Step 2'],
    ['Thông tin định danh được dùng cho mục đích xác minh hồ sơ. Tại bước này, ảnh cần tải lên là ảnh chân dung cá nhân của người đăng ký — không tải ảnh CCCD, hộ chiếu hoặc ảnh giấy tờ vào trường này.','Identity information is used to verify the application. Upload a personal portrait here—not a photo of an ID card, passport, or other identity document.'],
    ['Loại giấy tờ định danh','Identity document type'], ['Căn cước công dân (CCCD - 12 chữ số)','Citizen ID (12 digits)'], ['Hộ chiếu (Passport)','Passport'], ['Thẻ học sinh / sinh viên','Student ID card'], ['Mã định danh giấy khai sinh','Birth certificate identifier'],
    ['Số giấy tờ định danh','Identity document number'], ['Ngày cấp','Issue date'], ['Nơi cấp','Place of issue'], ['Ngày hết hạn giấy tờ (nếu có)','Document expiration date (if applicable)'],
    ['Ảnh chân dung cá nhân (JPG/PNG/WEBP) *','Personal portrait (JPG/PNG/WEBP) *'], ['Chọn tệp trực tiếp từ thiết bị','Choose a file from your device'],
    ['Tiếp tục Bước 4 →','Continue to Step 4 →'], ['Quay lại Bước 3','Back to Step 3'],
    ['Lưu ý: Người đăng ký chỉ chọn nhóm vai trò đề xuất; vai trò chính thức trong hệ thống chỉ được xác lập sau khi Hội đồng/Cán bộ có thẩm quyền xét duyệt.','Note: You are selecting a requested role only. Your actual system role is assigned only after review and approval by an authorized person.'],
    ['Nhóm vai trò đề xuất đăng ký','Requested role'], ['Thành viên Trung tâm (Member)','Center member (Member)'], ['Học viên / Thí sinh Khảo thí (Student)','Learner / assessment candidate (Student)'],
    ['Thành viên Nhóm Nghiên cứu (Researcher)','Research team member (Researcher)'], ['Điều phối viên Dự án Cộng đồng (Project Coordinator)','Community project coordinator'], ['Cộng tác viên Khảo thí Học thuật (Examiner)','Academic assessment contributor (Examiner)'],
    ['Lĩnh vực nghiên cứu hoặc dự án quan tâm','Research or project interests'], ['Khoa học giáo dục, Chuyển đổi số, Khảo thí học thuật...','Education science, digital transformation, academic assessment...'],
    ['Mục đích xin cấp tài khoản chi tiết (tối thiểu 10 ký tự) *','Detailed reason for requesting an account (at least 10 characters) *'],
    ['Mô tả rõ mục đích tham gia nghiên cứu, dự án cộng đồng hoặc khảo thí tại Trung tâm...','Describe why you want to participate in the Center’s research, community projects, or assessments...'],
    ['Tóm tắt kinh nghiệm học thuật / hoạt động xã hội (nếu có)','Summary of academic or community experience (if any)'], ['Các đề tài, dự án hoặc hoạt động bạn đã từng tham gia...','Research, projects or activities you have participated in...'],
    ['Hồ sơ / Tài liệu minh chứng bổ sung (PDF/JPG/PNG — nếu có)','Additional supporting documents (PDF/JPG/PNG — optional)'], ['Không bắt buộc','Optional'],
    ['Tiếp tục Bước 5 →','Continue to Step 5 →'], ['Quay lại Bước 4','Back to Step 4'],
    ['Bản tóm tắt thông tin hồ sơ trước khi gửi','Application summary before submission'], ['Họ và tên:','Full name:'], ['Ngày sinh:','Date of birth:'], ['Dưới 18 tuổi','Under 18'], ['Email & SĐT:','Email & phone:'], ['Người giám hộ:','Guardian:'],
    ['Trình độ & Đơn vị:','Education & organization:'], ['Chuyên ngành / Vai trò:','Major / role:'], ['Giấy tờ định danh:','Identity document:'], ['Cấp ngày','Issued on'], ['Nhóm quyền đề xuất:','Requested role:'],
    ['Sửa Bước 1','Edit Step 1'], ['Sửa Bước 2','Edit Step 2'], ['Sửa Bước 3','Edit Step 3'], ['Sửa Bước 4','Edit Step 4'],
    ['Điều khoản đăng ký và sử dụng tài khoản Sky First','Sky First account registration and use terms'],
    ['1. Mục đích tài khoản.','1. Account purpose.'], ['Tài khoản được sử dụng để truy cập các dịch vụ, hoạt động nghiên cứu, dự án cộng đồng và chức năng khảo thí mà Trung tâm cho phép theo vai trò được cấp.','The account provides access to services, research activities, community projects and assessments permitted by the Center for the assigned role.'],
    ['2. Trách nhiệm người đăng ký.','2. Applicant responsibilities.'], ['Bạn có trách nhiệm cung cấp thông tin chính xác theo hiểu biết của mình, bảo vệ thông tin đăng nhập và không sử dụng tài khoản để truy cập trái phép hoặc gây ảnh hưởng đến hệ thống.','You must provide accurate information to the best of your knowledge, protect your credentials and not use the account for unauthorized access or to disrupt the system.'],
    ['3. Xét duyệt.','3. Review.'], ['Gửi hồ sơ chỉ xác nhận yêu cầu đã được tiếp nhận; không bảo đảm tài khoản được cấp. Trung tâm có thể yêu cầu bổ sung thông tin và chỉ cấp quyền sau khi người có thẩm quyền phê duyệt.','Submitting an application confirms receipt only; it does not guarantee an account. The Center may request more information and grants access only after authorized approval.'],
    ['4. Quản lý tài khoản.','4. Account management.'], ['Quyền truy cập phụ thuộc trạng thái tài khoản, vai trò được phê duyệt và quy định áp dụng. Những hành vi vi phạm có thể dẫn tới việc tạm hạn chế hoặc chấm dứt quyền truy cập theo quy trình phù hợp.','Access depends on account status, approved role and applicable rules. Violations may lead to restriction or termination of access under the relevant process.'],
    ['5. Dữ liệu cá nhân.','5. Personal data.'], ['Thông tin liên hệ, thông tin định danh, ảnh chân dung và chữ ký được xử lý để tiếp nhận, xác minh và xét duyệt hồ sơ, quản lý tài khoản và đáp ứng nghĩa vụ liên quan. Quyền truy cập được giới hạn theo nhiệm vụ; việc lưu trữ và thực hiện quyền của chủ thể dữ liệu tuân theo thông báo quyền riêng tư được công bố.','Contact details, identity information, portrait and signature are processed to receive, verify and review applications, manage accounts and meet related obligations. Access is limited by role; retention and data-subject rights follow the published privacy notice.'],
    ['6. Hỗ trợ và khiếu nại.','6. Support and complaints.'], ['Khi cần sửa thông tin hoặc làm rõ quyết định, người đăng ký liên hệ bộ phận hỗ trợ của Trung tâm qua','To correct information or request clarification of a decision, contact the Center at'], ['hoặc hotline','or call the hotline'],
    ['Vui lòng đọc thêm','Please also read'], ['Điều khoản sử dụng đầy đủ','the full Terms of Use'], ['Thông báo bảo vệ dữ liệu cá nhân','the Personal Data Protection Notice'], ['Nội dung điều khoản chính thức cần được Trung tâm phê duyệt và duy trì nhất quán trên website.','The official terms must be approved by the Center and kept consistent across the website.'],
    ['Các xác nhận bắt buộc trước khi ký và nộp','Required confirmations before signing and submission'], ['Xác nhận tính chính xác:','Accuracy confirmation:'], ['Bạn xác nhận đã kiểm tra thông tin trong bản tóm tắt, thông tin do mình cung cấp đúng theo hiểu biết và sẽ liên hệ Trung tâm nếu phát hiện sai sót cần điều chỉnh.','You confirm that you reviewed the summary and that the information is accurate to the best of your knowledge. Contact the Center if you discover an error.'],
    ['Tôi xác nhận đã rà soát hồ sơ và cam kết tính chính xác của thông tin đã khai báo. *','I confirm that I have reviewed the application and that the information provided is accurate to the best of my knowledge. *'],
    ['Thông báo xử lý dữ liệu cá nhân:','Personal data processing notice:'], ['Trung tâm sử dụng thông tin trong hồ sơ, ảnh chân dung và chữ ký để tiếp nhận, xác minh, xét duyệt và quản lý yêu cầu cấp tài khoản; chỉ người có nhiệm vụ phù hợp được truy cập. Hãy đọc thông báo quyền riêng tư để biết thêm về mục đích, thời hạn lưu giữ và cách thực hiện quyền của bạn.','The Center uses application information, portrait and signature to receive, verify and review account requests. Access is limited to authorized personnel. Read the privacy notice for purposes, retention and how to exercise your rights.'],
    ['Tôi xác nhận đã được cung cấp và đã đọc','I confirm that I have been provided with and have read the'], ['Điều khoản sử dụng:','Terms of use:'], ['Điều khoản quy định trách nhiệm người đăng ký, việc sử dụng tài khoản theo quyền được cấp, quy trình xét duyệt và cách liên hệ khi có vấn đề. Việc tích chọn bên dưới thể hiện sự đồng ý sau khi đã đọc nội dung.','The terms explain applicant responsibilities, account use according to assigned permissions, review procedures and how to seek help. Checking below indicates agreement after reading the terms.'],
    ['Tôi đã đọc, hiểu và đồng ý tuân thủ','I have read, understood and agree to comply with'],
    ['Ký xác nhận của người đăng ký *','Applicant signature *'], ['Chọn một trong hai cách: ký trực tiếp trong khung bên dưới hoặc tải lên ảnh chữ ký của chính bạn. Kiểm tra chữ ký trong bản xem trước trước khi gửi hồ sơ.','Choose one method: sign in the box below or upload an image of your own signature. Review it before submitting.'],
    ['Cách 1 — Ký trực tiếp bằng chuột, bút cảm ứng hoặc ngón tay','Method 1 — Sign using a mouse, stylus or finger'], ['Cách 2 — Tải ảnh chữ ký (PNG/JPG/WEBP, tối đa 150 KB)','Method 2 — Upload a signature image (PNG/JPG/WEBP, up to 150 KB)'], ['Đã chọn ảnh chữ ký; có thể tải lại để thay thế.','Signature image selected; you can upload a replacement.'], ['Chọn ảnh chữ ký cá nhân nếu không ký trực tiếp.','Choose a signature image if you do not sign directly.'],
    ['Xem trước chữ ký hiện tại','Current signature preview'], ['Đã có nét ký trực tiếp trên khung ký.','A direct signature has been drawn in the box.'], ['Xóa chữ ký để ký lại','Clear signature and sign again'],
    ['← Quay lại Bước 4','← Back to Step 4'], ['✓ Gửi Hồ sơ Yêu cầu Cấp Tài khoản','✓ Submit Account Application']
  ];
  let output = markup;
  for (const [vi, en] of pairs) output = output.replaceAll(vi, en);
  output = output.replaceAll('giấy tờ (nếu có)', 'document (if applicable)')
    .replaceAll('Đúng 12 chữ số', 'Exactly 12 digits')
    .replaceAll('Nhập số giấy tờ', 'Enter document number')
    .replaceAll('Cục Cảnh sát QLHC về TTXH...', 'Civil Registry / issuing authority...')
    .replaceAll('Bảo vệ dữ liệu cá nhân', 'Personal data protection');
  return output;
}

function renderRegStepContent(d, age, isMinor) {
  const renderLocalized = html => localizeRegistrationMarkup(html, AppState.lang === 'en');
  if (d.step === 1) {
    return renderLocalized(`
      <h3>Bước 1 — Thông tin cá nhân</h3>
      <div class="grid-2" style="margin-top:14px;">
        <div class="form-group">
          <label class="form-label" for="regFullName">Họ và tên đầy đủ *</label>
          <input id="regFullName" class="form-control" value="${esc(d.full_name)}" placeholder="Nguyễn Văn A" required>
        </div>
        <div class="form-group">
          <label class="form-label" for="regEmail">Địa chỉ Email *</label>
          <input id="regEmail" type="email" class="form-control" value="${esc(d.email)}" placeholder="tenban@domain.com" required>
        </div>
        <div class="form-group">
          <label class="form-label" for="regPhone">Số điện thoại liên hệ *</label>
          <input id="regPhone" class="form-control" value="${esc(d.phone)}" placeholder="0912345678" required>
        </div>
        <div class="form-group">
          <label class="form-label" for="regGender">Giới tính *</label>
          <select id="regGender" class="form-control">
            <option value="Nam" ${d.gender === 'Nam' ? 'selected' : ''}>Nam</option>
            <option value="Nữ" ${d.gender === 'Nữ' ? 'selected' : ''}>Nữ</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label" for="regDob">Ngày sinh * (Tính tuổi theo thời gian thực)</label>
          <input id="regDob" type="date" class="form-control" value="${esc(d.date_of_birth)}" required>
          ${age !== null && age >= 0 ? `<small style="color:var(--ink-500);display:block;margin-top:4px;">Tuổi tính tại thời điểm hiện tại: <strong>${age} tuổi</strong> ${isMinor ? '(Dưới 18 tuổi — bắt buộc có thông tin Người giám hộ)' : '(Đủ 18 tuổi)'}</small>` : ''}
        </div>
      </div>

      ${isMinor ? `
        <div class="alert-box alert-warning" style="margin-top:12px;">
          <h4 style="margin-bottom:10px;">Thông tin Người giám hộ hợp pháp (Bắt buộc đối với người dưới 18 tuổi)</h4>
          <div class="grid-2">
            <div class="form-group">
              <label class="form-label" for="regGuardName">Họ và tên người giám hộ *</label>
              <input id="regGuardName" class="form-control" value="${esc(d.guardian_full_name)}" placeholder="Họ tên cha/mẹ/người giám hộ">
            </div>
            <div class="form-group">
              <label class="form-label" for="regGuardRel">Mối quan hệ với người đăng ký *</label>
              <input id="regGuardRel" class="form-control" value="${esc(d.guardian_relationship)}" placeholder="Cha đẻ / Mẹ đẻ / Người giám hộ hợp pháp">
            </div>
            <div class="form-group">
              <label class="form-label" for="regGuardPhone">Số điện thoại người giám hộ *</label>
              <input id="regGuardPhone" class="form-control" value="${esc(d.guardian_phone)}" placeholder="09xxxxxxxx">
            </div>
            <div class="form-group">
              <label class="form-label" for="regGuardEmail">Email người giám hộ (nếu có)</label>
              <input id="regGuardEmail" type="email" class="form-control" value="${esc(d.guardian_email)}" placeholder="phu-huynh@domain.com">
            </div>
          </div>
          <label style="display:flex;align-items:center;gap:8px;font-weight:600;cursor:pointer;margin-top:6px;">
            <input type="checkbox" id="regGuardConsent" ${d.guardian_consent ? 'checked' : ''}>
            Tôi xác nhận người giám hộ hợp pháp đã đọc quy định và đồng ý cho đăng ký tài khoản tại Trung tâm. *
          </label>
        </div>
      ` : ''}

      <div style="display:flex;justify-content:flex-end;margin-top:20px;">
        <button type="button" class="btn btn-primary" id="btnStep1Next">Tiếp tục Bước 2 →</button>
      </div>
    `);
  }

  if (d.step === 2) {
    const grp = d.applicant_group;
    return renderLocalized(`
      <h3>Bước 2 — Học tập và công tác</h3>
      <div class="grid-2" style="margin-top:14px;">
        <div class="form-group">
          <label class="form-label" for="regAppGroup">Nhóm người đăng ký *</label>
          <select id="regAppGroup" class="form-control">
            <option value="student_school" ${grp === 'student_school' ? 'selected' : ''}>Học sinh phổ thông</option>
            <option value="student_uni" ${grp === 'student_uni' ? 'selected' : ''}>Sinh viên Đại học / Cao đẳng</option>
            <option value="researcher_lecturer" ${grp === 'researcher_lecturer' ? 'selected' : ''}>Nghiên cứu viên / Giảng viên</option>
            <option value="specialist_staff" ${grp === 'specialist_staff' ? 'selected' : ''}>Cán bộ / Chuyên gia</option>
            <option value="community_volunteer" ${grp === 'community_volunteer' ? 'selected' : ''}>Tình nguyện viên / Cộng tác viên cộng đồng</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label" for="regEduLevel">Trình độ học vấn *</label>
          <select id="regEduLevel" class="form-control">
            <option value="Trung học phổ thông" ${d.education_level === 'Trung học phổ thông' ? 'selected' : ''}>Trung học phổ thông</option>
            <option value="Cao đẳng / Đại học" ${d.education_level === 'Cao đẳng / Đại học' ? 'selected' : ''}>Cao đẳng / Đại học</option>
            <option value="Thạc sĩ" ${d.education_level === 'Thạc sĩ' ? 'selected' : ''}>Thạc sĩ</option>
            <option value="Tiến sĩ" ${d.education_level === 'Tiến sĩ' ? 'selected' : ''}>Tiến sĩ</option>
            <option value="Khác" ${d.education_level === 'Khác' ? 'selected' : ''}>Khác</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label" for="regInstitution">Trường / Đơn vị học tập hoặc công tác *</label>
          <input id="regInstitution" class="form-control" value="${esc(d.institution_name)}" placeholder="Tên trường học / viện nghiên cứu / cơ quan">
        </div>
        <div class="form-group">
          <label class="form-label" for="regOccupation">Nghề nghiệp / Vai trò hiện tại *</label>
          <input id="regOccupation" class="form-control" value="${esc(d.current_occupation)}" placeholder="Sinh viên / Giảng viên / Nghiên cứu viên...">
        </div>
        ${(grp === 'student_school' || grp === 'student_uni') ? `
          <div class="form-group">
            <label class="form-label" for="regClassName">Lớp ${grp === 'student_school' ? '*' : '(nếu có)'}</label>
            <input id="regClassName" class="form-control" value="${esc(d.class_name)}" placeholder="Ví dụ: 12A1 hoặc K68-CNTT">
          </div>
        ` : ''}
        ${(grp === 'student_uni' || grp === 'researcher_lecturer') ? `
          <div class="form-group">
            <label class="form-label" for="regFaculty">Khoa / Bộ môn *</label>
            <input id="regFaculty" class="form-control" value="${esc(d.faculty_department)}" placeholder="Khoa Công nghệ thông tin / Khoa học Giáo dục...">
          </div>
        ` : ''}
        <div class="form-group">
          <label class="form-label" for="regMajor">Chuyên ngành / Lĩnh vực chuyên môn *</label>
          <input id="regMajor" class="form-control" value="${esc(d.major_or_field)}" placeholder="Khoa học dữ liệu / Giáo dục học / Xã hội học...">
        </div>
        ${(grp === 'specialist_staff' || grp === 'researcher_lecturer' || grp === 'community_volunteer') ? `
          <div class="form-group">
            <label class="form-label" for="regWorkUnit">Đơn vị / Phòng ban công tác</label>
            <input id="regWorkUnit" class="form-control" value="${esc(d.work_unit)}" placeholder="Phòng / Ban / Trung tâm...">
          </div>
          <div class="form-group">
            <label class="form-label" for="regPosition">Chức vụ ${grp === 'specialist_staff' ? '*' : '(nếu có)'}</label>
            <input id="regPosition" class="form-control" value="${esc(d.position_title)}" placeholder="Chuyên viên / Điều phối viên / Trưởng nhóm...">
          </div>
        ` : ''}
      </div>
      <div style="display:flex;justify-content:space-between;margin-top:20px;">
        <button type="button" class="btn btn-secondary" id="btnStep2Back">← Quay lại Bước 1</button>
        <button type="button" class="btn btn-primary" id="btnStep2Next">Tiếp tục Bước 3 →</button>
      </div>
    `);
  }

  if (d.step === 3) {
    return renderLocalized(`
      <h3>Bước 3 — Thông tin định danh và Ảnh chân dung cá nhân</h3>
      <p style="font-size:13px;color:var(--emerald-600);margin:6px 0 14px;">
        Thông tin định danh được dùng cho mục đích xác minh hồ sơ. Tại bước này, ảnh cần tải lên là ảnh chân dung cá nhân của người đăng ký — không tải ảnh CCCD, hộ chiếu hoặc ảnh giấy tờ vào trường này.
      </p>
      <div class="grid-2">
        <div class="form-group">
          <label class="form-label" for="regIdType">Loại giấy tờ định danh *</label>
          <select id="regIdType" class="form-control">
            <option value="CCCD" ${d.id_document_type === 'CCCD' ? 'selected' : ''}>Căn cước công dân (CCCD - 12 chữ số)</option>
            <option value="Passport" ${d.id_document_type === 'Passport' ? 'selected' : ''}>Hộ chiếu (Passport)</option>
            <option value="StudentCard" ${d.id_document_type === 'StudentCard' ? 'selected' : ''}>Thẻ học sinh / sinh viên</option>
            <option value="BirthCertificate" ${d.id_document_type === 'BirthCertificate' ? 'selected' : ''}>Mã định danh giấy khai sinh</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label" for="regIdNumber">Số giấy tờ định danh * ${d.id_document_type === 'CCCD' ? '(Đúng 12 chữ số)' : ''}</label>
          <input id="regIdNumber" class="form-control" value="${esc(d.id_number)}" placeholder="${d.id_document_type === 'CCCD' ? '079203001234' : 'Nhập số giấy tờ'}">
        </div>
        <div class="form-group">
          <label class="form-label" for="regIdIssuedDate">Ngày cấp *</label>
          <input id="regIdIssuedDate" type="date" class="form-control" value="${esc(d.id_issued_date)}">
        </div>
        <div class="form-group">
          <label class="form-label" for="regIdIssuedPlace">Nơi cấp *</label>
          <input id="regIdIssuedPlace" class="form-control" value="${esc(d.id_issued_place)}" placeholder="Cục Cảnh sát QLHC về TTXH...">
        </div>
        <div class="form-group">
          <label class="form-label" for="regIdExpiryDate">Ngày hết hạn giấy tờ (nếu có)</label>
          <input id="regIdExpiryDate" type="date" class="form-control" value="${esc(d.id_expiry_date)}">
        </div>
      </div>

      <div class="grid-2 registration-upload-grid" style="margin-top:10px;">
        <div class="card" style="padding:14px;">
          <label class="form-label" for="filePersonalPhoto">Ảnh chân dung cá nhân (JPG/PNG/WEBP) *</label>
          <input id="filePersonalPhoto" type="file" accept="image/jpeg,image/png,image/webp" class="form-control" data-upload-purpose="personal_photo" required>
          <small id="status_personal_photo" style="display:block;margin-top:6px;color:var(--emerald-600);font-weight:600;">
            ${d.personal_photo_name ? `✓ Đã tải: ${esc(d.personal_photo_name)}` : 'Chọn tệp trực tiếp từ thiết bị'}
          </small>
        </div>
      </div>

      <div style="display:flex;justify-content:space-between;margin-top:20px;">
        <button type="button" class="btn btn-secondary" id="btnStep3Back">← Quay lại Bước 2</button>
        <button type="button" class="btn btn-primary" id="btnStep3Next">Tiếp tục Bước 4 →</button>
      </div>
    `);
  }

  if (d.step === 4) {
    return renderLocalized(`
      <h3>Bước 4 — Mục đích đăng ký và thông tin bổ sung</h3>
      <p style="font-size:13px;color:var(--ink-500);margin:6px 0 14px;">
        Lưu ý: Người đăng ký chỉ chọn nhóm vai trò đề xuất; vai trò chính thức trong hệ thống chỉ được xác lập sau khi Hội đồng/Cán bộ có thẩm quyền xét duyệt.
      </p>
      <div class="grid-2">
        <div class="form-group">
          <label class="form-label" for="regReqRole">Nhóm vai trò đề xuất đăng ký *</label>
          <select id="regReqRole" class="form-control">
            <option value="member" ${d.requested_role === 'member' ? 'selected' : ''}>Thành viên Trung tâm (Member)</option>
            <option value="student" ${d.requested_role === 'student' ? 'selected' : ''}>Học viên / Thí sinh Khảo thí (Student)</option>
            <option value="researcher" ${d.requested_role === 'researcher' ? 'selected' : ''}>Thành viên Nhóm Nghiên cứu (Researcher)</option>
            <option value="project_manager" ${d.requested_role === 'project_manager' ? 'selected' : ''}>Điều phối viên Dự án Cộng đồng (Project Coordinator)</option>
            <option value="examiner" ${d.requested_role === 'examiner' ? 'selected' : ''}>Cộng tác viên Khảo thí Học thuật (Examiner)</option>
          </select>
        </div>
        <div class="form-group">
          <label class="form-label" for="regInterest">Lĩnh vực nghiên cứu hoặc dự án quan tâm *</label>
          <input id="regInterest" class="form-control" value="${esc(d.research_or_project_interest)}" placeholder="Khoa học giáo dục, Chuyển đổi số, Khảo thí học thuật...">
        </div>
      </div>
      <div class="form-group">
        <label class="form-label" for="regPurpose">Mục đích xin cấp tài khoản chi tiết (tối thiểu 10 ký tự) *</label>
        <textarea id="regPurpose" class="form-control" rows="3" placeholder="Mô tả rõ mục đích tham gia nghiên cứu, dự án cộng đồng hoặc khảo thí tại Trung tâm...">${esc(d.registration_purpose)}</textarea>
      </div>
      <div class="form-group">
        <label class="form-label" for="regExp">Tóm tắt kinh nghiệm học thuật / hoạt động xã hội (nếu có)</label>
        <textarea id="regExp" class="form-control" rows="2" placeholder="Các đề tài, dự án hoặc hoạt động bạn đã từng tham gia...">${esc(d.experience_summary)}</textarea>
      </div>
      <div class="form-group">
        <label class="form-label" for="fileSupportingDoc">Hồ sơ / Tài liệu minh chứng bổ sung (PDF/JPG/PNG — nếu có)</label>
        <input id="fileSupportingDoc" type="file" accept="application/pdf,image/jpeg,image/png,image/webp" class="form-control" data-upload-purpose="supporting_doc">
        <small id="status_supporting_doc" style="display:block;margin-top:6px;color:var(--emerald-600);font-weight:600;">
          ${d.supporting_doc_name ? `✓ Đã tải: ${esc(d.supporting_doc_name)}` : 'Không bắt buộc'}
        </small>
      </div>
      <div style="display:flex;justify-content:space-between;margin-top:20px;">
        <button type="button" class="btn btn-secondary" id="btnStep4Back">← Quay lại Bước 3</button>
        <button type="button" class="btn btn-primary" id="btnStep4Next">Tiếp tục Bước 5 →</button>
      </div>
    `);
  }

  const maskedIdPreview = d.id_number.length > 4
    ? '*'.repeat(d.id_number.length - 4) + d.id_number.slice(-4)
    : '****';

  return renderLocalized(`
    <h3>Bước 5 — Kiểm tra hồ sơ, Ký xác nhận và Gửi yêu cầu</h3>
    <div class="card" style="background:var(--bg-100);margin:14px 0;">
      <h4 style="margin-bottom:10px;color:var(--navy-900);">Bản tóm tắt thông tin hồ sơ trước khi gửi</h4>
      <div class="grid-2" style="font-size:13.5px;">
        <div>
          <p>• <strong>Họ và tên:</strong> ${esc(d.full_name)} (${esc(d.gender)})</p>
          <p>• <strong>Ngày sinh:</strong> ${esc(d.date_of_birth)} ${isMinor ? `<span class="status-pill status-amber">Dưới 18 tuổi</span>` : ''}</p>
          <p>• <strong>Email & SĐT:</strong> ${esc(d.email)} | ${esc(d.phone)}</p>
          ${isMinor ? `<p>• <strong>Người giám hộ:</strong> ${esc(d.guardian_full_name)} (${esc(d.guardian_relationship)} - ${esc(d.guardian_phone)})</p>` : ''}
        </div>
        <div>
          <p>• <strong>Trình độ & Đơn vị:</strong> ${esc(d.education_level)} — ${esc(d.institution_name)}</p>
          <p>• <strong>Chuyên ngành / Vai trò:</strong> ${esc(d.major_or_field)} (${esc(d.current_occupation)})</p>
          <p>• <strong>Giấy tờ định danh:</strong> ${esc(d.id_document_type)} (${esc(maskedIdPreview)}) — Cấp ngày ${esc(d.id_issued_date)}</p>
          <p>• <strong>Nhóm quyền đề xuất:</strong> <code>${esc(d.requested_role)}</code></p>
        </div>
      </div>
      <div style="margin-top:10px;display:flex;gap:8px;flex-wrap:wrap;">
        <button type="button" class="btn btn-sm btn-secondary" data-goto-step="1">Sửa Bước 1</button>
        <button type="button" class="btn btn-sm btn-secondary" data-goto-step="2">Sửa Bước 2</button>
        <button type="button" class="btn btn-sm btn-secondary" data-goto-step="3">Sửa Bước 3</button>
        <button type="button" class="btn btn-sm btn-secondary" data-goto-step="4">Sửa Bước 4</button>
      </div>
    </div>

    <section class="registration-terms" aria-labelledby="registrationTermsTitle">
      <h4 id="registrationTermsTitle">Điều khoản đăng ký và sử dụng tài khoản Sky First</h4>
      <p><strong>1. Mục đích tài khoản.</strong> Tài khoản được sử dụng để truy cập các dịch vụ, hoạt động nghiên cứu, dự án cộng đồng và chức năng khảo thí mà Trung tâm cho phép theo vai trò được cấp.</p>
      <p><strong>2. Trách nhiệm người đăng ký.</strong> Bạn có trách nhiệm cung cấp thông tin chính xác theo hiểu biết của mình, bảo vệ thông tin đăng nhập và không sử dụng tài khoản để truy cập trái phép hoặc gây ảnh hưởng đến hệ thống.</p>
      <p><strong>3. Xét duyệt.</strong> Gửi hồ sơ chỉ xác nhận yêu cầu đã được tiếp nhận; không bảo đảm tài khoản được cấp. Trung tâm có thể yêu cầu bổ sung thông tin và chỉ cấp quyền sau khi người có thẩm quyền phê duyệt.</p>
      <p><strong>4. Quản lý tài khoản.</strong> Quyền truy cập phụ thuộc trạng thái tài khoản, vai trò được phê duyệt và quy định áp dụng. Những hành vi vi phạm có thể dẫn tới việc tạm hạn chế hoặc chấm dứt quyền truy cập theo quy trình phù hợp.</p>
      <p><strong>5. Dữ liệu cá nhân.</strong> Thông tin liên hệ, thông tin định danh, ảnh chân dung và chữ ký được xử lý để tiếp nhận, xác minh và xét duyệt hồ sơ, quản lý tài khoản và đáp ứng nghĩa vụ liên quan. Quyền truy cập được giới hạn theo nhiệm vụ; việc lưu trữ và thực hiện quyền của chủ thể dữ liệu tuân theo thông báo quyền riêng tư được công bố.</p>
      <p><strong>6. Hỗ trợ và khiếu nại.</strong> Khi cần sửa thông tin hoặc làm rõ quyết định, người đăng ký liên hệ bộ phận hỗ trợ của Trung tâm qua <a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a> hoặc hotline <a href="tel:0924910210">0924 910 210</a>.</p>
      <p class="registration-terms-note">Vui lòng đọc thêm <a href="/gioi-thieu?section=dieu-khoan-su-dung" target="_blank" rel="noopener noreferrer">Điều khoản sử dụng đầy đủ</a> và <a href="/gioi-thieu?section=chinh-sach-bao-ve-du-lieu" target="_blank" rel="noopener noreferrer">Thông báo bảo vệ dữ liệu cá nhân</a>. Nội dung điều khoản chính thức cần được Trung tâm phê duyệt và duy trì nhất quán trên website.</p>
    </section>

    <section class="registration-confirmations" aria-labelledby="registrationConfirmTitle">
      <h4 id="registrationConfirmTitle">Các xác nhận bắt buộc trước khi ký và nộp</h4>
      <div class="registration-confirmation-copy">
        <strong>Xác nhận tính chính xác:</strong> Bạn xác nhận đã kiểm tra thông tin trong bản tóm tắt, thông tin do mình cung cấp đúng theo hiểu biết và sẽ liên hệ Trung tâm nếu phát hiện sai sót cần điều chỉnh.
      </div>
      <label class="registration-check-row">
        <input type="checkbox" id="chkAccuracy" ${d.data_accuracy_confirmed ? 'checked' : ''}>
        <span>Tôi xác nhận đã rà soát hồ sơ và cam kết tính chính xác của thông tin đã khai báo. *</span>
      </label>
      <div class="registration-confirmation-copy">
        <strong>Thông báo xử lý dữ liệu cá nhân:</strong> Trung tâm sử dụng thông tin trong hồ sơ, ảnh chân dung và chữ ký để tiếp nhận, xác minh, xét duyệt và quản lý yêu cầu cấp tài khoản; chỉ người có nhiệm vụ phù hợp được truy cập. Hãy đọc thông báo quyền riêng tư để biết thêm về mục đích, thời hạn lưu giữ và cách thực hiện quyền của bạn.
      </div>
      <label class="registration-check-row">
        <input type="checkbox" id="chkPrivacy" ${d.privacy_policy_accepted ? 'checked' : ''}>
        <span>Tôi xác nhận đã được cung cấp và đã đọc <a href="/gioi-thieu?section=chinh-sach-bao-ve-du-lieu" target="_blank" rel="noopener noreferrer">Thông báo bảo vệ dữ liệu cá nhân</a>. *</span>
      </label>
      <div class="registration-confirmation-copy">
        <strong>Điều khoản sử dụng:</strong> Điều khoản quy định trách nhiệm người đăng ký, việc sử dụng tài khoản theo quyền được cấp, quy trình xét duyệt và cách liên hệ khi có vấn đề. Việc tích chọn bên dưới thể hiện sự đồng ý sau khi đã đọc nội dung.
      </div>
      <label class="registration-check-row">
        <input type="checkbox" id="chkTerms" ${d.terms_accepted ? 'checked' : ''}>
        <span>Tôi đã đọc, hiểu và đồng ý tuân thủ <a href="/gioi-thieu?section=dieu-khoan-su-dung" target="_blank" rel="noopener noreferrer">Điều khoản đăng ký và sử dụng tài khoản Sky First</a>. *</span>
      </label>
    </section>

    <section class="signature-section" aria-labelledby="signatureHeading">
      <h4 id="signatureHeading">Ký xác nhận của người đăng ký *</h4>
      <p>Chọn một trong hai cách: ký trực tiếp trong khung bên dưới hoặc tải lên ảnh chữ ký của chính bạn. Kiểm tra chữ ký trong bản xem trước trước khi gửi hồ sơ.</p>
      <div class="signature-method-label">Cách 1 — Ký trực tiếp bằng chuột, bút cảm ứng hoặc ngón tay</div>
      <canvas id="signatureCanvas" class="signature-pad" width="500" height="140" aria-label="Vùng ký trực tiếp"></canvas>
      <div class="signature-upload-row">
        <div class="signature-method-label">Cách 2 — Tải ảnh chữ ký (PNG/JPG/WEBP, tối đa 150 KB)</div>
        <input id="fileSignatureImage" type="file" accept="image/png,image/jpeg,image/webp" class="form-control">
        <small id="signatureUploadStatus">${d.signature_method === 'upload' && d.signature_data ? 'Đã chọn ảnh chữ ký; có thể tải lại để thay thế.' : 'Chọn ảnh chữ ký cá nhân nếu không ký trực tiếp.'}</small>
      </div>
      <div id="signaturePreviewWrap" class="signature-preview-wrap" ${d.signature_data ? '' : 'hidden'}>
        <strong>Xem trước chữ ký hiện tại</strong>
        <img id="signaturePreview" alt="Bản xem trước chữ ký" src="${d.signature_data && d.signature_method === 'upload' ? esc(d.signature_data) : ''}" ${d.signature_data && d.signature_method === 'upload' ? '' : 'hidden'}>
        <span id="signatureDirectStatus" ${d.signature_data && d.signature_method === 'draw' ? '' : 'hidden'}>Đã có nét ký trực tiếp trên khung ký.</span>
      </div>
      <button type="button" class="btn btn-sm btn-secondary" id="btnClearSignature">Xóa chữ ký để ký lại</button>
    </section>

    <div style="display:flex;justify-content:space-between;margin-top:20px;">
      <button type="button" class="btn btn-secondary" id="btnStep5Back">← Quay lại Bước 4</button>
      <button type="button" class="btn btn-emerald" id="btnSubmitAccountReq">✓ Gửi Hồ sơ Yêu cầu Cấp Tài khoản</button>
    </div>
  `);
}

function syncCurrentStepInputs() {
  const d = AppState.regDraft;
  const val = id => document.getElementById(id)?.value?.trim();
  if (d.step === 1) {
    if (val('regFullName') !== undefined) d.full_name = val('regFullName');
    if (val('regEmail') !== undefined) d.email = val('regEmail');
    if (val('regPhone') !== undefined) d.phone = val('regPhone');
    if (val('regGender') !== undefined) d.gender = val('regGender');
    if (val('regDob') !== undefined) d.date_of_birth = val('regDob');
    if (document.getElementById('regGuardName')) d.guardian_full_name = val('regGuardName');
    if (document.getElementById('regGuardRel')) d.guardian_relationship = val('regGuardRel');
    if (document.getElementById('regGuardPhone')) d.guardian_phone = val('regGuardPhone');
    if (document.getElementById('regGuardEmail')) d.guardian_email = val('regGuardEmail');
    if (document.getElementById('regGuardConsent')) d.guardian_consent = document.getElementById('regGuardConsent').checked;
  } else if (d.step === 2) {
    if (val('regAppGroup') !== undefined) d.applicant_group = val('regAppGroup');
    if (val('regEduLevel') !== undefined) d.education_level = val('regEduLevel');
    if (val('regInstitution') !== undefined) d.institution_name = val('regInstitution');
    if (val('regOccupation') !== undefined) d.current_occupation = val('regOccupation');
    if (document.getElementById('regClassName')) d.class_name = val('regClassName');
    if (document.getElementById('regFaculty')) d.faculty_department = val('regFaculty');
    if (val('regMajor') !== undefined) d.major_or_field = val('regMajor');
    if (document.getElementById('regWorkUnit')) d.work_unit = val('regWorkUnit');
    if (document.getElementById('regPosition')) d.position_title = val('regPosition');
  } else if (d.step === 3) {
    if (val('regIdType') !== undefined) d.id_document_type = val('regIdType');
    if (val('regIdNumber') !== undefined) d.id_number = val('regIdNumber');
    if (val('regIdIssuedDate') !== undefined) d.id_issued_date = val('regIdIssuedDate');
    if (val('regIdIssuedPlace') !== undefined) d.id_issued_place = val('regIdIssuedPlace');
    if (val('regIdExpiryDate') !== undefined) d.id_expiry_date = val('regIdExpiryDate');
  } else if (d.step === 4) {
    if (val('regReqRole') !== undefined) d.requested_role = val('regReqRole');
    if (val('regInterest') !== undefined) d.research_or_project_interest = val('regInterest');
    if (val('regPurpose') !== undefined) d.registration_purpose = val('regPurpose');
    if (val('regExp') !== undefined) d.experience_summary = val('regExp');
  } else if (d.step === 5) {
    if (document.getElementById('chkAccuracy')) d.data_accuracy_confirmed = document.getElementById('chkAccuracy').checked;
    if (document.getElementById('chkPrivacy')) d.privacy_policy_accepted = document.getElementById('chkPrivacy').checked;
    if (document.getElementById('chkTerms')) d.terms_accepted = document.getElementById('chkTerms').checked;
  }
}

function bindRegStepEvents(d, age, isMinor) {
  const showErr = msg => {
    const b = document.getElementById('regErrorBanner');
    if (b) b.innerHTML = `<div class="alert-box alert-error">${esc(msg)}</div>`;
  };

  document.getElementById('regDob')?.addEventListener('change', () => {
    syncCurrentStepInputs();
    renderRoute();
  });

  document.getElementById('regAppGroup')?.addEventListener('change', () => {
    syncCurrentStepInputs();
    renderRoute();
  });

  document.getElementById('regIdType')?.addEventListener('change', () => {
    syncCurrentStepInputs();
    renderRoute();
  });

  // Direct R2 file uploads in Step 3 & Step 4
  document.querySelectorAll('[data-upload-purpose]').forEach(input => {
    input.addEventListener('change', async () => {
      const file = input.files?.[0];
      const purpose = input.getAttribute('data-upload-purpose');
      const statusEl = document.getElementById(`status_${purpose}`);
      if (!file) return;
      if (statusEl) statusEl.textContent = 'Đang tải tệp bảo mật lên máy chủ...';
      input.disabled = true;
      try {
        const fd = new FormData();
        fd.set('file', file);
        fd.set('purpose', purpose);
        const res = await apiFetch('/api/account-requests/upload', { method: 'POST', body: fd });
        d[`${purpose}_r2_key`] = res.r2_key;
        d[`${purpose}_name`] = res.original_filename;
        if (statusEl) statusEl.textContent = `✓ Đã tải bảo mật: ${res.original_filename}`;
        showToast(`Tải tệp ${res.original_filename} thành công.`);
      } catch (err) {
        if (statusEl) statusEl.textContent = `✕ Lỗi: ${err.message}`;
        showToast(err.message, true);
      } finally {
        input.disabled = false;
      }
    });
  });

  document.getElementById('btnStep1Next')?.addEventListener('click', () => {
    syncCurrentStepInputs();
    if (d.full_name.length < 3) return showErr('Vui lòng nhập Họ và tên đầy đủ (tối thiểu 3 ký tự).');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(d.email)) return showErr('Địa chỉ Email không hợp lệ.');
    if (!/^(0|\+84)[0-9]{8,10}$/.test(d.phone.replace(/[\s.-]/g, ''))) return showErr('Số điện thoại không hợp lệ (10-11 chữ số).');
    const calcAge = calculateAgeFromDob(d.date_of_birth);
    if (calcAge === null) return showErr('Vui lòng chọn Ngày sinh hợp lệ.');
    if (calcAge < 0) return showErr('Ngày sinh không được nằm trong tương lai.');
    if (calcAge < 18) {
      if (!d.guardian_full_name || !d.guardian_relationship || !/^(0|\+84)[0-9]{8,10}$/.test(d.guardian_phone.replace(/[\s.-]/g, '')) || !d.guardian_consent) {
        return showErr('Người đăng ký dưới 18 tuổi bắt buộc phải nhập đầy đủ Họ tên, Mối quan hệ, Số điện thoại hợp lệ và tích chọn Xác nhận đồng ý của người giám hộ.');
      }
    }
    d.step = 2;
    renderRoute();
  });

  document.getElementById('btnStep2Back')?.addEventListener('click', () => { syncCurrentStepInputs(); d.step = 1; renderRoute(); });
  document.getElementById('btnStep2Next')?.addEventListener('click', () => {
    syncCurrentStepInputs();
    if (!d.education_level || !d.institution_name || !d.current_occupation || !d.major_or_field) {
      return showErr('Vui lòng điền đầy đủ Trình độ học vấn, Trường/Đơn vị, Nghề nghiệp và Chuyên ngành.');
    }
    if (d.applicant_group === 'student_school' && !d.class_name) return showErr('Học sinh phổ thông bắt buộc nhập thông tin Lớp.');
    if ((d.applicant_group === 'student_uni' || d.applicant_group === 'researcher_lecturer') && !d.faculty_department) {
      return showErr('Vui lòng nhập thông tin Khoa / Bộ môn.');
    }
    if (d.applicant_group === 'specialist_staff' && !d.position_title) return showErr('Vui lòng nhập Chức vụ hiện tại.');
    d.step = 3;
    renderRoute();
  });

  document.getElementById('btnStep3Back')?.addEventListener('click', () => { syncCurrentStepInputs(); d.step = 2; renderRoute(); });
  document.getElementById('btnStep3Next')?.addEventListener('click', () => {
    syncCurrentStepInputs();
    if (d.id_document_type === 'CCCD' && !/^\d{12}$/.test(d.id_number)) {
      return showErr('Số Căn cước công dân (CCCD) bắt buộc gồm đúng 12 chữ số.');
    }
    if (d.id_document_type !== 'CCCD' && d.id_number.length < 6) {
      return showErr('Số giấy tờ định danh phải có ít nhất 6 ký tự.');
    }
    if (!d.id_issued_date || !d.id_issued_place) {
      return showErr('Vui lòng nhập đầy đủ Ngày cấp và Nơi cấp giấy tờ định danh.');
    }
    if (!d.personal_photo_r2_key) {
      return showErr('Bước 3 bắt buộc tải lên ảnh chân dung cá nhân trước khi tiếp tục.');
    }
    d.step = 4;
    renderRoute();
  });

  document.getElementById('btnStep4Back')?.addEventListener('click', () => { syncCurrentStepInputs(); d.step = 3; renderRoute(); });
  document.getElementById('btnStep4Next')?.addEventListener('click', () => {
    syncCurrentStepInputs();
    if (!d.research_or_project_interest || d.registration_purpose.length < 10) {
      return showErr('Vui lòng nhập Lĩnh vực quan tâm và Mục đích xin cấp tài khoản (tối thiểu 10 ký tự).');
    }
    d.step = 5;
    renderRoute();
  });

  document.getElementById('btnStep5Back')?.addEventListener('click', () => { syncCurrentStepInputs(); d.step = 4; renderRoute(); });

  // Step 5 signature: direct canvas drawing OR uploaded personal-signature image.
  const canvas = document.getElementById('signatureCanvas');
  const signatureFile = document.getElementById('fileSignatureImage');
  const signaturePreviewWrap = document.getElementById('signaturePreviewWrap');
  const signaturePreview = document.getElementById('signaturePreview');
  const directStatus = document.getElementById('signatureDirectStatus');
  const signatureStatus = document.getElementById('signatureUploadStatus');
  const refreshSignaturePreview = () => {
    if (signaturePreviewWrap) signaturePreviewWrap.hidden = !d.signature_data;
    if (signaturePreview) {
      signaturePreview.hidden = !(d.signature_data && d.signature_method === 'upload');
      if (d.signature_method === 'upload' && d.signature_data) signaturePreview.src = d.signature_data;
    }
    if (directStatus) directStatus.hidden = !(d.signature_data && d.signature_method === 'draw');
  };
  if (canvas) {
    const ctx = canvas.getContext('2d');
    ctx.strokeStyle = '#072556';
    ctx.lineWidth = 2.5;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    let drawing = false;
    let hasStroke = false;
    const getPos = e => {
      const rect = canvas.getBoundingClientRect();
      return { x: (e.clientX - rect.left) * (canvas.width / rect.width), y: (e.clientY - rect.top) * (canvas.height / rect.height) };
    };
    if (d.signature_data && d.signature_method === 'draw') {
      const image = new Image();
      image.onload = () => ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
      image.src = d.signature_data;
      hasStroke = true;
    }
    canvas.addEventListener('pointerdown', e => {
      e.preventDefault();
      drawing = true;
      canvas.setPointerCapture?.(e.pointerId);
      d.signature_method = 'draw';
      d.signature_data = '';
      if (signatureFile) signatureFile.value = '';
      if (signatureStatus) signatureStatus.textContent = 'Đang dùng chữ ký ký trực tiếp.';
      if (signaturePreview) signaturePreview.hidden = true;
      if (directStatus) directStatus.hidden = false;
      if (signaturePreviewWrap) signaturePreviewWrap.hidden = false;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      const p = getPos(e);
      ctx.beginPath();
      ctx.moveTo(p.x, p.y);
      ctx.lineTo(p.x + 0.01, p.y + 0.01);
      ctx.stroke();
      hasStroke = true;
      d.signature_data = canvas.toDataURL('image/png');
    });
    canvas.addEventListener('pointermove', e => {
      if (!drawing) return;
      const p = getPos(e);
      ctx.lineTo(p.x, p.y);
      ctx.stroke();
      hasStroke = true;
      d.signature_data = canvas.toDataURL('image/png');
      d.signature_method = 'draw';
      refreshSignaturePreview();
    });
    const finishDrawing = () => { drawing = false; if (hasStroke) { d.signature_data = canvas.toDataURL('image/png'); d.signature_method = 'draw'; refreshSignaturePreview(); } };
    canvas.addEventListener('pointerup', finishDrawing);
    canvas.addEventListener('pointercancel', finishDrawing);
    document.getElementById('btnClearSignature')?.addEventListener('click', () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      if (signatureFile) signatureFile.value = '';
      d.signature_data = '';
      d.signature_method = '';
      hasStroke = false;
      if (signatureStatus) signatureStatus.textContent = 'Chọn ảnh chữ ký cá nhân nếu không ký trực tiếp.';
      refreshSignaturePreview();
    });
  }
  signatureFile?.addEventListener('change', async () => {
    const file = signatureFile.files?.[0];
    if (!file) return;
    if (!['image/png','image/jpeg','image/webp'].includes(file.type) || file.size > 150 * 1024) {
      signatureFile.value = '';
      if (signatureStatus) signatureStatus.textContent = 'Tệp không hợp lệ. Chỉ chấp nhận PNG/JPG/WEBP tối đa 150 KB.';
      return showErr('Ảnh chữ ký phải là PNG, JPG hoặc WEBP và không vượt quá 150 KB.');
    }
    try {
      const source = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => resolve(String(reader.result || ''));
        reader.onerror = () => reject(new Error('Không đọc được ảnh chữ ký.'));
        reader.readAsDataURL(file);
      });
      const img = await new Promise((resolve, reject) => {
        const image = new Image(); image.onload = () => resolve(image); image.onerror = () => reject(new Error('Ảnh chữ ký không đọc được.')); image.src = source;
      });
      const staging = document.createElement('canvas');
      const scale = Math.min(1, 1000 / img.width, 300 / img.height);
      staging.width = Math.max(1, Math.round(img.width * scale));
      staging.height = Math.max(1, Math.round(img.height * scale));
      const c = staging.getContext('2d'); c.fillStyle = '#ffffff'; c.fillRect(0,0,staging.width,staging.height); c.drawImage(img,0,0,staging.width,staging.height);
      const normalized = staging.toDataURL('image/png');
      if (normalized.length > 340000) throw new Error('Ảnh chữ ký sau khi xử lý vẫn quá lớn. Vui lòng chọn ảnh đơn giản hơn.');
      d.signature_data = normalized;
      d.signature_method = 'upload';
      const ctx = canvas?.getContext('2d'); if (ctx && canvas) ctx.clearRect(0,0,canvas.width,canvas.height);
      if (signatureStatus) signatureStatus.textContent = `Đã chọn ảnh chữ ký: ${file.name}`;
      refreshSignaturePreview();
    } catch (err) {
      signatureFile.value = '';
      if (signatureStatus) signatureStatus.textContent = err.message;
      showErr(err.message);
    }
  });
  refreshSignaturePreview();

  document.getElementById('btnSubmitAccountReq')?.addEventListener('click', async () => {
    syncCurrentStepInputs();
    if (!d.signature_data) return showErr('Vui lòng ký trực tiếp hoặc tải ảnh chữ ký cá nhân trước khi gửi hồ sơ.');
    if (!d.data_accuracy_confirmed || !d.privacy_policy_accepted || !d.terms_accepted) {
      return showErr('Vui lòng đọc nội dung và tích chọn đầy đủ 3 xác nhận: tính chính xác, thông báo dữ liệu cá nhân và điều khoản sử dụng.');
    }
    const btn = document.getElementById('btnSubmitAccountReq');
    btn.disabled = true;
    btn.textContent = 'Đang gửi hồ sơ lên máy chủ D1...';
    try {
      const res = await apiFetch('/api/account-requests', {
        method: 'POST',
        body: JSON.stringify(d)
      });
      d.submittedResult = res;
      showToast(`Đã gửi hồ sơ thành công! Mã yêu cầu: ${res.request_code}`);
      renderRoute();
    } catch (err) {
      showErr(err.message);
      btn.disabled = false;
      btn.textContent = '✓ Gửi Hồ sơ Yêu cầu Cấp Tài khoản';
    }
  });
}

// ============================================================================
// VIEW 10: TRA CỨU YÊU CẦU (/tra-cuu) — Sanitized Minimal Lookup
// ============================================================================
function renderLookupView(vp, isVi) {
  const prefillCode = AppState.currentQuery.get('code') || '';
  vp.innerHTML = `
    <div class="container" style="max-width:740px;">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'TRA CỨU TIẾN ĐỘ XÉT DUYỆT' : 'APPLICATION STATUS LOOKUP'}</span>
          <h1 class="section-title">${isVi ? 'Tra cứu Trạng thái Yêu cầu Cấp Tài khoản' : 'Track Account Registration Request'}</h1>
          <p class="section-desc">
            ${isVi
              ? 'Nhập Mã yêu cầu (SCRD-SFN- kèm 10 chữ số) và Email đăng ký. Hệ thống chỉ trả về trạng thái xét duyệt và hướng dẫn bước tiếp theo, tuyệt đối không hiển thị CCCD, ảnh định danh hoặc thông tin nhạy cảm.'
              : 'Enter your Request Code (SCRD-SFN- + 10 digits) and registered Email. Sensitive identity data is never exposed.'}
          </p>
        </div>
      </div>
      <div class="doc-panel">
        <form id="lookupRequestForm">
          <div class="grid-2">
            <div class="form-group">
              <label class="form-label" for="inpLookupCode">${isVi ? 'Mã yêu cầu (SCRD-SFN-XXXXXXXXXX) *' : 'Request Code *'}</label>
              <input id="inpLookupCode" class="form-control" value="${esc(prefillCode)}" placeholder="SCRD-SFN-0000000000" required>
            </div>
            <div class="form-group">
              <label class="form-label" for="inpLookupEmail">${isVi ? 'Email đã đăng ký *' : 'Registered Email *'}</label>
              <input id="inpLookupEmail" type="email" class="form-control" placeholder="email@domain.com" required>
            </div>
          </div>
          <button type="submit" class="btn btn-primary" id="btnExecLookup">${isVi ? 'Tra cứu trạng thái' : 'Check Status'}</button>
        </form>
        <div id="lookupOutputArea" style="margin-top:20px;"></div>
      </div>
    </div>
  `;

  document.getElementById('lookupRequestForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const out = document.getElementById('lookupOutputArea');
    const btn = document.getElementById('btnExecLookup');
    btn.disabled = true;
    out.innerHTML = `<p>Đang truy vấn dữ liệu từ máy chủ...</p>`;
    try {
      const res = await apiFetch('/api/account-requests/lookup', {
        method: 'POST',
        body: JSON.stringify({
          request_code: document.getElementById('inpLookupCode').value.trim(),
          email: document.getElementById('inpLookupEmail').value.trim()
        })
      });
      const r = res.request;
      out.innerHTML = `
        <div class="card" style="background:#f8fafc;border-color:#93c5fd;">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;flex-wrap:wrap;gap:8px;">
            <strong style="font-size:18px;color:var(--navy-900);">${esc(r.request_code)}</strong>
            <span class="status-pill status-green">${esc(r.status)}</span>
          </div>
          <p style="font-size:13.5px;margin-bottom:8px;">
            • <strong>Thời điểm tiếp nhận:</strong> ${esc(r.submitted_at)}<br>
            • <strong>Cập nhật gần nhất:</strong> ${esc(r.updated_at)}<br>
            • <strong>Thông báo từ bộ phận xét duyệt:</strong> ${esc(r.reviewer_message)}<br>
            • <strong>Hướng dẫn bước tiếp theo:</strong> ${esc(r.next_step_guidance)}
          </p>
        </div>
      `;
    } catch (err) {
      out.innerHTML = `<div class="alert-box alert-error">${esc(err.message)}</div>`;
    } finally {
      btn.disabled = false;
    }
  });
}

// ============================================================================
// VIEW 11: QUÊN MẬT KHẨU & ĐẶT LẠI MẬT KHẨU (/quen-mat-khau)
// ============================================================================
function renderForgotPasswordView(vp, isVi) {
  const title = isVi ? 'Quên mật khẩu?' : 'Forgot your password?';
  const description = isVi
    ? 'Vì lý do bảo mật, việc khôi phục mật khẩu được hỗ trợ trực tiếp bởi quản trị viên. Vui lòng liên hệ quản trị viên hoặc gọi hotline để được hướng dẫn xác minh và khôi phục quyền truy cập.'
    : 'For account security, password recovery is handled by an administrator. Please contact your administrator or call the support hotline for identity verification and help restoring access.';
  vp.innerHTML = `
    <section class="container auth-help-page">
      <div class="auth-help-card">
        <div class="auth-help-icon" aria-hidden="true">🔐</div>
        <p class="eyebrow">${isVi ? 'HỖ TRỢ TÀI KHOẢN' : 'ACCOUNT SUPPORT'}</p>
        <h1 class="section-title">${title}</h1>
        <p class="section-desc">${description}</p>
        <div class="hotline-panel">
          <span>${isVi ? 'HOTLINE HỖ TRỢ' : 'SUPPORT HOTLINE'}</span>
          <a href="tel:0924910210">0924 910 210</a>
          <small>${isVi ? 'Vui lòng chuẩn bị email hoặc mã thành viên để quản trị viên hỗ trợ xác minh.' : 'Please have your registered email or member ID ready for verification.'}</small>
        </div>
        <div class="auth-help-actions">
          <a class="btn btn-primary" href="tel:0924910210">${isVi ? 'Gọi hotline' : 'Call hotline'}</a>
          <a class="auth-back-link" href="/dang-nhap" data-nav="/dang-nhap">${isVi ? 'Quay lại đăng nhập' : 'Back to sign in'}</a>
        </div>
      </div>
    </section>
  `;
}

// ============================================================================
// VIEW 12: ĐĂNG NHẬP HỆ THỐNG/CMS (/dang-nhap) & CONDITIONAL ONE-TIME BOOTSTRAP
// ============================================================================
function renderLoginView(vp, isVi) {
  if (AppState.currentUser) {
    navigateTo('/bang-dieu-khien', true);
    return;
  }

  vp.innerHTML = `
    <div class="container" style="max-width:580px;">
      <div class="section-head">
        <div>
          <span class="eyebrow">${isVi ? 'XÁC THỰC TÀI KHOẢN & PHÂN QUYỀN RBAC' : 'AUTHENTICATION & RBAC'}</span>
          <h1 class="section-title">${isVi ? 'Đăng nhập Hệ thống & Quản trị CMS' : 'System & CMS Sign In'}</h1>
        </div>
      </div>

      <div class="doc-panel">
        <form id="loginForm">
          <div class="form-group">
            <label class="form-label" for="inpLoginEmail">Email đăng nhập *</label>
            <input id="inpLoginEmail" type="email" class="form-control" autocomplete="username" required placeholder="tenban@domain.com">
          </div>
          <div class="form-group">
            <label class="form-label" for="inpLoginPassword">Mật khẩu *</label>
            <input id="inpLoginPassword" type="password" class="form-control" autocomplete="current-password" required placeholder="Nhập mật khẩu">
          </div>
          <div id="loginErrorMsg"></div>
          <div style="display:flex;justify-content:space-between;align-items:center;margin-top:16px;flex-wrap:wrap;gap:10px;">
            <button type="submit" class="btn btn-primary" id="btnSubmitLogin">${isVi ? 'Đăng nhập' : 'Sign In'}</button>
            <div style="font-size:13px;">
              <a href="/quen-mat-khau" data-nav="/quen-mat-khau">${isVi ? 'Quên mật khẩu?' : 'Forgot password?'}</a> •
              <a href="/dang-ky" data-nav="/dang-ky">${isVi ? 'Yêu cầu cấp tài khoản' : 'Request account'}</a>
            </div>
          </div>
        </form>

        <p class="auth-bootstrap-note">${isVi ? 'Khởi tạo quản trị viên đầu tiên được thực hiện qua quy trình quản trị hạ tầng được bảo vệ, không thực hiện tại trang công khai này.' : 'First-admin initialization is handled through the protected infrastructure process, not on this public page.'}</p>

      </div>
    </div>
  `;

  document.getElementById('loginForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const errBox = document.getElementById('loginErrorMsg');
    const btn = document.getElementById('btnSubmitLogin');
    btn.disabled = true;
    errBox.innerHTML = '';
    try {
      const res = await apiFetch('/api/auth/login', {
        method: 'POST',
        body: JSON.stringify({
          email: document.getElementById('inpLoginEmail').value.trim(),
          password: document.getElementById('inpLoginPassword').value
        })
      });
      AppState.token = res.token;
      AppState.csrfToken = res.csrf_token;
      AppState.currentUser = res.user;
      sessionStorage.setItem('skyfirst_token', res.token);
      sessionStorage.setItem('skyfirst_csrf', res.csrf_token);
      showToast(`Xin chào ${res.user.full_name}!`);
      navigateTo('/bang-dieu-khien');
    } catch (err) {
      errBox.innerHTML = `<div class="alert-box alert-error">${esc(err.message)}</div>`;
    } finally {
      btn.disabled = false;
    }
  });


}

// ============================================================================
// VIEW 13: KHU VỰC DASHBOARD & QUẢN TRỊ CMS (/bang-dieu-khien, /quan-tri)
// ============================================================================
async function renderDashboardView(vp, isVi) {
  if (!AppState.currentUser) {
    vp.innerHTML = `
      <div class="container">
        <div class="alert-box alert-error">
          <strong>401 — Yêu cầu xác thực:</strong> Khu vực Bảng điều khiển và Quản trị CMS chỉ dành cho tài khoản đã đăng nhập.
        </div>
        <a class="btn btn-primary" href="/dang-nhap" data-nav="/dang-nhap">Đến trang Đăng nhập →</a>
      </div>
    `;
    return;
  }

  vp.innerHTML = `<div class="container"><div class="empty-state"><h3>Đang tải dữ liệu phân quyền từ máy chủ...</h3></div></div>`;
  try {
    const [dashData, chatRes] = await Promise.all([
      apiFetch('/api/dashboard/overview'),
      apiFetch('/api/chat/rooms').catch(() => ({ rooms: [] }))
    ]);
    AppState.dashboardData = dashData;
    AppState.chatRooms = chatRes.rooms || [];
  } catch (err) {
    vp.innerHTML = `<div class="container"><div class="alert-box alert-error">${esc(err.message)}</div></div>`;
    return;
  }

  const u = AppState.currentUser;
  const isCmsRole = ['super_admin', 'cms_editor'].includes(u.role);
  const isReviewRole = ['super_admin', 'reviewer'].includes(u.role);
  const isSuperAdmin = u.role === 'super_admin';
  const tab = AppState.activeDashboardTab;

  vp.innerHTML = `
    <div class="container">
      <div class="section-head" style="margin-bottom:18px;">
        <div>
          <span class="eyebrow">KHU VỰC NỘI BỘ & QUẢN TRỊ HỆ THỐNG (RBAC: ${esc(u.role.toUpperCase())})</span>
          <h1 class="section-title">Xin chào, ${esc(u.full_name)}</h1>
        </div>
        <div style="display:flex;gap:10px;align-items:center;">
          <span class="status-pill status-green">${esc(u.email)} (${esc(u.sfn_id || u.role)})</span>
          <a class="btn btn-sm btn-secondary" href="/" data-nav="/">← Trang công khai</a>
        </div>
      </div>

      <div class="cms-shell">
        <aside class="cms-sidebar" aria-label="Menu bảng điều khiển">
          <div class="cms-nav-group">Cá nhân & Nghiệp vụ</div>
          <button type="button" class="cms-nav-btn ${tab === 'overview' ? 'active' : ''}" data-dash-tab="overview"><span>📊 Tổng quan cá nhân</span></button>
          <button type="button" class="cms-nav-btn ${tab === 'profile' ? 'active' : ''}" data-dash-tab="profile"><span>👤 Hồ sơ & Ảnh đại diện</span></button>
          <button type="button" class="cms-nav-btn ${tab === 'research_projects' ? 'active' : ''}" data-dash-tab="research_projects"><span>🔬 Nghiên cứu, Dự án & Tiến độ</span></button>
          <button type="button" class="cms-nav-btn ${tab === 'exams' ? 'active' : ''}" data-dash-tab="exams"><span>📝 Khảo thí & Kết quả</span></button>
          <button type="button" class="cms-nav-btn ${tab === 'chat' ? 'active' : ''}" data-dash-tab="chat"><span>💬 Chat riêng & Nhóm bảo mật</span></button>
          ${isSuperAdmin ? `<div class="cms-nav-group">Quản lý truy cập</div><button type="button" class="cms-nav-btn ${tab === 'users' ? 'active' : ''}" data-dash-tab="users"><span>👥 Người dùng & Vai trò</span></button>` : ''}

          ${isReviewRole ? `
            <div class="cms-nav-group">Xét duyệt & Quản trị</div>
            <button type="button" class="cms-nav-btn ${tab === 'requests' ? 'active' : ''}" data-dash-tab="requests">
              <span>🛡️ Duyệt Yêu cầu Tài khoản</span>
              <span>${(AppState.dashboardData?.admin?.account_requests || []).length}</span>
            </button>
          ` : ''}

          ${isCmsRole ? `
            <div class="cms-nav-group">Quản trị Nội dung CMS</div>
            <button type="button" class="cms-nav-btn ${tab === 'cms_posts' ? 'active' : ''}" data-dash-tab="cms_posts">
              <span>📰 Quản lý Bài viết</span>
              <span>${(AppState.dashboardData?.cms?.posts || []).length}</span>
            </button>
            <button type="button" class="cms-nav-btn ${tab === 'cms_pages' ? 'active' : ''}" data-dash-tab="cms_pages">
              <span>📄 Quản lý Trang Công khai</span>
              <span>${(AppState.dashboardData?.cms?.pages || []).length}</span>
            </button>
            <button type="button" class="cms-nav-btn ${tab === 'cms_menus' ? 'active' : ''}" data-dash-tab="cms_menus">
              <span>🔗 Menu, Footer 4 Cột & SEO</span>
            </button>
            <button type="button" class="cms-nav-btn ${tab === 'cms_media' ? 'active' : ''}" data-dash-tab="cms_media">
              <span>🖼️ Thư viện Media R2</span>
            </button>
          ` : ''}
        </aside>
        <div class="cms-main" id="dashboardTabViewport"></div>
      </div>
    </div>
  `;

  vp.querySelectorAll('[data-dash-tab]').forEach(btn => {
    btn.addEventListener('click', () => {
      AppState.activeDashboardTab = btn.getAttribute('data-dash-tab');
      renderDashboardView(vp, isVi);
    });
  });

  const subVp = document.getElementById('dashboardTabViewport');
  renderDashboardSubTab(subVp, tab, isVi);
}

async function renderDashboardSubTab(subVp, tab, isVi = AppState.lang === 'vi') {
  const d = AppState.dashboardData;
  const u = AppState.currentUser;

  if (tab === 'users') {
    if (u.role !== 'super_admin') { subVp.innerHTML = '<div class="alert-box alert-error">Chỉ super admin được quản lý tài khoản người dùng.</div>'; return; }
    subVp.innerHTML = `<h2>${isVi ? 'Quản lý người dùng và vai trò' : 'User and role management'}</h2><p class="section-desc">${isVi ? 'Chỉ super admin có thể thay đổi trạng thái/vai trò hoặc tạo mật khẩu tạm thời. Mật khẩu chỉ được hiển thị một lần.' : 'Only super admins can change roles/status or issue a temporary password. The password is displayed once.'}</p><div class="chat-loading"><span class="page-state-spinner"></span><p>${isVi ? 'Đang tải danh sách người dùng…' : 'Loading users…'}</p></div>`;
    try {
      const result = await apiFetch('/api/admin/users');
      const users = result.users || [];
      subVp.innerHTML = `<h2>${isVi ? 'Quản lý người dùng và vai trò' : 'User and role management'}</h2><p class="section-desc">${isVi ? 'Chỉ super admin có thể thay đổi trạng thái/vai trò hoặc tạo mật khẩu tạm thời. Mật khẩu chỉ được hiển thị một lần; xác minh danh tính người nhận qua kênh chính thức.' : 'Only super admins can change roles/status or issue a temporary password. Verify the recipient identity through an official channel.'}</p>${users.length ? `<div class="table-wrap"><table class="data-table"><thead><tr><th>${isVi?'Người dùng':'User'}</th><th>${isVi?'Vai trò':'Role'}</th><th>${isVi?'Trạng thái':'Status'}</th><th>${isVi?'Đăng nhập gần nhất':'Last login'}</th><th>${isVi?'Thao tác':'Actions'}</th></tr></thead><tbody>${users.map(x=>`<tr><td><strong>${esc(x.full_name)}</strong><br><small>${esc(x.email)}</small><br><code>${esc(x.sfn_id||x.id)}</code></td><td><select class="form-control admin-user-role" data-user-id="${esc(x.id)}" ${x.id===u.id?'disabled':''}>${['super_admin','cms_editor','reviewer','research_lead','researcher','project_manager','project_lead','examiner','member','student'].map(role=>`<option value="${role}" ${x.role===role?'selected':''}>${role}</option>`).join('')}</select></td><td><select class="form-control admin-user-status" data-user-id="${esc(x.id)}" ${x.id===u.id?'disabled':''}>${[['active','Đang hoạt động'],['pending','Chờ kích hoạt'],['suspended','Tạm khóa'],['locked','Đã khóa']].map(([value,label])=>`<option value="${value}" ${x.status===value?'selected':''}>${isVi?label:value}</option>`).join('')}</select></td><td>${esc(x.last_login_at||'—')}</td><td><div class="admin-user-actions"><button type="button" class="btn btn-sm btn-primary btn-save-admin-user" data-user-id="${esc(x.id)}" ${x.id===u.id?'disabled':''}>${isVi?'Lưu quyền':'Save'}</button><button type="button" class="btn btn-sm btn-secondary btn-issue-temp-password" data-user-id="${esc(x.id)}">${isVi?'Tạo mật khẩu tạm':'Issue temp password'}</button></div></td></tr>`).join('')}</tbody></table></div>` : `<div class="empty-state">${isVi?'Chưa có tài khoản người dùng.':'No user accounts found.'}</div>`}`;
      subVp.querySelectorAll('.btn-save-admin-user').forEach(btn=>btn.addEventListener('click',async()=>{const id=btn.dataset.userId;const role=subVp.querySelector(`.admin-user-role[data-user-id="${CSS.escape(id)}"]`)?.value;const status=subVp.querySelector(`.admin-user-status[data-user-id="${CSS.escape(id)}"]`)?.value;btn.disabled=true;try{await apiFetch(`/api/admin/users/${encodeURIComponent(id)}`,{method:'PATCH',body:JSON.stringify({role,status})});showToast(isVi?'Đã cập nhật quyền và trạng thái người dùng.':'User role and status updated.');await renderDashboardSubTab(subVp,'users',isVi);}catch(err){showToast(err.message,true);btn.disabled=false;}}));
      subVp.querySelectorAll('.btn-issue-temp-password').forEach(btn=>btn.addEventListener('click',async()=>{const id=btn.dataset.userId;if(!window.confirm(isVi?'Tạo mật khẩu tạm mới, kích hoạt tài khoản và thu hồi các phiên cũ? Chỉ tiếp tục sau khi đã xác minh danh tính người nhận.':'Issue a new temporary password, activate the account and revoke old sessions? Continue only after verifying the recipient identity.'))return;btn.disabled=true;try{const result=await apiFetch(`/api/admin/users/${encodeURIComponent(id)}/temporary-password`,{method:'POST',body:JSON.stringify({})});window.alert(`${isVi?'MẬT KHẨU TẠM THỜI — CHỈ HIỂN THỊ MỘT LẦN':'TEMPORARY PASSWORD — SHOWN ONCE'}

${result.full_name} (${result.email})
${result.temporary_password}

${isVi?'Hãy bàn giao qua kênh đã xác minh. Không gửi mật khẩu qua nhóm chat hoặc email không an toàn.':'Share only through a verified channel. Do not send this password in group chat or insecure email.'}`);showToast(isVi?'Đã tạo mật khẩu tạm, tài khoản được kích hoạt và các phiên cũ bị thu hồi.':'Temporary password issued; account activated and old sessions revoked.');await renderDashboardSubTab(subVp,'users',isVi);}catch(err){showToast(err.message,true);btn.disabled=false;}}));
    } catch (err) { subVp.innerHTML = `<div class="alert-box alert-error">${esc(err.message)}</div>`; }
    return;
  }

  if (tab === 'overview') {
    subVp.innerHTML = `
      <h2 style="margin-bottom:14px;color:var(--navy-900);">Tổng quan Hoạt động trên Hệ thống D1</h2>
      <div class="grid-4" style="margin-bottom:24px;">
        <div class="card"><h4>Đề tài Nghiên cứu</h4><div style="font-size:26px;font-weight:800;color:var(--navy-800);">${(d.research_studies || []).length}</div></div>
        <div class="card"><h4>Dự án Cộng đồng</h4><div style="font-size:26px;font-weight:800;color:var(--emerald-600);">${(d.community_projects || []).length}</div></div>
        <div class="card"><h4>Nhiệm vụ Công việc</h4><div style="font-size:26px;font-weight:800;color:var(--blue-600);">${(d.tasks || []).length}</div></div>
        <div class="card"><h4>Lượt Dự thi của tôi</h4><div style="font-size:26px;font-weight:800;color:var(--amber-600);">${(d.my_exam_attempts || []).length}</div></div>
      </div>
      <div class="card">
        <h3>Thông tin Phiên Xác thực</h3>
        <p style="margin-top:8px;">
          • Họ và tên: <strong>${esc(u.full_name)}</strong><br>
          • Mã thành viên: <code>${esc(u.sfn_id || 'Chưa cấp')}</code><br>
          • Email: <strong>${esc(u.email)}</strong><br>
          • Vai trò phân quyền (RBAC): <span class="status-pill status-blue">${esc(u.role)}</span>
        </p>
      </div>
    `;
    return;
  }

  if (tab === 'profile') {
    subVp.innerHTML = `
      <h2 style="margin-bottom:14px;color:var(--navy-900);">Hồ sơ Tài khoản & Ảnh đại diện (Lưu trữ R2)</h2>
      <div class="card" style="max-width:680px;">
        <div style="display:flex;align-items:center;gap:20px;margin-bottom:20px;flex-wrap:wrap;">
          <img id="currentAvatarPreview" src="${esc(u.avatar_url || '/assets/sky-first-logo-trimmed.webp')}" alt="Avatar" style="width:88px;height:88px;object-fit:contain;border-radius:12px;border:1px solid var(--line-200);background:#fff;padding:6px;">
          <div>
            <h3>${esc(u.full_name)}</h3>
            <p style="margin:4px 0;">Email: <strong>${esc(u.email)}</strong></p>
            <label class="btn btn-sm btn-secondary" style="cursor:pointer;">
              📷 Tải ảnh đại diện mới từ thiết bị
              <input type="file" id="inpAvatarFile" accept="image/jpeg,image/png,image/webp" style="display:none;">
            </label>
          </div>
        </div>
        <form id="profileUpdateForm">
          <div class="grid-2">
            <div class="form-group"><label class="form-label">Họ và tên *</label><input id="profFullName" class="form-control" value="${esc(u.full_name)}" required></div>
            <div class="form-group"><label class="form-label">Đơn vị / Tổ chức</label><input id="profOrg" class="form-control" value="${esc(u.organization || '')}"></div>
            <div class="form-group"><label class="form-label">Khoa / Phòng ban</label><input id="profDept" class="form-control" value="${esc(u.department || '')}"></div>
            <div class="form-group"><label class="form-label">Học hàm / Học vị / Chức danh</label><input id="profTitle" class="form-control" value="${esc(u.academic_title || '')}"></div>
          </div>
          <button type="submit" class="btn btn-primary">Lưu cập nhật hồ sơ</button>
        </form>
      </div>
    `;

    document.getElementById('inpAvatarFile')?.addEventListener('change', async e => {
      const file = e.target.files?.[0];
      if (!file) return;
      const fd = new FormData();
      fd.set('file', file);
      try {
        const res = await apiFetch('/api/profile/avatar', { method: 'POST', body: fd });
        AppState.currentUser.avatar_url = res.avatar_url;
        document.getElementById('currentAvatarPreview').src = res.avatar_url;
        showToast('Cập nhật ảnh đại diện lên R2 thành công!');
      } catch (err) {
        showToast(err.message, true);
      }
    });

    document.getElementById('profileUpdateForm')?.addEventListener('submit', async e => {
      e.preventDefault();
      try {
        const res = await apiFetch('/api/profile', {
          method: 'PUT',
          body: JSON.stringify({
            full_name: document.getElementById('profFullName').value.trim(),
            organization: document.getElementById('profOrg').value.trim(),
            department: document.getElementById('profDept').value.trim(),
            academic_title: document.getElementById('profTitle').value.trim()
          })
        });
        AppState.currentUser.full_name = res.full_name;
        renderShell();
        showToast('Đã lưu thông tin hồ sơ vào D1!');
      } catch (err) {
        showToast(err.message, true);
      }
    });
    return;
  }

  if (tab === 'cms_posts') {
    const posts = d.cms?.posts || [];
    subVp.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;flex-wrap:wrap;gap:10px;">
        <div>
          <h2 style="color:var(--navy-900);">${isVi ? 'Quản lý bài viết CMS' : 'CMS article management'}</h2>
          <p style="font-size:13px;color:var(--ink-700);">${isVi ? 'Tạo, chỉnh sửa nội dung tiếng Việt/Anh, SEO, nhãn, trạng thái xuất bản và xóa bài viết. Bài viết có hỗ trợ AI vẫn cần được biên tập và duyệt trước khi công bố.' : 'Create and edit Vietnamese/English content, SEO fields, tags, publication status, and delete articles. AI-assisted drafts still require editorial review before publication.'}</p>
        </div>
        <button type="button" class="btn btn-primary" id="btnNewCmsPost">+ Tạo bài viết mới</button>
      </div>
      <div id="cmsPostEditorArea" style="margin-bottom:20px;"></div>
      <table class="data-table">
        <thead>
          <tr><th>Tiêu đề & Slug</th><th>Chuyên mục</th><th>Nguồn</th><th>Trạng thái</th><th>Thao tác</th></tr>
        </thead>
        <tbody>
          ${posts.map(p => `
            <tr>
              <td><strong>${esc(p.title_vi)}</strong><br><code>/${esc(p.slug)}</code></td>
              <td>${esc(p.category)}</td>
              <td>${Number(p.is_ai_generated) === 1 ? `<span class="status-pill status-amber">${isVi ? 'Bản nháp có AI hỗ trợ' : 'AI-assisted draft'}</span>` : `<span class="status-pill status-blue">${isVi ? 'Biên tập viên' : 'Editor'}</span>`}</td>
              <td><span class="status-pill ${p.status === 'published' ? 'status-green' : 'status-amber'}">${esc(p.status)}</span></td>
              <td style="display:flex;gap:6px;flex-wrap:wrap;">
                <button type="button" class="btn btn-sm btn-secondary btn-edit-post" data-post-id="${esc(p.id)}">✏️ Sửa</button>
                <button type="button" class="btn btn-sm ${p.status === 'published' ? 'btn-secondary' : 'btn-emerald'} btn-toggle-post" data-post-id="${esc(p.id)}">
                  ${p.status === 'published' ? 'Gỡ xuất bản' : 'Xuất bản'}
                </button>
                <button type="button" class="btn btn-sm btn-danger btn-del-post" data-post-id="${esc(p.id)}">Xóa</button>
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;

    const openPostForm = postObj => {
      const p = postObj || { id: '', title_vi: '', title_en: '', slug: '', category: 'Tin tức và Hoạt động', excerpt_vi: '', excerpt_en: '', content_vi: '', content_en: '', featured_image_url: '', tags_json: '[]', seo_title: '', seo_description: '', status: 'draft', is_ai_generated: 0 };
      const area = document.getElementById('cmsPostEditorArea');
      area.innerHTML = `
        <div class="card" style="border:2px solid var(--blue-600);">
          <h3>${p.id ? 'Chỉnh sửa Bài viết CMS' : 'Tạo Bài viết CMS Mới'}</h3>
          <form id="cmsPostForm" style="margin-top:12px;">
            <div class="grid-3">
              <div class="form-group"><label class="form-label">Tiêu đề (VI) *</label><input id="pTitleVi" class="form-control" value="${esc(p.title_vi)}" required></div>
              <div class="form-group"><label class="form-label">Tiêu đề (EN)</label><input id="pTitleEn" class="form-control" value="${esc(p.title_en || '')}"></div>
              <div class="form-group"><label class="form-label">Slug URL *</label><input id="pSlug" class="form-control" value="${esc(p.slug)}" required></div>
            </div>
            <div class="grid-3">
              <div class="form-group"><label class="form-label">Chuyên mục *</label><input id="pCat" class="form-control" value="${esc(p.category)}" required></div>
              <div class="form-group"><label class="form-label">SEO Title</label><input id="pSeoTitle" class="form-control" value="${esc(p.seo_title || '')}"></div>
              <div class="form-group"><label class="form-label">Trạng thái</label>
                <select id="pStatus" class="form-control">
                  <option value="draft" ${p.status === 'draft' ? 'selected' : ''}>Bản nháp (draft)</option>
                  <option value="published" ${p.status === 'published' ? 'selected' : ''}>Xuất bản (published)</option>
                  <option value="unpublished" ${p.status === 'unpublished' ? 'selected' : ''}>Gỡ xuất bản (unpublished)</option>
                </select>
              </div>
            </div>
            <div class="grid-2"><div class="form-group"><label class="form-label">Tóm tắt (VI)</label><textarea id="pExcerptVi" class="form-control" rows="2">${esc(p.excerpt_vi || '')}</textarea></div><div class="form-group"><label class="form-label">Excerpt (EN)</label><textarea id="pExcerptEn" class="form-control" rows="2">${esc(p.excerpt_en || '')}</textarea></div></div>
            <div class="form-group"><label class="form-label">SEO Description</label><input id="pSeoDesc" class="form-control" value="${esc(p.seo_description || '')}"></div>
            <div class="grid-2"><div class="form-group"><label class="form-label">Nội dung HTML (VI) *</label><textarea id="pContentVi" class="form-control" rows="7" required>${esc(p.content_vi || '')}</textarea></div><div class="form-group"><label class="form-label">Content HTML (EN)</label><textarea id="pContentEn" class="form-control" rows="7">${esc(p.content_en || '')}</textarea></div></div>
            <div class="grid-2"><div class="form-group"><label class="form-label">Ảnh đại diện (URL hợp lệ, nếu có)</label><input id="pFeaturedImage" class="form-control" type="url" value="${esc(p.featured_image_url || '')}"></div><div class="form-group"><label class="form-label">Tags (JSON array)</label><input id="pTags" class="form-control" value="${esc(p.tags_json || '[]')}" placeholder='["nghiên cứu","cộng đồng"]'></div></div>
            <div style="display:flex;gap:10px;">
              <button type="submit" class="btn btn-primary">Lưu lên Backend D1</button>
              <button type="button" class="btn btn-secondary" id="btnCancelPostEdit">Đóng</button>
            </div>
          </form>
        </div>
      `;
      document.getElementById('btnCancelPostEdit')?.addEventListener('click', () => { area.innerHTML = ''; });
      document.getElementById('cmsPostForm')?.addEventListener('submit', async e => {
        e.preventDefault();
        const submitButton = e.submitter || e.target.querySelector('button[type="submit"]');
        if (submitButton) submitButton.disabled = true;
        try {
          await apiFetch('/api/cms/posts', {
            method: 'POST',
            body: JSON.stringify({
              id: p.id || undefined,
              title_vi: document.getElementById('pTitleVi').value.trim(),
              title_en: document.getElementById('pTitleEn').value.trim(),
              slug: document.getElementById('pSlug').value.trim(),
              category: document.getElementById('pCat').value.trim(),
              seo_title: document.getElementById('pSeoTitle').value.trim(),
              seo_description: document.getElementById('pSeoDesc').value.trim(),
              status: document.getElementById('pStatus').value,
              excerpt_vi: document.getElementById('pExcerptVi').value.trim(),
              excerpt_en: document.getElementById('pExcerptEn').value.trim(),
              content_vi: document.getElementById('pContentVi').value.trim(),
              content_en: document.getElementById('pContentEn').value.trim(),
              featured_image_url: document.getElementById('pFeaturedImage').value.trim(),
              tags_json: document.getElementById('pTags').value.trim() || '[]',
              is_ai_generated: Boolean(p.is_ai_generated),
              explicit_publish: document.getElementById('pStatus').value === 'published'
            })
          });
          await loadInitialData();
          showToast(AppState.lang === 'vi' ? 'Đã lưu bài viết vào cơ sở dữ liệu.' : 'Article saved to the database.');
          renderRoute();
        } catch (err) {
          showToast(err.message, true);
          if (submitButton) submitButton.disabled = false;
        }
      });
    };

    document.getElementById('btnNewCmsPost')?.addEventListener('click', () => openPostForm(null));
    subVp.querySelectorAll('.btn-edit-post').forEach(btn => {
      btn.addEventListener('click', () => {
        const post = posts.find(x => String(x.id) === btn.getAttribute('data-post-id'));
        if (post) openPostForm(post);
      });
    });
    subVp.querySelectorAll('.btn-toggle-post').forEach(btn => {
      btn.addEventListener('click', async () => {
        const post = posts.find(x => String(x.id) === btn.getAttribute('data-post-id'));
        if (!post) return;
        const nextStatus = post.status === 'published' ? 'unpublished' : 'published';
        if (nextStatus === 'published' && !window.confirm(AppState.lang === 'vi' ? `Xác nhận biên tập và xuất bản “${post.title_vi}”?` : `Confirm editorial review and publish “${post.title_en || post.title_vi}”?`)) return;
        try {
          await apiFetch('/api/cms/posts', {
            method: 'POST',
            body: JSON.stringify({ ...post, status: nextStatus, explicit_publish: nextStatus === 'published' })
          });
          await loadInitialData();
          showToast(`Đã chuyển trạng thái bài viết sang ${nextStatus}!`);
          renderRoute();
        } catch (err) {
          showToast(err.message, true);
        }
      });
    });
    subVp.querySelectorAll('.btn-del-post').forEach(btn => {
      btn.addEventListener('click', async () => {
        const postId = btn.getAttribute('data-post-id');
        if (!window.confirm('Bạn có chắc chắn muốn xóa bài viết này khỏi D1?')) return;
        try {
          await apiFetch(`/api/cms/posts/${encodeURIComponent(postId)}`, { method: 'DELETE' });
          await loadInitialData();
          showToast('Đã xóa bài viết khỏi D1.');
          renderRoute();
        } catch (err) {
          showToast(err.message, true);
        }
      });
    });
    return;
  }

  if (tab === 'cms_pages') {
    const isVi = AppState.lang === 'vi';
    const pages = d.cms?.pages || [];
    const protectedSlugs = new Set(['tong-quan','trang-chu-noi-dung','su-menh-tam-nhin','co-cau-to-chuc','linh-vuc-hoat-dong','lien-he','chinh-sach-bao-ve-du-lieu','dieu-khoan-su-dung','huong-dan-su-dung','ho-tro-nguoi-dung','an-toan-thong-tin']);
    subVp.innerHTML = `
      <h2 style="margin-bottom:14px;color:var(--navy-900);">${isVi ? 'Quản lý trang và chính sách' : 'Pages and policies'}</h2>
      <p style="margin-bottom:14px;color:var(--ink-600);">${isVi ? 'Nội dung được lưu trong D1. Trang hệ thống có thể chỉnh sửa, chuyển trạng thái hoặc lưu trữ; các trang cốt lõi không thể xóa nhầm.' : 'Content is stored in D1. System pages can be edited, unpublished, or archived; protected core pages cannot be accidentally deleted.'}</p>
      <div style="margin-bottom:16px;display:flex;gap:10px;flex-wrap:wrap;">
        <button type="button" class="btn btn-primary" id="btnNewCmsPage">${isVi ? '+ Tạo trang mới' : '+ Create page'}</button>
      </div>
      <div id="cmsPageEditorArea" style="margin-bottom:20px;"></div>
      <div style="overflow-x:auto;">
        <table class="data-table">
          <thead><tr><th>${isVi ? 'Tiêu đề (VI / EN)' : 'Title (VI / EN)'}</th><th>Slug</th><th>${isVi ? 'Nhóm' : 'Group'}</th><th>${isVi ? 'Phiên bản' : 'Version'}</th><th>${isVi ? 'Trạng thái' : 'Status'}</th><th>${isVi ? 'Thao tác' : 'Actions'}</th></tr></thead>
          <tbody>
            ${pages.map(pg => `
              <tr>
                <td><strong>${esc(pg.title_vi)}</strong><br><small>${esc(pg.title_en)}</small></td>
                <td><code>${esc(pg.slug)}</code></td>
                <td>${esc(pg.page_group || 'general')}</td>
                <td>v${Number(pg.version || 1)}</td>
                <td><span class="status-pill ${pg.status === 'published' ? 'status-green' : 'status-blue'}">${esc(pg.status)}</span></td>
                <td><div style="display:flex;gap:6px;flex-wrap:wrap;">
                  <button type="button" class="btn btn-sm btn-secondary btn-edit-page" data-page-id="${esc(pg.id)}">${isVi ? 'Chỉnh sửa' : 'Edit'}</button>
                  <button type="button" class="btn btn-sm btn-secondary btn-toggle-page" data-page-id="${esc(pg.id)}">${pg.status === 'published' ? (isVi ? 'Gỡ xuất bản' : 'Unpublish') : (isVi ? 'Xuất bản' : 'Publish')}</button>
                  ${protectedSlugs.has(pg.slug) ? '' : `<button type="button" class="btn btn-sm btn-secondary btn-delete-page" data-page-id="${esc(pg.id)}">${isVi ? 'Xóa' : 'Delete'}</button>`}
                </div></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;

    const openPageEditor = (existing = null) => {
      const pg = existing || { id: '', slug: '', title_vi: '', title_en: '', summary_vi: '', summary_en: '', content_vi: '', content_en: '', seo_title_vi: '', seo_title_en: '', seo_description_vi: '', seo_description_en: '', sort_order: pages.length + 1, page_group: 'about', status: 'draft', version: 0 };
      const area = document.getElementById('cmsPageEditorArea');
      area.innerHTML = `
        <div class="card" style="border:2px solid var(--blue-600);">
          <div style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;">
            <h3>${existing ? (isVi ? `Chỉnh sửa trang: ${esc(pg.title_vi)}` : `Edit page: ${esc(pg.title_en || pg.title_vi)}`) : (isVi ? 'Tạo trang mới' : 'Create a page')}</h3>
            <button type="button" class="btn btn-sm btn-secondary" id="btnCancelPageEdit">${isVi ? 'Đóng trình soạn thảo' : 'Close editor'}</button>
          </div>
          <form id="cmsPageForm" style="margin-top:12px;">
            <div class="grid-3">
              <div class="form-group"><label class="form-label" for="pgSlug">Slug *</label><input id="pgSlug" class="form-control" value="${esc(pg.slug)}" pattern="[a-z0-9_/-]+" required maxlength="180"></div>
              <div class="form-group"><label class="form-label" for="pgTitleVi">${isVi ? 'Tiêu đề (VI) *' : 'Title (VI) *'}</label><input id="pgTitleVi" class="form-control" value="${esc(pg.title_vi)}" required maxlength="250"></div>
              <div class="form-group"><label class="form-label" for="pgTitleEn">Title (EN) *</label><input id="pgTitleEn" class="form-control" value="${esc(pg.title_en || '')}" required maxlength="250"></div>
            </div>
            <div class="grid-2"><div class="form-group"><label class="form-label">${isVi ? 'Tóm tắt (VI)' : 'Summary (VI)'}</label><textarea id="pgSummaryVi" class="form-control" rows="2" maxlength="3000">${esc(pg.summary_vi || '')}</textarea></div><div class="form-group"><label class="form-label">Summary (EN)</label><textarea id="pgSummaryEn" class="form-control" rows="2" maxlength="3000">${esc(pg.summary_en || '')}</textarea></div></div>
            <div class="grid-2"><div class="form-group"><label class="form-label">${isVi ? 'Nội dung HTML (VI) *' : 'Content HTML (VI) *'}</label><textarea id="pgContentVi" class="form-control" rows="9" required>${esc(pg.content_vi || '')}</textarea></div><div class="form-group"><label class="form-label">Content HTML (EN) *</label><textarea id="pgContentEn" class="form-control" rows="9" required>${esc(pg.content_en || '')}</textarea></div></div>
            <div class="grid-3"><div class="form-group"><label class="form-label">SEO title (VI)</label><input id="pgSeoTitleVi" class="form-control" value="${esc(pg.seo_title_vi || '')}" maxlength="250"></div><div class="form-group"><label class="form-label">SEO title (EN)</label><input id="pgSeoTitleEn" class="form-control" value="${esc(pg.seo_title_en || '')}" maxlength="250"></div><div class="form-group"><label class="form-label">${isVi ? 'Thứ tự' : 'Sort order'}</label><input id="pgSortOrder" class="form-control" type="number" min="0" max="9999" value="${Number(pg.sort_order || 1)}"></div></div>
            <div class="grid-2"><div class="form-group"><label class="form-label">SEO description (VI)</label><textarea id="pgSeoDescVi" class="form-control" rows="2" maxlength="500">${esc(pg.seo_description_vi || '')}</textarea></div><div class="form-group"><label class="form-label">SEO description (EN)</label><textarea id="pgSeoDescEn" class="form-control" rows="2" maxlength="500">${esc(pg.seo_description_en || '')}</textarea></div></div>
            <div class="grid-3">
              <div class="form-group"><label class="form-label">${isVi ? 'Nhóm trang' : 'Page group'}</label><select id="pgGroup" class="form-control">${[['home','Trang chủ / Home'],['about','Giới thiệu / About'],['policy','Chính sách / Policy'],['support','Hỗ trợ / Support'],['cooperation','Hợp tác / Cooperation'],['general','Khác / General']].map(([v,l])=>`<option value="${v}" ${pg.page_group===v?'selected':''}>${l}</option>`).join('')}</select></div>
              <div class="form-group"><label class="form-label">${isVi ? 'Trạng thái' : 'Status'}</label><select id="pgStatus" class="form-control">${[['draft','Bản nháp / Draft'],['published','Đã xuất bản / Published'],['unpublished','Đã gỡ / Unpublished'],['archived','Lưu trữ / Archived']].map(([v,l])=>`<option value="${v}" ${pg.status===v?'selected':''}>${l}</option>`).join('')}</select></div>
              <div class="form-group" style="display:flex;align-items:end;"><button type="submit" class="btn btn-primary" style="width:100%;">${isVi ? 'Lưu trang vào D1' : 'Save page to D1'}</button></div>
            </div>
          </form>
        </div>
      `;
      document.getElementById('btnCancelPageEdit')?.addEventListener('click', () => { area.innerHTML = ''; });
      document.getElementById('cmsPageForm')?.addEventListener('submit', async e => {
        e.preventDefault();
        const saveButton = e.submitter || e.target.querySelector('button[type="submit"]');
        if (saveButton) saveButton.disabled = true;
        try {
          await apiFetch('/api/cms/pages', {
            method: 'POST',
            body: JSON.stringify({
              id: pg.id || undefined,
              slug: document.getElementById('pgSlug').value.trim(),
              title_vi: document.getElementById('pgTitleVi').value.trim(),
              title_en: document.getElementById('pgTitleEn').value.trim(),
              content_vi: document.getElementById('pgContentVi').value.trim(),
              content_en: document.getElementById('pgContentEn').value.trim(),
              summary_vi: document.getElementById('pgSummaryVi').value.trim(),
              summary_en: document.getElementById('pgSummaryEn').value.trim(),
              seo_title_vi: document.getElementById('pgSeoTitleVi').value.trim(),
              seo_title_en: document.getElementById('pgSeoTitleEn').value.trim(),
              seo_description_vi: document.getElementById('pgSeoDescVi').value.trim(),
              seo_description_en: document.getElementById('pgSeoDescEn').value.trim(),
              sort_order: Number(document.getElementById('pgSortOrder').value || 1),
              page_group: document.getElementById('pgGroup').value,
              status: document.getElementById('pgStatus').value
            })
          });
          await loadInitialData();
          showToast(isVi ? 'Đã lưu trang vào D1 thành công.' : 'Page saved to D1.');
          renderRoute();
        } catch (err) {
          showToast(err.message, true);
          if (saveButton) saveButton.disabled = false;
        }
      });
    };

    document.getElementById('btnNewCmsPage')?.addEventListener('click', () => openPageEditor());
    subVp.querySelectorAll('.btn-edit-page').forEach(btn => btn.addEventListener('click', () => {
      const pg = pages.find(x => String(x.id) === btn.getAttribute('data-page-id'));
      if (pg) openPageEditor(pg);
    }));
    subVp.querySelectorAll('.btn-toggle-page').forEach(btn => btn.addEventListener('click', async () => {
      const pg = pages.find(x => String(x.id) === btn.getAttribute('data-page-id'));
      if (!pg) return;
      const nextStatus = pg.status === 'published' ? 'unpublished' : 'published';
      if (nextStatus === 'published' && !window.confirm(isVi ? `Xuất bản trang “${pg.title_vi}”?` : `Publish “${pg.title_en || pg.title_vi}”?`)) return;
      try {
        await apiFetch('/api/cms/pages', { method: 'POST', body: JSON.stringify({ ...pg, status: nextStatus }) });
        await loadInitialData();
        showToast(isVi ? `Đã đổi trạng thái trang sang ${nextStatus}.` : `Page status changed to ${nextStatus}.`);
        renderRoute();
      } catch (err) { showToast(err.message, true); }
    }));
    subVp.querySelectorAll('.btn-delete-page').forEach(btn => btn.addEventListener('click', async () => {
      const pg = pages.find(x => String(x.id) === btn.getAttribute('data-page-id'));
      if (!pg || !window.confirm(isVi ? `Xóa vĩnh viễn trang “${pg.title_vi}”? Thao tác này không thể hoàn tác.` : `Permanently delete “${pg.title_en || pg.title_vi}”? This cannot be undone.`)) return;
      try {
        await apiFetch(`/api/cms/pages/${encodeURIComponent(pg.id)}`, { method: 'DELETE' });
        await loadInitialData();
        showToast(isVi ? 'Đã xóa trang.' : 'Page deleted.');
        renderRoute();
      } catch (err) { showToast(err.message, true); }
    }));
    return;
  }

  if (tab === 'cms_menus') {
    const menus = d.cms?.menus || [];
    subVp.innerHTML = `
      <h2 style="margin-bottom:14px;color:var(--navy-900);">Quản lý Menu Chính, 4 Cột Footer & Cấu hình Trang chủ</h2>
      <div class="card" style="margin-bottom:20px;">
        <h3>Thêm / Cập nhật Mục Menu hoặc Liên kết Footer</h3>
        <form id="cmsMenuForm" style="margin-top:12px;">
          <input id="mId" type="hidden" value="">
          <div class="grid-3">
            <div class="form-group">
              <label class="form-label">Vị trí hiển thị</label>
              <select id="mLocation" class="form-control">
                <option value="main_header">Menu chính (main_header)</option>
                <option value="footer_col_2">Footer Cột 2 — Về Trung tâm</option>
                <option value="footer_col_3">Footer Cột 3 — Kết nối Sky First</option>
                <option value="footer_col_4">Footer Cột 4 — Tài khoản Trung tâm</option>
                <option value="footer_bottom">Footer Chính sách dưới cùng</option>
              </select>
            </div>
            <div class="form-group"><label class="form-label">Nhãn Tiếng Việt *</label><input id="mLabelVi" class="form-control" required></div>
            <div class="form-group"><label class="form-label">Nhãn Tiếng Anh *</label><input id="mLabelEn" class="form-control" required></div>
            <div class="form-group"><label class="form-label">Đường dẫn đích (URL) *</label><input id="mTargetUrl" class="form-control" placeholder="/gioi-thieu" required></div>
            <div class="form-group"><label class="form-label">Thứ tự</label><input id="mSortOrder" type="number" class="form-control" value="1"></div>
            <div class="form-group"><label class="form-label"><input id="mVisible" type="checkbox" checked> Hiển thị</label></div>
            <div class="form-group"><label class="form-label"><input id="mNewTab" type="checkbox"> Mở tab mới</label></div>
          </div>
          <button type="submit" class="btn btn-primary" id="btnSaveMenu">Lưu Mục Điều hướng vào D1</button> <button type="button" class="btn btn-secondary" id="btnResetMenu">Mục mới / Làm trống biểu mẫu</button>
        </form>
      </div>
      <div class="grid-2" style="margin-bottom:20px;">
        <div class="card">
          <h3>Cập nhật Nội dung Banner & Cấu hình Trang chủ (VI/EN)</h3>
          <form id="cmsSettingsForm" style="margin-top:10px;">
            <div class="form-group"><label class="form-label">Tiêu đề Banner (VI)</label><input id="setHeroTitleVi" class="form-control" value="${esc(AppState.settings.hero_title_vi || "")}"></div>
            <div class="form-group"><label class="form-label">Tiêu đề Banner (EN)</label><input id="setHeroTitleEn" class="form-control" value="${esc(AppState.settings.hero_title_en || "")}"></div>
            <div class="grid-2"><div class="form-group"><label class="form-label">Mô tả Banner (VI)</label><textarea id="setHeroSubVi" class="form-control" rows="3">${esc(AppState.settings.hero_subtitle_vi || "")}</textarea></div><div class="form-group"><label class="form-label">Hero subtitle (EN)</label><textarea id="setHeroSubEn" class="form-control" rows="3">${esc(AppState.settings.hero_subtitle_en || "")}</textarea></div></div>
            <button type="submit" class="btn btn-primary btn-sm">Lưu Cấu hình Trang chủ vào D1</button>
          </form>
        </div>
        <div class="card">
          <h3>Quản lý Chuyển hướng URL (Redirects 301/302)</h3>
          <form id="cmsRedirectForm" style="margin-top:10px;">
            <div class="grid-2">
              <div class="form-group"><label class="form-label">Đường dẫn cũ *</label><input id="redOldPath" class="form-control" placeholder="/duong-dan-cu" required></div>
              <div class="form-group"><label class="form-label">Đường dẫn đích *</label><input id="redNewPath" class="form-control" placeholder="/gioi-thieu" required></div>
            </div>
            <button type="submit" class="btn btn-secondary btn-sm">Thêm Chuyển hướng</button>
          </form>
          <ul style="list-style:none;margin-top:10px;font-size:12.5px;">
            ${(d.cms?.redirects || []).map(r => `<li style="margin-bottom:4px;display:flex;gap:8px;align-items:center;flex-wrap:wrap;"><code>${esc(r.old_path)}</code> → <code>${esc(r.new_path)}</code> (${r.status_code}) <button type="button" class="btn btn-sm btn-danger btn-delete-redirect" data-old-path="${esc(r.old_path)}">Xóa</button></li>`).join("")}
          </ul>
        </div>
      </div>
      <table class="data-table">
        <thead><tr><th>Vị trí</th><th>Thứ tự</th><th>Nhãn VI / EN</th><th>Liên kết</th><th>Hiển thị / Thao tác</th></tr></thead>
        <tbody>
          ${menus.map(m => `
            <tr>
              <td><code>${esc(m.menu_location)}</code></td>
              <td>${Number(m.sort_order)}</td>
              <td><strong>${esc(m.label_vi)}</strong> / ${esc(m.label_en)}</td>
              <td><code>${esc(m.target_url)}</code></td>
              <td>
                <span class="status-pill ${Number(m.is_visible) ? "status-green" : "status-amber"}">${Number(m.is_visible) ? "Hiển thị" : "Ẩn"}</span>
                <button type="button" class="btn btn-sm btn-secondary btn-toggle-menu" data-menu-id="${esc(m.id)}" style="margin-left:6px;">Đổi ẩn/hiện</button>
              </td>
            </tr>
          `).join("")}
        </tbody>
      </table>
    `;


    document.getElementById("cmsSettingsForm")?.addEventListener("submit", async e => {
      e.preventDefault();
      try {
        await apiFetch("/api/cms/settings", {
          method: "POST",
          body: JSON.stringify({
            settings: {
              hero_title_vi: document.getElementById("setHeroTitleVi").value.trim(),
              hero_title_en: document.getElementById("setHeroTitleEn").value.trim(),
              hero_subtitle_vi: document.getElementById("setHeroSubVi").value.trim(),
              hero_subtitle_en: document.getElementById("setHeroSubEn").value.trim()
            }
          })
        });
        await loadInitialData();
        renderShell();
        showToast("Đã cập nhật cấu hình trang chủ vào D1!");
      } catch (err) {
        showToast(err.message, true);
      }
    });

    subVp.querySelectorAll('.btn-delete-redirect').forEach(btn => btn.addEventListener('click', async () => { const oldPath=btn.dataset.oldPath||''; if(!oldPath||!window.confirm(`Xóa chuyển hướng ${oldPath}?`))return; try { await apiFetch(`/api/cms/redirects/${encodeURIComponent(oldPath.replace(/^\//,''))}`,{method:'DELETE'}); await loadInitialData(); showToast('Đã xóa chuyển hướng.'); renderRoute(); } catch(err) { showToast(err.message,true); } }));

    document.getElementById("cmsRedirectForm")?.addEventListener("submit", async e => {
      e.preventDefault();
      try {
        await apiFetch("/api/cms/redirects", {
          method: "POST",
          body: JSON.stringify({
            old_path: document.getElementById("redOldPath").value.trim(),
            new_path: document.getElementById("redNewPath").value.trim(),
            status_code: 301
          })
        });
        await loadInitialData();
        showToast("Đã lưu chuyển hướng URL vào D1!");
        renderRoute();
      } catch (err) {
        showToast(err.message, true);
      }
    });

    subVp.querySelectorAll(".btn-toggle-menu").forEach(btn => {
      btn.addEventListener("click", async () => {
        const m = menus.find(x => String(x.id) === btn.getAttribute("data-menu-id"));
        if (!m) return;
        try {
          await apiFetch("/api/cms/menus", {
            method: "POST",
            body: JSON.stringify({ ...m, is_visible: !Number(m.is_visible) })
          });
          await loadInitialData();
          renderShell();
          showToast("Đã cập nhật trạng thái hiển thị mục menu!");
          renderRoute();
        } catch (err) {
          showToast(err.message, true);
        }
      });
    });

    const resetMenuForm = () => { document.getElementById('mId').value=''; document.getElementById('mLocation').value='main_header'; document.getElementById('mLabelVi').value=''; document.getElementById('mLabelEn').value=''; document.getElementById('mTargetUrl').value=''; document.getElementById('mSortOrder').value='1'; document.getElementById('mVisible').checked=true; document.getElementById('mNewTab').checked=false; document.getElementById('btnSaveMenu').textContent='Lưu Mục Điều hướng vào D1'; };
    document.getElementById('btnResetMenu')?.addEventListener('click', resetMenuForm);
    subVp.querySelectorAll('.btn-edit-menu').forEach(btn => btn.addEventListener('click', () => { const m=menus.find(x=>String(x.id)===btn.dataset.menuId); if(!m)return; document.getElementById('mId').value=m.id; document.getElementById('mLocation').value=m.menu_location; document.getElementById('mLabelVi').value=m.label_vi||''; document.getElementById('mLabelEn').value=m.label_en||''; document.getElementById('mTargetUrl').value=m.target_url||''; document.getElementById('mSortOrder').value=Number(m.sort_order||1); document.getElementById('mVisible').checked=Boolean(Number(m.is_visible)); document.getElementById('mNewTab').checked=Boolean(Number(m.open_in_new_tab)); document.getElementById('btnSaveMenu').textContent='Cập nhật mục menu'; document.getElementById('cmsMenuForm').scrollIntoView({behavior:'smooth',block:'start'}); }));
    subVp.querySelectorAll('.btn-delete-menu').forEach(btn => btn.addEventListener('click', async () => { const m=menus.find(x=>String(x.id)===btn.dataset.menuId); if(!m||!window.confirm(`Xóa mục menu “${m.label_vi}”?`))return; try { await apiFetch(`/api/cms/menus/${encodeURIComponent(m.id)}`,{method:'DELETE'}); await loadInitialData(); renderShell(); showToast('Đã xóa mục menu.'); renderRoute(); } catch(err) { showToast(err.message,true); } }));
    document.getElementById('cmsMenuForm')?.addEventListener('submit', async e => {
      e.preventDefault();
      try {
        await apiFetch('/api/cms/menus', {
          method: 'POST',
          body: JSON.stringify({
            id: document.getElementById('mId').value || undefined,
            menu_location: document.getElementById('mLocation').value,
            label_vi: document.getElementById('mLabelVi').value.trim(),
            label_en: document.getElementById('mLabelEn').value.trim(),
            target_url: document.getElementById('mTargetUrl').value.trim(),
            sort_order: Number(document.getElementById('mSortOrder').value || 1),
            is_visible: document.getElementById('mVisible').checked,
            open_in_new_tab: document.getElementById('mNewTab').checked
          })
        });
        await loadInitialData();
        renderShell();
        showToast('Đã lưu mục menu vào D1 và cập nhật giao diện!');
        renderRoute();
      } catch (err) {
        showToast(err.message, true);
      }
    });
    return;
  }

  if (tab === 'cms_media') {
    const mediaList = d.cms?.media || [];
    subVp.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;flex-wrap:wrap;gap:12px;">
        <div>
          <h2 style="color:var(--navy-900);">Thư viện Media Cloudflare R2 (Bucket: scrd-files)</h2>
          <p style="font-size:13px;color:var(--ink-700);">Tải tệp từ thiết bị, kiểm tra định dạng/magic bytes và phân quyền truy cập.</p>
        </div>
        <form id="mediaUploadForm" style="display:flex;gap:8px;align-items:center;">
          <select id="mediaScopeSelect" class="form-control" style="width:180px;">
            <option value="public">Công khai (public)</option>
            <option value="authenticated">Thành viên (authenticated)</option>
            <option value="research_team">Nhóm nghiên cứu</option>
            <option value="admin_only">Chỉ Quản trị viên</option>
          </select>
          <label class="btn btn-primary" style="cursor:pointer;">
            ⬆️ Chọn tệp tải lên R2
            <input type="file" id="inpCmsMediaFile" style="display:none;">
          </label>
        </form>
      </div>
      <table class="data-table">
        <thead><tr><th>Tên tệp</th><th>MIME & Kích thước</th><th>Phân quyền</th><th>Tải xuống / Xóa</th></tr></thead>
        <tbody>
          ${mediaList.map(mf => `
            <tr>
              <td><strong>${esc(mf.original_filename)}</strong><br><small><code>${esc(mf.r2_key)}</code></small></td>
              <td>${esc(mf.mime_type)} (${Math.round(Number(mf.size_bytes || 0) / 1024)} KB)</td>
              <td><span class="status-pill status-blue">${esc(mf.access_scope)}</span></td>
              <td style="display:flex;gap:6px;">
                <a class="btn btn-sm btn-secondary" href="/api/files/${encodeURIComponent(mf.id)}/download" target="_blank" rel="noopener">Tải xuống</a>
                <button type="button" class="btn btn-sm btn-danger btn-del-media" data-media-id="${esc(mf.id)}">Xóa</button>
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;

    document.getElementById('inpCmsMediaFile')?.addEventListener('change', async e => {
      const file = e.target.files?.[0];
      if (!file) return;
      const fd = new FormData();
      fd.set('file', file);
      fd.set('access_scope', document.getElementById('mediaScopeSelect').value);
      try {
        await apiFetch('/api/media/upload', { method: 'POST', body: fd });
        showToast('Tải tệp lên R2 và lưu metadata D1 thành công!');
        renderRoute();
      } catch (err) {
        showToast(err.message, true);
      }
    });

    subVp.querySelectorAll('.btn-del-media').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-media-id');
        if (!window.confirm('Xác nhận xóa tệp khỏi R2 và D1?')) return;
        try {
          await apiFetch(`/api/media/${encodeURIComponent(id)}`, { method: 'DELETE' });
          showToast('Đã xóa tệp khỏi R2 và D1.');
          renderRoute();
        } catch (err) {
          showToast(err.message, true);
        }
      });
    });
    return;
  }

  if (tab === 'requests') {
    const reqs = d.admin?.account_requests || [];
    subVp.innerHTML = `
      <h2 style="margin-bottom:14px;color:var(--navy-900);">Xét duyệt Hồ sơ Yêu cầu Cấp Tài khoản & Cấp Quyền Hệ thống</h2>
      <section id="requestDetailPanel" class="request-detail-panel card" hidden aria-live="polite"></section>
      ${reqs.length === 0 ? `<div class="empty-state"><p>Hiện chưa có hồ sơ yêu cầu cấp tài khoản nào.</p></div>` : `
        <table class="data-table">
          <thead>
            <tr><th>Mã & Ngày gửi</th><th>Ứng viên</th><th>Học tập / Định danh</th><th>Vai trò & Mục đích</th><th>Trạng thái & Thao tác Xét duyệt</th></tr>
          </thead>
          <tbody>
            ${reqs.map(r => `
              <tr>
                <td>
                  <strong><code>${esc(r.request_code)}</code></strong><br>
                  <small>${esc(r.submitted_at)}</small>
                </td>
                <td>
                  <strong>${esc(r.full_name)}</strong> (${esc(r.gender)})<br>
                  ${esc(r.email)} | ${esc(r.phone)}<br>
                  <small>Tuổi: ${Number(r.calculated_age)} ${Number(r.is_minor) ? `<span class="status-pill status-amber">Dưới 18t (GH: ${esc(r.guardian_full_name)})</span>` : ''}</small>
                </td>
                <td>
                  ${esc(r.education_level)} — ${esc(r.institution_name)}<br>
                  <small>${esc(r.id_document_type)}: <code>${esc(r.id_number_masked)}</code></small>
                </td>
                <td>
                  Đề xuất: <code>${esc(r.requested_role)}</code><br>
                  <small>${esc(r.registration_purpose)}</small>
                </td>
                <td>
                  <div style="margin-bottom:6px;"><span class="status-pill status-green">${esc(r.status)}</span></div>
                  <select class="form-control sel-req-status" data-req-id="${esc(r.id)}" style="margin-bottom:6px;font-size:12px;padding:5px;">
                    <option value="Đã tiếp nhận" ${r.status === 'Đã tiếp nhận' ? 'selected' : ''}>Đã tiếp nhận</option>
                    <option value="Đang xem xét" ${r.status === 'Đang xem xét' ? 'selected' : ''}>Đang xem xét</option>
                    <option value="Cần bổ sung thông tin" ${r.status === 'Cần bổ sung thông tin' ? 'selected' : ''}>Cần bổ sung thông tin</option>
                    <option value="Đã duyệt" ${r.status === 'Đã duyệt' ? 'selected' : ''}>Đã duyệt</option>
                    <option value="Từ chối" ${r.status === 'Từ chối' ? 'selected' : ''}>Từ chối</option>
                    <option value="Đã kích hoạt tài khoản" ${r.status === 'Đã kích hoạt tài khoản' ? 'selected' : ''}>Đã kích hoạt tài khoản</option>
                  </select>
                  <input class="form-control inp-req-note" data-req-id="${esc(r.id)}" placeholder="Ghi chú công khai..." value="${esc(r.review_notes_public || '')}" style="font-size:12px;padding:5px;margin-bottom:6px;">
                  <div class="request-review-actions">
                    <button type="button" class="btn btn-sm btn-secondary btn-view-request" data-req-id="${esc(r.id)}">Xem hồ sơ, ảnh chân dung & chữ ký</button>
                    <button type="button" class="btn btn-sm btn-primary btn-save-review" data-req-id="${esc(r.id)}">Lưu xét duyệt</button>
                  </div>
                </td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `}
    `;

    subVp.querySelectorAll('.btn-view-request').forEach(btn => {
      btn.addEventListener('click', async () => {
        const reqId = btn.getAttribute('data-req-id');
        const panel = document.getElementById('requestDetailPanel');
        if (!panel) return;
        panel.hidden = false;
        panel.innerHTML = '<div class="chat-loading"><span class="page-state-spinner"></span><p>Đang tải hồ sơ riêng tư theo quyền xét duyệt…</p></div>';
        try {
          const detail = await apiFetch(`/api/admin/account-requests/${encodeURIComponent(reqId)}`);
          let portraitSrc = '';
          if (detail.portrait_media_id) {
            const headers = new Headers({ Authorization: `Bearer ${AppState.token}` });
            if (AppState.csrfToken) headers.set('X-CSRF-Token', AppState.csrfToken);
            const imageResponse = await fetch(`/api/media/${encodeURIComponent(detail.portrait_media_id)}`, { headers, cache: 'no-store' });
            if (imageResponse.ok) portraitSrc = URL.createObjectURL(await imageResponse.blob());
          }
          panel.innerHTML = `
            <div class="request-detail-heading"><div><span class="eyebrow">HỒ SƠ RIÊNG TƯ · CHỈ DÀNH CHO NGƯỜI CÓ QUYỀN</span><h3>${esc(detail.full_name)} — ${esc(detail.request_code)}</h3><p>${esc(detail.status)}</p></div><button type="button" class="btn btn-sm btn-secondary" id="btnCloseRequestDetail">Đóng chi tiết</button></div>
            <div class="request-detail-grid">
              <section><h4>Thông tin cá nhân</h4><dl><dt>Email</dt><dd>${esc(detail.email)}</dd><dt>Điện thoại</dt><dd>${esc(detail.phone)}</dd><dt>Ngày sinh</dt><dd>${esc(detail.date_of_birth)}</dd><dt>Giới tính</dt><dd>${esc(detail.gender)}</dd><dt>Nhóm ứng viên</dt><dd>${esc(detail.applicant_group)}</dd><dt>Học tập / Công tác</dt><dd>${esc([detail.education_level,detail.institution_name,detail.major_or_field,detail.current_occupation,detail.work_unit].filter(Boolean).join(' · '))}</dd></dl></section>
              <section><h4>Thông tin định danh</h4><dl><dt>Loại giấy tờ</dt><dd>${esc(detail.id_document_type)}</dd><dt>Số giấy tờ (đã che)</dt><dd>${esc(detail.id_number_masked)}</dd><dt>Ngày cấp</dt><dd>${esc(detail.id_issued_date)}</dd><dt>Nơi cấp</dt><dd>${esc(detail.id_issued_place)}</dd><dt>Hạn sử dụng</dt><dd>${esc(detail.id_expiry_date || 'Không cung cấp')}</dd><dt>Mục đích đăng ký</dt><dd>${esc(detail.registration_purpose)}</dd><dt>Lĩnh vực quan tâm</dt><dd>${esc(detail.research_or_project_interest)}</dd></dl></section>
              <section><h4>Ảnh chân dung cá nhân</h4>${portraitSrc ? `<a href="${portraitSrc}" target="_blank" rel="noopener noreferrer"><img class="request-portrait-preview" src="${portraitSrc}" alt="Ảnh chân dung ứng viên"></a>` : '<p class="text-muted">Không tải được ảnh hoặc ảnh chưa có.</p>'}</section>
              <section><h4>Chữ ký xác nhận</h4>${detail.signature_data ? `<img class="request-signature-preview" src="${esc(detail.signature_data)}" alt="Chữ ký xác nhận của người đăng ký">` : '<p class="text-muted">Hồ sơ chưa có chữ ký.</p>'}<p class="text-muted">Đã xác nhận tính chính xác: ${detail.data_accuracy_confirmed ? 'Có' : 'Không'} · Điều khoản: ${detail.terms_accepted ? 'Đã xác nhận' : 'Chưa xác nhận'} · Thông báo dữ liệu: ${detail.privacy_policy_accepted ? 'Đã xác nhận' : 'Chưa xác nhận'}</p></section>
            </div>`;
          document.getElementById('btnCloseRequestDetail')?.addEventListener('click', () => { panel.hidden = true; panel.innerHTML = ''; });
        } catch (err) {
          panel.innerHTML = `<div class="alert-box alert-error">${esc(err.message)}</div><button type="button" class="btn btn-sm btn-secondary" id="btnCloseRequestDetail">Đóng</button>`;
          document.getElementById('btnCloseRequestDetail')?.addEventListener('click', () => { panel.hidden = true; panel.innerHTML = ''; });
        }
      });
    });

    subVp.querySelectorAll('.btn-save-review').forEach(btn => {
      btn.addEventListener('click', async () => {
        const reqId = btn.getAttribute('data-req-id');
        const sel = subVp.querySelector(`.sel-req-status[data-req-id="${CSS.escape(reqId)}"]`);
        const noteInp = subVp.querySelector(`.inp-req-note[data-req-id="${CSS.escape(reqId)}"]`);
        try {
          await apiFetch('/api/admin/account-requests/review', {
            method: 'POST',
            body: JSON.stringify({
              request_id: reqId,
              new_status: sel.value,
              review_notes_public: noteInp.value.trim()
            })
          });
          showToast('Đã lưu kết quả xét duyệt vào D1!');
          renderRoute();
        } catch (err) {
          showToast(err.message, true);
        }
      });
    });
    return;
  }

  if (tab === 'research_projects') {
    const canManage = ['super_admin', 'research_lead', 'project_manager', 'project_lead', 'cms_editor'].includes(u.role);
    subVp.innerHTML = `
      <h2 style="margin-bottom:14px;color:var(--navy-900);">Quản lý Nghiên cứu, Dự án Cộng đồng & Nhiệm vụ Tiến độ Thực</h2>
      ${canManage ? `
        <div class="grid-2" style="margin-bottom:20px;">
          <div class="card">
            <h3>+ Tạo Đề tài Nghiên cứu / Dự án Mới</h3>
            <form id="newProgramForm" style="margin-top:10px;">
              <div class="form-group">
                <label class="form-label">Phân loại</label>
                <select id="progType" class="form-control">
                  <option value="research">Đề tài Nghiên cứu Khoa học</option>
                  <option value="project">Dự án Phát triển Cộng đồng</option>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Mã số (Code) *</label><input id="progCode" class="form-control" placeholder="RES-2026-01" required></div>
              <div class="form-group"><label class="form-label">Tên chương trình (VI) *</label><input id="progTitle" class="form-control" required></div>
              <div class="form-group"><label class="form-label">Tóm tắt / Mục tiêu *</label><textarea id="progSummary" class="form-control" rows="2" required></textarea></div>
              <button type="submit" class="btn btn-primary btn-sm">Lưu vào D1</button>
            </form>
          </div>
          <div class="card">
            <h3>+ Thêm / Cập nhật Nhiệm vụ (Tự động tính % Tiến độ)</h3>
            <form id="newTaskForm" style="margin-top:10px;">
              <div class="grid-2">
                <div class="form-group">
                  <label class="form-label">Loại chương trình</label>
                  <select id="tkParentType" class="form-control">
                    <option value="research">Nghiên cứu (research)</option>
                    <option value="project">Dự án (project)</option>
                  </select>
                </div>
                <div class="form-group"><label class="form-label">Mã Đề tài/Dự án *</label><input id="tkParentId" class="form-control" placeholder="RES-2026-01" required></div>
              </div>
              <div class="form-group"><label class="form-label">Tên nhiệm vụ *</label><input id="tkTitle" class="form-control" required></div>
              <div class="grid-2">
                <div class="form-group"><label class="form-label">Trọng số</label><input id="tkWeight" type="number" class="form-control" value="50"></div>
                <div class="form-group">
                  <label class="form-label">Trạng thái</label>
                  <select id="tkStatus" class="form-control">
                    <option value="todo">Chưa bắt đầu (0%)</option>
                    <option value="in_progress">Đang thực hiện (50%)</option>
                    <option value="completed">Đã hoàn thành (100%)</option>
                  </select>
                </div>
              </div>
              <button type="submit" class="btn btn-emerald btn-sm">Lưu Nhiệm vụ & Tính Tiến độ</button>
            </form>
          </div>
        </div>
      ` : ''}
      <table class="data-table">
        <thead><tr><th>Loại & Mã</th><th>Nhiệm vụ</th><th>Trọng số</th><th>Trạng thái</th></tr></thead>
        <tbody>
          ${(d.tasks || []).map(tk => `
            <tr>
              <td><code>${esc(tk.parent_type)}:${esc(tk.parent_id)}</code></td>
              <td><strong>${esc(tk.title)}</strong></td>
              <td>${Number(tk.weight)}</td>
              <td><span class="status-pill status-blue">${esc(tk.status)}</span></td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;

    document.getElementById('newProgramForm')?.addEventListener('submit', async e => {
      e.preventDefault();
      const type = document.getElementById('progType').value;
      const code = document.getElementById('progCode').value.trim();
      const title = document.getElementById('progTitle').value.trim();
      const summary = document.getElementById('progSummary').value.trim();
      try {
        await apiFetch(type === 'research' ? '/api/research' : '/api/projects', {
          method: 'POST',
          body: JSON.stringify({
            id: code,
            code,
            slug: code.toLowerCase(),
            title_vi: title,
            summary_vi: summary,
            objective_vi: summary,
            is_public: true
          })
        });
        await loadInitialData();
        showToast('Đã lưu chương trình vào D1!');
        renderRoute();
      } catch (err) {
        showToast(err.message, true);
      }
    });

    document.getElementById('newTaskForm')?.addEventListener('submit', async e => {
      e.preventDefault();
      try {
        const res = await apiFetch('/api/tasks', {
          method: 'POST',
          body: JSON.stringify({
            parent_type: document.getElementById('tkParentType').value,
            parent_id: document.getElementById('tkParentId').value.trim(),
            title: document.getElementById('tkTitle').value.trim(),
            weight: Number(document.getElementById('tkWeight').value || 1),
            status: document.getElementById('tkStatus').value
          })
        });
        await loadInitialData();
        showToast(`Đã lưu nhiệm vụ! Tiến độ chương trình hiện tại: ${res.parent_progress_percent}%`);
        renderRoute();
      } catch (err) {
        showToast(err.message, true);
      }
    });
    return;
  }

  if (tab === 'exams') {
    const myAttempts = d.my_exam_attempts || [];
    subVp.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;">
        <h2 style="color:var(--navy-900);">Lịch sử Dự thi & Kết quả Khảo thí của Tôi</h2>
        <a class="btn btn-primary btn-sm" href="/khao-thi-danh-gia" data-nav="/khao-thi-danh-gia">Mở Danh sách Kỳ thi →</a>
      </div>
      ${myAttempts.length === 0 ? `<div class="empty-state"><p>Bạn chưa có lượt dự thi nào được ghi nhận.</p></div>` : `
        <table class="data-table">
          <thead><tr><th>Kỳ thi</th><th>Mã phiên</th><th>Trạng thái</th><th>Điểm số</th><th>Mã biên nhận</th></tr></thead>
          <tbody>
            ${myAttempts.map(a => `
              <tr>
                <td><strong>${esc(a.exam_title)}</strong> (<code>${esc(a.exam_code || '')}</code>)</td>
                <td><code>${esc(a.id)}</code></td>
                <td><span class="status-pill status-green">${esc(a.status)}</span></td>
                <td>${a.score !== null && a.score !== undefined ? `<strong>${esc(a.score)} / ${esc(a.max_score)}</strong>` : 'Ẩn theo quy chế / Chờ chấm'}</td>
                <td><code>${esc(a.receipt_code || '—')}</code></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `}
    `;
    return;
  }

  if (tab === 'chat') {
    const rooms = AppState.chatRooms;
    const activeRoomId = AppState.activeChatRoomId;
    const selectedRoom = rooms.find(r => r.id === activeRoomId) || null;
    subVp.innerHTML = `
      <section class="chat-admin-module">
        <div class="chat-module-heading">
          <div>
            <span class="eyebrow">GIAO TIẾP NỘI BỘ</span>
            <h2>Chat riêng 1–1 và nhóm bảo mật</h2>
            <p>Chỉ thành viên được cấp quyền mới xem được lịch sử tin nhắn và tệp của hội thoại.</p>
          </div>
          <div class="chat-security-note"><span aria-hidden="true">🔒</span><span>Quyền thành viên được kiểm tra tại backend</span></div>
        </div>
        <div class="chat-contact-search card">
          <label class="form-label" for="chatContactQuery">Tìm người dùng để bắt đầu trò chuyện hoặc thêm vào nhóm</label>
          <div class="chat-search-row">
            <input id="chatContactQuery" class="form-control" minlength="2" placeholder="Nhập tên, mã thành viên hoặc email (tối thiểu 2 ký tự)" autocomplete="off">
            <button type="button" class="btn btn-primary" id="btnFindChatContacts">Tìm người dùng</button>
          </div>
          <div id="chatContactsResults" class="chat-contacts-results" aria-live="polite">
            <p class="chat-helper">Kết quả tìm kiếm chỉ hiển thị tên, mã thành viên và vai trò cơ bản; không hiển thị số điện thoại hay thông tin riêng tư.</p>
          </div>
          <div class="chat-create-group-row">
            <div class="form-group">
              <label class="form-label" for="chatGroupName">Tên nhóm chat mới</label>
              <input id="chatGroupName" class="form-control" maxlength="160" placeholder="Ví dụ: Nhóm Nghiên cứu / Dự án cộng đồng">
            </div>
            <button type="button" class="btn btn-secondary" id="btnCreateChatGroup">Tạo nhóm với thành viên đã chọn</button>
          </div>
        </div>
        <div class="chat-workspace-grid">
          <section class="card chat-room-list-panel">
            <div class="chat-panel-heading"><h3>Cuộc trò chuyện của bạn</h3><span class="chat-count">${rooms.length}</span></div>
            ${rooms.length === 0 ? `<div class="chat-empty"><span aria-hidden="true">💬</span><strong>Chưa có cuộc trò chuyện</strong><p>Tìm người dùng để bắt đầu chat 1–1 hoặc tạo nhóm với thành viên đã chọn.</p></div>` : `
              <div class="chat-room-list">
                ${rooms.map(r => `
                  <button type="button" class="chat-room-item ${r.id === activeRoomId ? 'active' : ''}" data-room-id="${esc(r.id)}">
                    <span class="chat-room-avatar" aria-hidden="true">${r.room_type === 'direct' ? '1:1' : '👥'}</span>
                    <span class="chat-room-summary"><strong>${esc(r.name || (r.room_type === 'direct' ? 'Trò chuyện riêng' : 'Nhóm chat'))}</strong><small>${r.room_type === 'direct' ? 'Trò chuyện riêng 1–1' : `Nhóm · ${Number(r.member_count || 1)} thành viên`} · ${Number(r.message_count || 0)} tin nhắn</small></span>
                    <span class="chat-room-arrow" aria-hidden="true">›</span>
                  </button>
                `).join('')}
              </div>
            `}
          </section>
          <section class="card chat-conversation-panel" id="chatRoomMessagesPanel">
            <div class="chat-empty chat-empty-large"><span aria-hidden="true">✉️</span><strong>Chọn một cuộc trò chuyện</strong><p>Tin nhắn sẽ hiển thị tại đây sau khi xác minh quyền thành viên.</p></div>
          </section>
        </div>
      </section>
    `;

    const getSelectedMembers = () => [...subVp.querySelectorAll('.chat-group-member-select:checked')].map(el => el.value);
    const renderContactResults = contacts => {
      const target = document.getElementById('chatContactsResults');
      if (!target) return;
      if (!contacts.length) {
        target.innerHTML = '<p class="chat-helper">Không tìm thấy tài khoản đang hoạt động phù hợp. Thử tên hoặc mã thành viên khác.</p>';
        return;
      }
      target.innerHTML = `
        <div class="chat-result-heading"><strong>Chọn người trò chuyện</strong><span>Chọn Chat 1–1 hoặc đánh dấu thành viên để tạo nhóm</span></div>
        <div class="chat-contact-list">${contacts.map(c => `
          <div class="chat-contact-row">
            <span class="chat-contact-avatar" aria-hidden="true">${esc(String(c.full_name || '?').trim().slice(0,1).toUpperCase())}</span>
            <div class="chat-contact-copy"><strong>${esc(c.full_name)}</strong><small>${esc(c.sfn_id || 'Thành viên')} · ${esc(c.role || 'member')}${c.department ? ` · ${esc(c.department)}` : ''}</small></div>
            <label class="chat-select-for-group"><input class="chat-group-member-select" type="checkbox" value="${esc(c.id)}"> <span>Chọn nhóm</span></label>
            <button type="button" class="btn btn-sm btn-primary" data-start-direct="${esc(c.id)}">Chat 1–1</button>
          </div>
        `).join('')}</div>
      `;
    };
    const loadRooms = async () => {
      const res = await apiFetch('/api/chat/rooms');
      AppState.chatRooms = res.rooms || [];
      renderRoute();
    };
    const openRoom = async roomId => {
      AppState.activeChatRoomId = roomId;
      const panel = document.getElementById('chatRoomMessagesPanel');
      if (!panel) return;
      panel.innerHTML = '<div class="chat-loading"><span class="page-state-spinner"></span><p>Đang tải hội thoại và kiểm tra thành viên...</p></div>';
      try {
        const room = AppState.chatRooms.find(r => r.id === roomId);
        const [messageRes, memberRes] = await Promise.all([
          apiFetch(`/api/chat/rooms/${encodeURIComponent(roomId)}/messages`),
          room?.room_type === 'group' ? apiFetch(`/api/chat/rooms/${encodeURIComponent(roomId)}/members`) : Promise.resolve({ members: [] })
        ]);
        AppState.activeChatMessages = messageRes.messages || [];
        const members = memberRes.members || [];
        panel.innerHTML = `
          <header class="chat-conversation-header">
            <div><span class="eyebrow">${room?.room_type === 'direct' ? 'TRÒ CHUYỆN RIÊNG' : 'NHÓM BẢO MẬT'}</span><h3>${esc(room?.name || 'Hội thoại')}</h3><p>${room?.room_type === 'direct' ? 'Cuộc trò chuyện riêng 1–1' : `${members.length} thành viên trong nhóm`}</p></div>
            <button type="button" class="btn btn-sm btn-secondary" id="btnRefreshChat">Làm mới</button>
          </header>
          ${room?.room_type === 'group' ? `<div class="chat-members-panel"><div class="chat-panel-heading"><strong>Thành viên nhóm</strong><span>${members.length}</span></div><div class="chat-member-chips">${members.map(m => `<span class="chat-member-chip">${esc(m.full_name)} <small>${esc(m.role)}</small>${m.role !== 'owner' && AppState.currentUser?.id === room.created_by ? `<button type="button" aria-label="Xóa ${esc(m.full_name)} khỏi nhóm" data-remove-chat-member="${esc(m.user_id)}">×</button>` : ''}</span>`).join('')}</div><p class="chat-helper">Để thêm thành viên, tìm tài khoản ở phía trên, đánh dấu “Chọn nhóm”, rồi bấm “Thêm người đã chọn vào nhóm” bên dưới.</p><button type="button" class="btn btn-sm btn-secondary" id="btnAddMembersToRoom">Thêm người đã chọn vào nhóm</button></div>` : ''}
          <div class="chat-message-list" id="chatMessageList">
            ${AppState.activeChatMessages.length ? AppState.activeChatMessages.map(m => `<article class="chat-message"><div class="chat-message-meta"><strong>${esc(m.sender_name)}</strong><time>${esc(m.created_at || '')}</time></div><p>${esc(m.message_text)}</p></article>`).join('') : '<div class="chat-empty"><strong>Chưa có tin nhắn</strong><p>Gửi tin nhắn đầu tiên trong cuộc trò chuyện này.</p></div>'}
          </div>
          <form id="sendChatMsgForm" class="chat-compose-form">
            <label class="sr-only" for="inpChatMsg">Nội dung tin nhắn</label>
            <textarea id="inpChatMsg" class="form-control" rows="2" maxlength="5000" placeholder="Nhập tin nhắn…" required></textarea>
            <button type="submit" class="btn btn-primary">Gửi tin nhắn</button>
          </form>
          <p class="chat-helper">Không gửi mật khẩu, token xác thực hoặc tài liệu nhạy cảm vào hội thoại không phù hợp.</p>
        `;
        document.getElementById('btnRefreshChat')?.addEventListener('click', () => openRoom(roomId));
        document.getElementById('sendChatMsgForm')?.addEventListener('submit', async ev => {
          ev.preventDefault();
          const input = document.getElementById('inpChatMsg');
          const submit = ev.currentTarget.querySelector('button[type="submit"]');
          const message_text = input?.value?.trim();
          if (!message_text) return;
          submit.disabled = true;
          try {
            await apiFetch(`/api/chat/rooms/${encodeURIComponent(roomId)}/messages`, { method: 'POST', body: JSON.stringify({ message_text }) });
            await openRoom(roomId);
          } catch (err) {
            showToast(err.message, true);
            submit.disabled = false;
          }
        });
        document.getElementById('btnAddMembersToRoom')?.addEventListener('click', async () => {
          const ids = getSelectedMembers();
          if (!ids.length) return showToast('Hãy tìm và chọn ít nhất một thành viên trước.', true);
          try {
            for (const user_id of ids) await apiFetch(`/api/chat/rooms/${encodeURIComponent(roomId)}/members`, { method: 'POST', body: JSON.stringify({ user_id }) });
            showToast('Đã cập nhật thành viên nhóm.');
            await openRoom(roomId);
            await loadRooms();
          } catch (err) { showToast(err.message, true); }
        });
        panel.querySelectorAll('[data-remove-chat-member]').forEach(btn => btn.addEventListener('click', async () => {
          const userId = btn.getAttribute('data-remove-chat-member');
          if (!window.confirm('Xóa thành viên này khỏi nhóm?')) return;
          try {
            await apiFetch(`/api/chat/rooms/${encodeURIComponent(roomId)}/members/${encodeURIComponent(userId)}`, { method: 'DELETE' });
            await openRoom(roomId); await loadRooms();
          } catch (err) { showToast(err.message, true); }
        }));
        const messageList = document.getElementById('chatMessageList');
        if (messageList) messageList.scrollTop = messageList.scrollHeight;
      } catch (err) {
        panel.innerHTML = `<div class="alert-box alert-error">${esc(err.message)}</div>`;
      }
    };

    document.getElementById('btnFindChatContacts')?.addEventListener('click', async () => {
      const q = document.getElementById('chatContactQuery')?.value?.trim() || '';
      if (q.length < 2) return showToast('Nhập tối thiểu 2 ký tự để tìm người dùng.', true);
      const target = document.getElementById('chatContactsResults');
      target.innerHTML = '<p class="chat-helper">Đang tìm tài khoản…</p>';
      try {
        const res = await apiFetch(`/api/chat/contacts?q=${encodeURIComponent(q)}`);
        renderContactResults(res.contacts || []);
      } catch (err) { target.innerHTML = `<div class="alert-box alert-error">${esc(err.message)}</div>`; }
    });
    document.getElementById('chatContactQuery')?.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); document.getElementById('btnFindChatContacts')?.click(); } });
    subVp.querySelectorAll('[data-start-direct]').forEach(btn => btn.addEventListener('click', async () => {
      btn.disabled = true;
      try {
        const result = await apiFetch('/api/chat/rooms', { method: 'POST', body: JSON.stringify({ room_type: 'direct', target_user_id: btn.getAttribute('data-start-direct') }) });
        const rooms = await apiFetch('/api/chat/rooms'); AppState.chatRooms = rooms.rooms || []; AppState.activeChatRoomId = result.id; renderRoute();
      } catch (err) { showToast(err.message, true); btn.disabled = false; }
    }));
    document.getElementById('btnCreateChatGroup')?.addEventListener('click', async () => {
      const name = document.getElementById('chatGroupName')?.value?.trim() || '';
      const member_user_ids = getSelectedMembers();
      if (name.length < 2) return showToast('Tên nhóm cần ít nhất 2 ký tự.', true);
      if (!member_user_ids.length) return showToast('Tìm và chọn ít nhất một thành viên cho nhóm.', true);
      const btn = document.getElementById('btnCreateChatGroup'); btn.disabled = true;
      try {
        const result = await apiFetch('/api/chat/rooms', { method: 'POST', body: JSON.stringify({ room_type: 'group', name, member_user_ids }) });
        const rooms = await apiFetch('/api/chat/rooms'); AppState.chatRooms = rooms.rooms || []; AppState.activeChatRoomId = result.id; showToast('Đã tạo nhóm chat bảo mật.'); renderRoute();
      } catch (err) { showToast(err.message, true); btn.disabled = false; }
    });
    subVp.querySelectorAll('.chat-room-item').forEach(btn => btn.addEventListener('click', () => openRoom(btn.getAttribute('data-room-id'))));
    if (activeRoomId) openRoom(activeRoomId);
  }
}

// ============================================================================
// GLOBAL EVENT LISTENERS & BOOTSTRAP
// ============================================================================
function initApp() {
  document.addEventListener('click', e => {
    const mobileToggle = e.target.closest('#mobileNavToggle');
    if (mobileToggle) {
      const nav = document.getElementById('publicMainNav');
      const isOpen = nav?.classList.toggle('is-open') || false;
      mobileToggle.setAttribute('aria-expanded', String(isOpen));
      mobileToggle.setAttribute('aria-label', isOpen
        ? (AppState.lang === 'vi' ? 'Đóng menu điều hướng' : 'Close navigation menu')
        : (AppState.lang === 'vi' ? 'Mở menu điều hướng' : 'Open navigation menu'));
      const icon = mobileToggle.querySelector('.mobile-nav-toggle-icon');
      if (icon) icon.textContent = isOpen ? '✕' : '☰';
      return;
    }

    const navLink = e.target.closest('[data-nav]');
    if (navLink && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
      e.preventDefault();
      const target = navLink.getAttribute('data-nav');
      if (target) navigateTo(target);
    }
    const langBtn = e.target.closest('[data-lang]');
    if (langBtn) {
      setLanguage(langBtn.getAttribute('data-lang'));
    }
  });

  document.getElementById('closeDetailModalBtn')?.addEventListener('click', () => {
    document.getElementById('detailModal')?.classList.remove('open');
  });

  window.addEventListener('popstate', () => {
    closeMobileNavigation();
    AppState.currentPath = window.location.pathname;
    AppState.currentQuery = new URLSearchParams(window.location.search);
    renderShell();
    renderRoute();
  });

  loadInitialData().then(() => {
    renderShell();
    renderRoute();
  });
}

if (typeof window !== 'undefined' && typeof document !== 'undefined') {
  window.addEventListener('DOMContentLoaded', initApp);
}
