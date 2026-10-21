-- ============================================================================
-- TRUNG TÂM NGHIÊN CỨU VÀ PHÁT TRIỂN CỘNG ĐỒNG SKY FIRST
-- SKY FIRST CENTER FOR RESEARCH AND DEVELOPMENT
-- Domain: https://scrd.skyfirst.io.vn
-- Cloudflare D1 Database ID: 6006fe24-6278-4989-8d94-fd4734d71679 (Binding: DB)
-- Cloudflare R2 Bucket Name: scrd-files (Binding: FILES)
-- Migration Version: 0001_initial_non_destructive_schema.sql
-- ============================================================================

PRAGMA foreign_keys = ON;

-- 1. SYSTEM BOOTSTRAP & CONFIGURATION TABLE
CREATE TABLE IF NOT EXISTS system_config (
    config_key TEXT PRIMARY KEY,
    config_value TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_by INTEGER
);

-- Bootstrap state tracking (Ensures one-time atomic admin initialization)
CREATE TABLE IF NOT EXISTS bootstrap_state (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    is_bootstrapped INTEGER NOT NULL DEFAULT 0 CHECK (is_bootstrapped IN (0, 1)),
    bootstrapped_at TEXT,
    bootstrapped_admin_id INTEGER,
    bootstrap_ip TEXT,
    integrity_hash TEXT
);

INSERT OR IGNORE INTO bootstrap_state (id, is_bootstrapped) VALUES (1, 0);

-- 2. USERS & RBAC (ROLE-BASED ACCESS CONTROL)
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    password_salt TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('super_admin', 'cms_editor', 'research_lead', 'project_manager', 'examiner', 'member', 'reviewer')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('pending', 'active', 'suspended', 'locked')),
    avatar_r2_key TEXT,
    avatar_url TEXT,
    phone TEXT,
    gender TEXT,
    date_of_birth TEXT,
    organization TEXT,
    department TEXT,
    academic_title TEXT,
    bio_vi TEXT,
    bio_en TEXT,
    is_minor INTEGER NOT NULL DEFAULT 0 CHECK (is_minor IN (0, 1)),
    guardian_name TEXT,
    guardian_phone TEXT,
    guardian_email TEXT,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TEXT,
    last_login_at TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role_status ON users(role, status);

-- 3. SESSIONS & AUTH TOKENS
CREATE TABLE IF NOT EXISTS user_sessions (
    session_id TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    csrf_token TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    expires_at TEXT NOT NULL,
    revoked INTEGER NOT NULL DEFAULT 0 CHECK (revoked IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash ON user_sessions(token_hash);

-- 4. ACCOUNT REGISTRATION REQUESTS (5-STEP WORKFLOW & SCRD-SFN-XXXXXXXXXX CODE)
CREATE TABLE IF NOT EXISTS account_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_code TEXT NOT NULL UNIQUE CHECK (request_code GLOB 'SCRD-SFN-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
    -- Step 1: Personal Info
    full_name TEXT NOT NULL,
    email TEXT NOT NULL COLLATE NOCASE,
    phone TEXT NOT NULL,
    gender TEXT NOT NULL,
    date_of_birth TEXT NOT NULL,
    is_minor INTEGER NOT NULL DEFAULT 0 CHECK (is_minor IN (0, 1)),
    guardian_full_name TEXT,
    guardian_relationship TEXT,
    guardian_phone TEXT,
    guardian_email TEXT,
    guardian_consent INTEGER NOT NULL DEFAULT 0 CHECK (guardian_consent IN (0, 1)),
    personal_photo_r2_key TEXT,
    -- Step 2: Education & Work
    education_level TEXT NOT NULL,
    institution_name TEXT NOT NULL,
    major_or_field TEXT NOT NULL,
    current_occupation TEXT NOT NULL,
    work_unit TEXT,
    -- Step 3: Identity Info (Protected at Backend/D1 - NEVER sent in confirmation email)
    id_document_type TEXT NOT NULL CHECK (id_document_type IN ('CCCD', 'Passport', 'StudentCard', 'BirthCertificate')),
    id_number_encrypted TEXT NOT NULL,
    id_number_masked TEXT NOT NULL,
    id_issued_date TEXT NOT NULL,
    id_issued_place TEXT NOT NULL,
    id_front_r2_key TEXT,
    id_back_r2_key TEXT,
    -- Step 4: Purpose-Specific Supplemental Info
    requested_role TEXT NOT NULL DEFAULT 'member' CHECK (requested_role IN ('member', 'research_lead', 'project_manager', 'examiner')),
    registration_purpose TEXT NOT NULL,
    research_or_project_interest TEXT NOT NULL,
    experience_summary TEXT,
    supporting_doc_r2_key TEXT,
    -- Step 5: Consent & Review Status
    privacy_policy_accepted INTEGER NOT NULL CHECK (privacy_policy_accepted = 1),
    terms_accepted INTEGER NOT NULL CHECK (terms_accepted = 1),
    data_accuracy_confirmed INTEGER NOT NULL CHECK (data_accuracy_confirmed = 1),
    status TEXT NOT NULL DEFAULT 'Đã tiếp nhận' CHECK (status IN (
        'Đã tiếp nhận',
        'Đang xem xét',
        'Cần bổ sung thông tin',
        'Đã duyệt',
        'Từ chối',
        'Đã kích hoạt tài khoản'
    )),
    reviewer_id INTEGER,
    review_notes_public TEXT,
    review_notes_internal TEXT,
    supplement_request_message TEXT,
    approved_user_id INTEGER,
    submitted_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (approved_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_account_requests_code_email ON account_requests(request_code, email);
CREATE INDEX IF NOT EXISTS idx_account_requests_status ON account_requests(status);

-- 5. WORDPRESS-STYLE CMS: PAGES
CREATE TABLE IF NOT EXISTS cms_pages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT NOT NULL UNIQUE,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    summary_vi TEXT,
    summary_en TEXT,
    content_vi TEXT NOT NULL,
    content_en TEXT NOT NULL,
    page_group TEXT NOT NULL DEFAULT 'about' CHECK (page_group IN ('home', 'about', 'policy', 'support', 'cooperation', 'general')),
    featured_media_id INTEGER,
    seo_title_vi TEXT,
    seo_title_en TEXT,
    seo_description_vi TEXT,
    seo_description_en TEXT,
    status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'unpublished', 'archived')),
    version INTEGER NOT NULL DEFAULT 1,
    author_id INTEGER,
    published_at TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_cms_pages_slug ON cms_pages(slug);
CREATE INDEX IF NOT EXISTS idx_cms_pages_status ON cms_pages(status);

-- Page Revision History
CREATE TABLE IF NOT EXISTS cms_page_revisions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    page_id INTEGER NOT NULL,
    version INTEGER NOT NULL,
    title_vi TEXT NOT NULL,
    content_vi TEXT NOT NULL,
    edited_by INTEGER,
    edited_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (page_id) REFERENCES cms_pages(id) ON DELETE CASCADE
);

-- 6. WORDPRESS-STYLE CMS: POSTS (INCLUDING FULL EDITABILITY FOR AI-GENERATED POSTS)
CREATE TABLE IF NOT EXISTS cms_posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT NOT NULL UNIQUE,
    custom_path TEXT,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    excerpt_vi TEXT NOT NULL,
    excerpt_en TEXT NOT NULL,
    content_vi TEXT NOT NULL,
    content_en TEXT NOT NULL,
    category TEXT NOT NULL,
    tags_json TEXT NOT NULL DEFAULT '[]',
    featured_image_url TEXT,
    featured_media_id INTEGER,
    display_author TEXT NOT NULL,
    author_id INTEGER,
    is_ai_generated INTEGER NOT NULL DEFAULT 0 CHECK (is_ai_generated IN (0, 1)),
    is_locked INTEGER NOT NULL DEFAULT 0 CHECK (is_locked = 0), -- Hard constraint: Never lock AI-generated posts
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'pending_review', 'published', 'unpublished')),
    seo_title TEXT,
    seo_description TEXT,
    published_at TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_cms_posts_slug ON cms_posts(slug);
CREATE INDEX IF NOT EXISTS idx_cms_posts_status_cat ON cms_posts(status, category);

-- 7. CMS MENUS, FOOTER COLUMNS, LINKS & URL REDIRECTS
CREATE TABLE IF NOT EXISTS cms_menus (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    menu_location TEXT NOT NULL CHECK (menu_location IN ('main_header', 'utility_header', 'footer_col_2', 'footer_col_3', 'footer_col_4', 'footer_bottom')),
    parent_id INTEGER,
    label_vi TEXT NOT NULL,
    label_en TEXT NOT NULL,
    target_url TEXT NOT NULL,
    link_type TEXT NOT NULL DEFAULT 'internal' CHECK (link_type IN ('internal', 'external', 'cta', 'section')),
    sort_order INTEGER NOT NULL DEFAULT 1,
    is_visible INTEGER NOT NULL DEFAULT 1 CHECK (is_visible IN (0, 1)),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (parent_id) REFERENCES cms_menus(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_cms_menus_location_order ON cms_menus(menu_location, sort_order);

CREATE TABLE IF NOT EXISTS cms_redirects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    old_path TEXT NOT NULL UNIQUE,
    new_path TEXT NOT NULL,
    status_code INTEGER NOT NULL DEFAULT 301 CHECK (status_code IN (301, 302)),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- 8. CLOUDFLARE R2 MEDIA & FILE METADATA IN D1
CREATE TABLE IF NOT EXISTS r2_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    r2_key TEXT NOT NULL UNIQUE,
    bucket_name TEXT NOT NULL DEFAULT 'scrd-files',
    original_filename TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL CHECK (size_bytes > 0),
    sha256_checksum TEXT,
    access_scope TEXT NOT NULL DEFAULT 'public' CHECK (access_scope IN ('public', 'authenticated', 'research_team', 'project_team', 'exam_protected', 'chat_attachment', 'admin_only')),
    owner_user_id INTEGER,
    related_entity_type TEXT,
    related_entity_id INTEGER,
    alt_text_vi TEXT,
    alt_text_en TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_r2_files_scope ON r2_files(access_scope);
CREATE INDEX IF NOT EXISTS idx_r2_files_owner ON r2_files(owner_user_id);

-- 9. SCIENTIFIC RESEARCH (NGHIÊN CỨU KHOA HỌC)
CREATE TABLE IF NOT EXISTS research_studies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    field_vi TEXT NOT NULL,
    field_en TEXT NOT NULL,
    summary_vi TEXT NOT NULL,
    summary_en TEXT NOT NULL,
    methodology_vi TEXT,
    methodology_en TEXT,
    findings_summary_vi TEXT,
    findings_summary_en TEXT,
    status TEXT NOT NULL DEFAULT 'Đang triển khai' CHECK (status IN ('Đề xuất', 'Đang triển khai', 'Nghiệm thu', 'Đã công bố', 'Tạm dừng')),
    is_public INTEGER NOT NULL DEFAULT 1 CHECK (is_public IN (0, 1)),
    lead_user_id INTEGER,
    public_members_json TEXT NOT NULL DEFAULT '[]',
    progress_percent REAL NOT NULL DEFAULT 0 CHECK (progress_percent >= 0 AND progress_percent <= 100),
    start_date TEXT,
    end_date TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (lead_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- 10. COMMUNITY DEVELOPMENT PROJECTS (DỰ ÁN CỘNG ĐỒNG)
CREATE TABLE IF NOT EXISTS community_projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    objective_vi TEXT NOT NULL,
    objective_en TEXT NOT NULL,
    summary_vi TEXT NOT NULL,
    summary_en TEXT NOT NULL,
    activities_vi TEXT,
    activities_en TEXT,
    public_evidence_summary TEXT,
    status TEXT NOT NULL DEFAULT 'Đang thực hiện' CHECK (status IN ('Chuẩn bị', 'Đang thực hiện', 'Hoàn thành', 'Tạm hoãn')),
    is_public INTEGER NOT NULL DEFAULT 1 CHECK (is_public IN (0, 1)),
    manager_user_id INTEGER,
    progress_percent REAL NOT NULL DEFAULT 0 CHECK (progress_percent >= 0 AND progress_percent <= 100),
    start_date TEXT,
    end_date TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (manager_user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- 11. TASKS, MILESTONES & REAL PROGRESS TRACKING
CREATE TABLE IF NOT EXISTS work_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_type TEXT NOT NULL CHECK (parent_type IN ('research', 'project', 'general')),
    parent_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    assignee_user_id INTEGER,
    due_date TEXT,
    status TEXT NOT NULL DEFAULT 'todo' CHECK (status IN ('todo', 'in_progress', 'review', 'completed')),
    weight REAL NOT NULL DEFAULT 1.0 CHECK (weight > 0),
    milestone_name TEXT,
    evidence_r2_key TEXT,
    evidence_note TEXT,
    created_by INTEGER,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (assignee_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_work_tasks_parent ON work_tasks(parent_type, parent_id);

CREATE TABLE IF NOT EXISTS task_comments_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    user_id INTEGER,
    action_type TEXT NOT NULL CHECK (action_type IN ('comment', 'status_change', 'evidence_upload')),
    content TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (task_id) REFERENCES work_tasks(id) ON DELETE CASCADE
);

-- 12. ACADEMIC ASSESSMENT & TESTING (KHẢO THÍ VÀ ĐÁNH GIÁ HỌC THUẬT - PROTECTED AT BACKEND)
CREATE TABLE IF NOT EXISTS academic_assessments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    subject_area TEXT NOT NULL,
    public_overview_vi TEXT NOT NULL,
    public_overview_en TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    passing_score REAL NOT NULL DEFAULT 70.0,
    questions_encrypted_json TEXT NOT NULL, -- Never exposed to public API
    status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'closed')),
    created_by INTEGER,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS assessment_submissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    assessment_id INTEGER NOT NULL,
    candidate_user_id INTEGER NOT NULL,
    answers_json TEXT NOT NULL,
    score REAL,
    passed INTEGER CHECK (passed IN (0, 1)),
    graded_by INTEGER,
    submitted_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (assessment_id) REFERENCES academic_assessments(id) ON DELETE CASCADE,
    FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 13. PUBLICATIONS & DOCUMENTS LIBRARY (CÔNG BỐ VÀ TÀI LIỆU)
CREATE TABLE IF NOT EXISTS publications_documents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Hướng dẫn học thuật', 'Khung quy chuẩn', 'Báo cáo phương pháp', 'Biểu mẫu trung tâm')),
    summary_vi TEXT NOT NULL,
    summary_en TEXT NOT NULL,
    authors_text TEXT NOT NULL,
    access_level TEXT NOT NULL DEFAULT 'public' CHECK (access_level IN ('public', 'authenticated', 'research_only', 'admin_only')),
    r2_file_id INTEGER,
    published_date TEXT NOT NULL,
    download_count INTEGER NOT NULL DEFAULT 0,
    is_verified INTEGER NOT NULL DEFAULT 1 CHECK (is_verified IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (r2_file_id) REFERENCES r2_files(id) ON DELETE SET NULL
);

-- 14. DIRECT & GROUP CHAT WITH ACCESS CONTROL, BLOCK, REPORT & ANTI-SPAM
CREATE TABLE IF NOT EXISTS chat_rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_type TEXT NOT NULL CHECK (room_type IN ('direct', 'group')),
    name TEXT,
    created_by INTEGER NOT NULL,
    is_private INTEGER NOT NULL DEFAULT 1 CHECK (is_private = 1),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS chat_room_members (
    room_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'moderator', 'member')),
    last_read_message_id INTEGER DEFAULT 0,
    is_muted INTEGER NOT NULL DEFAULT 0,
    joined_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    PRIMARY KEY (room_id, user_id),
    FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_id INTEGER NOT NULL,
    sender_user_id INTEGER NOT NULL,
    message_text TEXT NOT NULL,
    attachment_r2_file_id INTEGER,
    is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (attachment_r2_file_id) REFERENCES r2_files(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS chat_blocks_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reporter_user_id INTEGER NOT NULL,
    target_user_id INTEGER NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('block', 'report')),
    reason TEXT,
    reported_message_id INTEGER,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'dismissed')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- 15. NOTIFICATIONS, SUPPORT TICKETS, EMAIL LOGS & SECURITY AUDIT LOGS
CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    body_vi TEXT NOT NULL,
    body_en TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'system',
    is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS support_requests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ticket_code TEXT NOT NULL UNIQUE,
    sender_name TEXT NOT NULL,
    sender_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    category TEXT NOT NULL,
    message TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    assigned_to INTEGER,
    resolution_note TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS email_dispatch_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'account_request_received',
        'account_request_supplement',
        'account_request_approved',
        'account_request_rejected',
        'account_activated',
        'password_reset',
        'research_notification',
        'project_notification',
        'assessment_notification',
        'task_assignment',
        'security_alert'
    )),
    recipient_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    reference_code TEXT,
    delivery_status TEXT NOT NULL CHECK (delivery_status IN ('queued', 'sent', 'failed', 'blocked_by_env')),
    provider_response TEXT,
    contains_sensitive_id INTEGER NOT NULL DEFAULT 0 CHECK (contains_sensitive_id = 0),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    actor_user_id INTEGER,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    ip_address TEXT,
    details_sanitized TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- ============================================================================
-- INITIAL SEED DATA (CMS CONFIG, 8 PUBLIC MENU ITEMS, 4-COL FOOTER, 9 ABOUT PAGES, AI DRAFT POST)
-- Zero fabricated achievements, zero fake partner logos, zero hardcoded admin credentials
-- ============================================================================

INSERT OR IGNORE INTO system_config (config_key, config_value) VALUES
('site_name_vi', 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First'),
('site_name_en', 'Sky First Center for Research and Development'),
('site_domain', 'https://scrd.skyfirst.io.vn'),
('support_email', 'support@skyfirst.io.vn'),
('technical_email', 'scrd@skyfirst.io.vn'),
('hero_title_vi', 'Hệ sinh thái Nghiên cứu Khoa học, Khảo thí Học thuật và Phát triển Cộng đồng'),
('hero_title_en', 'Ecosystem for Scientific Research, Academic Assessment and Community Development'),
('hero_subtitle_vi', 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First xây dựng nền tảng tri thức chuẩn mực, thúc đẩy các chương trình nghiên cứu ứng dụng, khảo thí minh bạch và dự án phục vụ cộng đồng bền vững.'),
('hero_subtitle_en', 'Sky First Center for Research and Development builds a rigorous knowledge platform, advancing applied research programs, transparent academic assessment, and sustainable community initiatives.'),
('hero_cta_primary_vi', 'Khám phá Lĩnh vực Hoạt động'),
('hero_cta_primary_en', 'Explore Our Core Areas'),
('hero_cta_secondary_vi', 'Yêu cầu Cấp Tài khoản'),
('hero_cta_secondary_en', 'Request Center Account'),
('cooperation_status_note_vi', 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First luôn mở rộng mạng lưới hợp tác học thuật và phát triển cộng đồng. Hiện tại danh sách đối tác công khai đang trong quá trình rà soát và xác nhận chính thức theo quy chuẩn minh bạch của Trung tâm.'),
('cooperation_status_note_en', 'Sky First Center for Research and Development continuously expands its academic and community collaboration network. Official partner listings are currently under formal verification in accordance with our transparency standards.');

-- 8 Main Public Menu Items (Section 4.2)
INSERT OR IGNORE INTO cms_menus (id, menu_location, parent_id, label_vi, label_en, target_url, link_type, sort_order, is_visible) VALUES
(1, 'main_header', NULL, 'Trang chủ', 'Home', '/', 'internal', 1, 1),
(2, 'main_header', NULL, 'Giới thiệu', 'About Us', '/gioi-thieu', 'internal', 2, 1),
(3, 'main_header', NULL, 'Nghiên cứu khoa học', 'Scientific Research', '/nghien-cuu-khoa-hoc', 'internal', 3, 1),
(4, 'main_header', NULL, 'Dự án cộng đồng', 'Community Projects', '/du-an-cong-dong', 'internal', 4, 1),
(5, 'main_header', NULL, 'Khảo thí và Đánh giá học thuật', 'Academic Assessment', '/khao-thi-danh-gia', 'internal', 5, 1),
(6, 'main_header', NULL, 'Công bố và Tài liệu', 'Publications & Documents', '/cong-bo-tai-lieu', 'internal', 6, 1),
(7, 'main_header', NULL, 'Hợp tác và Đối tác', 'Cooperation & Partners', '/hop-tac-doi-tac', 'internal', 7, 1),
(8, 'main_header', NULL, 'Tin tức và Hoạt động', 'News & Activities', '/tin-tuc-hoat-dong', 'internal', 8, 1),
-- Utility Header Navigation (Login, Request Lookup, Request Account, Forgot Password - Not in 8 main items per 4.2)
(9, 'utility_header', NULL, 'Tra cứu yêu cầu', 'Track Request', '/tra-cuu-yeu-cau', 'internal', 1, 1),
(10, 'utility_header', NULL, 'Yêu cầu cấp tài khoản', 'Request Account', '/yeu-cau-cap-tai-khoan', 'cta', 2, 1),
(11, 'utility_header', NULL, 'Quên mật khẩu', 'Forgot Password', '/quen-mat-khau', 'internal', 3, 1),
(12, 'utility_header', NULL, 'Đăng nhập', 'Sign In', '/dang-nhap', 'cta', 4, 1),
-- Desktop Footer 4 Columns (Section 4.10: Col 1 is standalone SFN Logo; Col 2: Về Trung tâm; Col 3: Kết nối Sky First; Col 4: Tài khoản Trung tâm; Clean names without raw URLs/phones)
(13, 'footer_col_2', NULL, 'Tổng quan Trung tâm', 'Center Overview', '/gioi-thieu/tong-quan', 'internal', 1, 1),
(14, 'footer_col_2', NULL, 'Sứ mệnh và tầm nhìn', 'Mission & Vision', '/gioi-thieu/su-menh-tam-nhin', 'internal', 2, 1),
(15, 'footer_col_2', NULL, 'Cơ cấu tổ chức', 'Organizational Structure', '/gioi-thieu/co-cau-to-chuc', 'internal', 3, 1),
(16, 'footer_col_2', NULL, 'Lĩnh vực hoạt động', 'Core Areas of Activity', '/gioi-thieu/linh-vuc-hoat-dong', 'internal', 4, 1),
(17, 'footer_col_3', NULL, 'Nghiên cứu khoa học', 'Scientific Research', '/nghien-cuu-khoa-hoc', 'internal', 1, 1),
(18, 'footer_col_3', NULL, 'Dự án cộng đồng', 'Community Projects', '/du-an-cong-dong', 'internal', 2, 1),
(19, 'footer_col_3', NULL, 'Hợp tác và Đối tác', 'Cooperation & Partners', '/hop-tac-doi-tac', 'internal', 3, 1),
(20, 'footer_col_3', NULL, 'Liên hệ và Hỗ trợ', 'Contact & Support', '/gioi-thieu/lien-he', 'internal', 4, 1),
(21, 'footer_col_4', NULL, 'Đăng nhập hệ thống', 'System Sign In', '/dang-nhap', 'internal', 1, 1),
(22, 'footer_col_4', NULL, 'Yêu cầu cấp tài khoản', 'Account Registration', '/yeu-cau-cap-tai-khoan', 'internal', 2, 1),
(23, 'footer_col_4', NULL, 'Tra cứu tiến độ yêu cầu', 'Application Status Lookup', '/tra-cuu-yeu-cau', 'internal', 3, 1),
(24, 'footer_col_4', NULL, 'Khôi phục mật khẩu', 'Password Recovery', '/quen-mat-khau', 'internal', 4, 1),
-- Footer Bottom Links
(25, 'footer_bottom', NULL, 'Chính sách bảo vệ dữ liệu cá nhân', 'Personal Data Protection Policy', '/gioi-thieu/chinh-sach-bao-ve-du-lieu', 'internal', 1, 1),
(26, 'footer_bottom', NULL, 'Điều khoản sử dụng', 'Terms of Use', '/gioi-thieu/dieu-khoan-su-dung', 'internal', 2, 1),
(27, 'footer_bottom', NULL, 'Hướng dẫn sử dụng', 'User Guide', '/gioi-thieu/huong-dan-su-dung', 'internal', 3, 1),
(28, 'footer_bottom', NULL, 'Hỗ trợ người dùng', 'User Support', '/gioi-thieu/ho-tro-nguoi-dung', 'internal', 4, 1);

-- 9 Required Public Introduction & Policy Pages (Section 4.3)
INSERT OR IGNORE INTO cms_pages (id, slug, title_vi, title_en, summary_vi, summary_en, content_vi, content_en, page_group, seo_title_vi, seo_description_vi, status, published_at) VALUES
(1, 'tong-quan', 'Tổng quan Trung tâm', 'Center Overview',
 'Giới thiệu chung về Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
 'General overview of Sky First Center for Research and Development.',
 '<p><strong>Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First</strong> (tên tiếng Anh: <em>Sky First Center for Research and Development</em>) là tổ chức hoạt động trong lĩnh vực nghiên cứu khoa học ứng dụng, phát triển các sáng kiến cộng đồng, khảo thí học thuật và phổ biến tri thức.</p><p>Trung tâm vận hành trên nguyên tắc minh bạch, chuẩn mực học thuật, bảo mật dữ liệu và lấy sự phát triển bền vững của cộng đồng làm trọng tâm.</p>',
 '<p><strong>Sky First Center for Research and Development</strong> operates in applied scientific research, community development initiatives, academic assessment, and knowledge dissemination.</p><p>The Center operates on the principles of transparency, academic rigor, data privacy, and sustainable community advancement.</p>',
 'about', 'Tổng quan | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Tổng quan chính thức về Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 'published', '2026-10-01T08:00:00Z'),

(2, 'su-menh-tam-nhin', 'Sứ mệnh và Tầm nhìn', 'Mission and Vision',
 'Định hướng chiến lược và giá trị cốt lõi của Trung tâm Sky First.',
 'Strategic direction and core values of Sky First Center.',
 '<h3>Sứ mệnh</h3><p>Kết nối tri thức khoa học với thực tiễn đời sống thông qua các chương trình nghiên cứu nghiêm túc, các dự án cộng đồng thiết thực và hệ thống đánh giá học thuật công bằng, bảo mật.</p><h3>Tầm nhìn</h3><p>Xây dựng hệ sinh thái nghiên cứu và phát triển cộng đồng hiện đại, chuẩn hóa quy trình số hóa và đóng góp tích cực vào sự phát triển năng lực học thuật của xã hội.</p>',
 '<h3>Mission</h3><p>Bridging scientific knowledge and real-world practice through rigorous research programs, practical community projects, and a fair, secure academic assessment system.</p><h3>Vision</h3><p>Building a modern community research and development ecosystem with standardized digital workflows that positively contribute to societal academic capacity.</p>',
 'about', 'Sứ mệnh và Tầm nhìn | Trung tâm Sky First', 'Sứ mệnh, tầm nhìn và giá trị cốt lõi của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 'published', '2026-10-01T08:00:00Z'),

(3, 'co-cau-to-chuc', 'Cơ cấu tổ chức', 'Organizational Structure',
 'Mô hình quản trị và các khối chuyên môn trực thuộc Trung tâm.',
 'Governance model and specialized divisions of the Center.',
 '<p>Cơ cấu tổ chức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First được thiết kế theo mô hình phối hợp chuyên môn chặt chẽ gồm các khối chức năng:</p><ul><li><strong>Ban Điều hành Trung tâm:</strong> Định hướng chiến lược, phê duyệt chương trình và giám sát tuân thủ quy chuẩn.</li><li><strong>Khối Nghiên cứu Khoa học:</strong> Tổ chức, thẩm định và triển khai các đề tài nghiên cứu, công bố khoa học.</li><li><strong>Khối Dự án Cộng đồng:</strong> Lập kế hoạch, điều phối hoạt động thực địa và theo dõi minh chứng tiến độ dự án.</li><li><strong>Khối Khảo thí và Đánh giá Học thuật:</strong> Xây dựng ngân hàng đánh giá, tổ chức khảo thí bảo mật và quản lý kết quả học thuật.</li><li><strong>Khối Công nghệ và Quản trị Dữ liệu:</strong> Vận hành hạ tầng kỹ thuật số, bảo vệ dữ liệu cá nhân và hỗ trợ kỹ thuật.</li></ul><p><em>Lưu ý: Danh sách nhân sự cụ thể chỉ được hiển thị khi có quyết định công bố chính thức và sự đồng ý của cá nhân theo chính sách bảo vệ dữ liệu.</em></p>',
 '<p>The organizational structure of Sky First Center for Research and Development is structured around specialized functional divisions:</p><ul><li><strong>Executive Board:</strong> Strategic direction, program approval, and compliance oversight.</li><li><strong>Scientific Research Division:</strong> Managing, reviewing, and executing research topics and publications.</li><li><strong>Community Projects Division:</strong> Planning, coordinating field activities, and verifying project milestones.</li><li><strong>Academic Assessment Division:</strong> Developing assessment frameworks, managing secure testing, and protecting academic records.</li><li><strong>Technology & Data Governance Division:</strong> Operating digital infrastructure, personal data protection, and technical support.</li></ul>',
 'about', 'Cơ cấu tổ chức | Trung tâm Sky First', 'Cơ cấu tổ chức và các khối chuyên môn của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 'published', '2026-10-01T08:00:00Z'),

(4, 'linh-vuc-hoat-dong', 'Lĩnh vực hoạt động', 'Core Areas of Activity',
 'Bốn trụ cột hoạt động trọng tâm của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
 'Four core pillars of activity at Sky First Center for Research and Development.',
 '<ul><li><strong>1. Nghiên cứu Khoa học và Ứng dụng:</strong> Thực hiện các đề tài nghiên cứu liên ngành, phương pháp giáo dục, công nghệ số và phát triển bền vững.</li><li><strong>2. Dự án Phát triển Cộng đồng:</strong> Triển khai các chương trình nâng cao năng lực, hỗ trợ kỹ năng và phát triển cộng đồng có theo dõi minh chứng rõ ràng.</li><li><strong>3. Khảo thí và Đánh giá Học thuật:</strong> Tổ chức đánh giá năng lực học thuật với cơ chế phân quyền nghiêm ngặt, bảo vệ tuyệt đối đề thi và kết quả cá nhân.</li><li><strong>4. Công bố Khoa học và Thư viện Tài liệu:</strong> Xây dựng kho tài liệu chuẩn hóa, hướng dẫn học thuật và ấn phẩm phục vụ cộng đồng theo phân quyền truy cập.</li></ul>',
 '<ul><li><strong>1. Scientific & Applied Research:</strong> Conducting interdisciplinary studies in education methodology, digital technology, and sustainable development.</li><li><strong>2. Community Development Projects:</strong> Implementing capacity-building and community support programs with verified milestone tracking.</li><li><strong>3. Academic Assessment & Testing:</strong> Organizing academic evaluations with strict access control, protecting exam content and individual results.</li><li><strong>4. Publications & Document Library:</strong> Maintaining a standardized repository of academic guides, methodological reports, and public/restricted documents.</li></ul>',
 'about', 'Lĩnh vực hoạt động | Trung tâm Sky First', 'Các lĩnh vực hoạt động chính của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 'published', '2026-10-01T08:00:00Z'),

(5, 'lien-he', 'Liên hệ', 'Contact Us',
 'Kênh thông tin liên hệ chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
 'Official contact channels of Sky First Center for Research and Development.',
 '<p>Mọi yêu cầu trao đổi học thuật, hợp tác dự án hoặc hỗ trợ hành chính, quý vị vui lòng liên hệ qua các kênh chính thức dưới đây:</p><ul><li><strong>Đơn vị:</strong> Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First (Sky First Center for Research and Development)</li><li><strong>Cổng thông tin điện tử:</strong> https://scrd.skyfirst.io.vn</li><li><strong>Email hỗ trợ chung:</strong> support@skyfirst.io.vn</li><li><strong>Email kỹ thuật & hệ thống:</strong> scrd@skyfirst.io.vn</li></ul>',
 '<p>For academic inquiries, project partnerships, or administrative assistance, please contact us through our official channels:</p><ul><li><strong>Organization:</strong> Sky First Center for Research and Development</li><li><strong>Official Portal:</strong> https://scrd.skyfirst.io.vn</li><li><strong>General Support Email:</strong> support@skyfirst.io.vn</li><li><strong>Technical & System Email:</strong> scrd@skyfirst.io.vn</li></ul>',
 'support', 'Liên hệ | Trung tâm Sky First', 'Thông tin liên hệ chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 'published', '2026-10-01T08:00:00Z'),

(6, 'chinh-sach-bao-ve-du-lieu', 'Chính sách bảo vệ dữ liệu cá nhân', 'Personal Data Protection Policy',
 'Quy định thu thập, xử lý, mã hóa và bảo vệ dữ liệu cá nhân tại hệ thống Sky First Center.',
 'Regulations on collecting, processing, encrypting, and protecting personal data at Sky First Center.',
 '<h3>1. Nguyên tắc thu thập và tối thiểu hóa dữ liệu</h3><p>Trung tâm chỉ thu thập các thông tin cần thiết phục vụ xác minh danh tính, xét duyệt tài khoản, quản lý nghiên cứu, dự án và khảo thí học thuật theo sự đồng ý rõ ràng của chủ thể dữ liệu.</p><h3>2. Bảo vệ thông tin định danh và người chưa thành niên</h3><p>Số giấy tờ định danh (CCCD/Hộ chiếu) và hình ảnh giấy tờ được lưu trữ phân quyền nghiêm ngặt trên cơ sở dữ liệu và hệ thống lưu trữ bảo mật; tuyệt đối không đính kèm thông tin nhạy cảm vào email thông báo tự động. Đối với người đăng ký dưới 18 tuổi, hệ thống bắt buộc xác nhận thông tin và sự đồng ý của người giám hộ hợp pháp.</p><h3>3. Quyền của chủ thể dữ liệu</h3><p>Người dùng có quyền tra cứu, yêu cầu cập nhật, hạn chế xử lý hoặc gửi yêu cầu hỗ trợ về dữ liệu cá nhân thông qua bộ phận Hỗ trợ tại địa chỉ support@skyfirst.io.vn.</p>',
 '<h3>1. Data Minimization & Lawful Collection</h3><p>The Center collects only essential information required for identity verification, account approval, research management, projects, and academic assessment with explicit user consent.</p><h3>2. Protection of Identity Documents & Minors</h3><p>Identity numbers and document scans are strictly access-controlled in D1/R2 storage and are never included in automated confirmation emails. For applicants under 18, legal guardian details and explicit consent are mandatory.</p><h3>3. Data Subject Rights</h3><p>Users have the right to inspect, update, or request assistance regarding their personal data via support@skyfirst.io.vn.</p>',
 'policy', 'Chính sách bảo vệ dữ liệu cá nhân | Trung tâm Sky First', 'Chính sách bảo vệ dữ liệu cá nhân của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 'published', '2026-10-01T08:00:00Z'),

(7, 'dieu-khoan-su-dung', 'Điều khoản sử dụng', 'Terms of Use',
 'Quy định về quyền, nghĩa vụ và chuẩn mực sử dụng hệ thống thông tin của Trung tâm.',
 'Rules on rights, obligations, and acceptable use of the Center information system.',
 '<h3>1. Phạm vi áp dụng</h3><p>Điều khoản này áp dụng cho toàn bộ người truy cập website công khai, người gửi yêu cầu cấp tài khoản và thành viên sử dụng bảng điều khiển nội bộ hoặc ứng dụng máy tính của Trung tâm.</p><h3>2. Trách nhiệm bảo mật tài khoản và liêm chính học thuật</h3><p>Thành viên chịu trách nhiệm bảo mật thông tin đăng nhập, tuân thủ quy định phân quyền truy cập tài liệu, đề thi khảo thí và dữ liệu dự án. Nghiêm cấm mọi hành vi can thiệp trái phép vào API, phát tán mã độc hoặc giả mạo thông tin định danh.</p>',
 '<h3>1. Scope of Application</h3><p>These terms apply to all visitors of the public website, account applicants, and members using the internal dashboard or desktop applications of the Center.</p><h3>2. Account Security & Academic Integrity</h3><p>Members are responsible for safeguarding credentials and respecting access controls for documents, assessments, and project records. Unauthorized API manipulation or identity falsification is strictly prohibited.</p>',
 'policy', 'Điều khoản sử dụng | Trung tâm Sky First', 'Điều khoản sử dụng hệ thống Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 'published', '2026-10-01T08:00:00Z'),

(8, 'huong-dan-su-dung', 'Hướng dẫn sử dụng', 'User Guide',
 'Hướng dẫn quy trình 5 bước đăng ký tài khoản, tra cứu mã yêu cầu SCRD-SFN và sử dụng hệ thống.',
 'Step-by-step guide on the 5-step account registration, SCRD-SFN code lookup, and system usage.',
 '<h3>1. Quy trình đăng ký cấp tài khoản (5 bước)</h3><ol><li><strong>Bước 1 - Thông tin cá nhân:</strong> Nhập họ tên, ngày sinh, email, số điện thoại và thông tin người giám hộ (nếu dưới 18 tuổi).</li><li><strong>Bước 2 - Học tập và công tác:</strong> Khai báo trình độ học vấn, đơn vị công tác/học tập và chuyên ngành.</li><li><strong>Bước 3 - Thông tin định danh:</strong> Cung cấp thông tin giấy tờ định danh và tệp đính kèm bảo mật (không phát tán qua email).</li><li><strong>Bước 4 - Thông tin bổ sung theo mục đích:</strong> Chọn vai trò đăng ký và mô tả định hướng tham gia nghiên cứu, dự án hoặc khảo thí.</li><li><strong>Bước 5 - Xét yêu cầu và xác nhận:</strong> Kiểm tra lại hồ sơ, xác nhận đồng ý chính sách và nhận mã tra cứu định dạng <code>SCRD-SFN-XXXXXXXXXX</code>.</li></ol><h3>2. Tra cứu trạng thái hồ sơ</h3><p>Sử dụng chức năng <strong>Tra cứu yêu cầu</strong> với Mã yêu cầu và Email đăng ký để theo dõi tiến độ xét duyệt theo thời gian thực.</p>',
 '<h3>1. 5-Step Account Registration</h3><ol><li><strong>Step 1 - Personal Details:</strong> Full name, DOB, contact details, and guardian info (if under 18).</li><li><strong>Step 2 - Education & Work:</strong> Academic background and current institution.</li><li><strong>Step 3 - Identity Verification:</strong> Protected ID information (never exposed in emails).</li><li><strong>Step 4 - Purpose & Role Details:</strong> Requested role and research/project interests.</li><li><strong>Step 5 - Review & Confirmation:</strong> Consent verification and generation of unique <code>SCRD-SFN-XXXXXXXXXX</code> tracking code.</li></ol>',
 'support', 'Hướng dẫn sử dụng | Trung tâm Sky First', 'Hướng dẫn sử dụng cổng thông tin Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 'published', '2026-10-01T08:00:00Z'),

(9, 'ho-tro-nguoi-dung', 'Hỗ trợ người dùng', 'User Support',
 'Trung tâm tiếp nhận yêu cầu hỗ trợ kỹ thuật, bổ sung hồ sơ và giải đáp thắc mắc.',
 'Support center for technical assistance, application supplementation, and inquiries.',
 '<p>Nếu quý vị gặp khó khăn trong quá trình đăng ký tài khoản, tra cứu mã yêu cầu, tải tài liệu hoặc cài đặt ứng dụng máy tính (Windows/macOS), vui lòng gửi yêu cầu trực tiếp qua biểu mẫu Hỗ trợ hoặc liên hệ:</p><ul><li><strong>Hỗ trợ người dùng & Hồ sơ:</strong> support@skyfirst.io.vn</li><li><strong>Hỗ trợ kỹ thuật hệ thống:</strong> scrd@skyfirst.io.vn</li></ul>',
 '<p>If you need assistance with account registration, request code lookup, document downloads, or desktop app installation (Windows/macOS), please submit a support ticket or email:</p><ul><li><strong>User & Application Support:</strong> support@skyfirst.io.vn</li><li><strong>Technical System Support:</strong> scrd@skyfirst.io.vn</li></ul>',
 'support', 'Hỗ trợ người dùng | Trung tâm Sky First', 'Cổng hỗ trợ người dùng Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 'published', '2026-10-01T08:00:00Z');

-- Initial CMS Posts (Including Published News & Pre-created AI Draft Post per Section 6.2 that is 100% unlocked and editable)
INSERT OR IGNORE INTO cms_posts (id, slug, custom_path, title_vi, title_en, excerpt_vi, excerpt_en, content_vi, content_en, category, tags_json, display_author, is_ai_generated, is_locked, status, seo_title, seo_description, published_at) VALUES
(1, 'ra-mat-nen-tang-so-sky-first-center', '/tin-tuc-hoat-dong/ra-mat-nen-tang-so-sky-first-center',
 'Vận hành Hệ thống Thông tin và Quản trị Nghiên cứu Sky First Center',
 'Launching the Sky First Center Information and Research Governance System',
 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First chính thức đưa vào vận hành hệ thống cổng thông tin tích hợp quản lý nghiên cứu, dự án cộng đồng và khảo thí học thuật.',
 'Sky First Center for Research and Development officially launches its integrated portal for scientific research, community projects, and academic assessment.',
 '<p>Nhằm chuẩn hóa quy trình quản lý khoa học và phục vụ cộng đồng, <strong>Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First</strong> triển khai nền tảng số hóa đồng bộ trên trình duyệt web và ứng dụng máy tính.</p><p>Hệ thống tích hợp quy trình đăng ký tài khoản 5 bước với mã định danh yêu cầu <code>SCRD-SFN-</code>, quản trị nội dung minh bạch và bảo vệ dữ liệu theo chuẩn mực an toàn thông tin.</p>',
 '<p>To standardize scientific management and community service workflows, <strong>Sky First Center for Research and Development</strong> deploys a unified digital platform across web browsers and desktop applications.</p>',
 'Hoạt động Trung tâm', '["Hệ thống số", "Quản trị nghiên cứu", "Cộng đồng"]', 'Ban Biên tập Sky First', 0, 0, 'published',
 'Vận hành Hệ thống Thông tin Sky First Center', 'Thông báo chính thức về việc vận hành cổng thông tin Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', '2026-10-15T09:00:00Z'),

(2, 'quy-chuan-dang-ky-tai-khoan-va-bao-mat-dinh-danh', '/tin-tuc-hoat-dong/quy-chuan-dang-ky-tai-khoan-va-bao-mat-dinh-danh',
 'Hướng dẫn Quy chuẩn Đăng ký Tài khoản 5 Bước và Bảo vệ Dữ liệu Cá nhân',
 'Guidelines on the 5-Step Account Registration Standard and Personal Data Protection',
 'Quy trình xét duyệt tài khoản tại Trung tâm đảm bảo kiểm soát phân quyền chặt chẽ, bảo vệ người chưa thành niên và không tiết lộ dữ liệu định danh qua email.',
 'The account approval workflow ensures strict role-based access control, minor protection, and zero sensitive ID exposure in emails.',
 '<p>Mọi hồ sơ đăng ký tài khoản tại Trung tâm đều được cấp mã tra cứu duy nhất theo cấu trúc <code>SCRD-SFN-</code> kèm 10 chữ số ngẫu nhiên. Người đăng ký có thể chủ động kiểm tra trạng thái xử lý trực tuyến mà không lộ thông tin nhạy cảm.</p>',
 '<p>Every account application at the Center is assigned a unique tracking code following the <code>SCRD-SFN-</code> + 10 random digits format, allowing secure status lookup without exposing sensitive identity data.</p>',
 'Thông báo Học thuật', '["Bảo mật dữ liệu", "Tài khoản", "Quy chuẩn"]', 'Khối Quản trị Dữ liệu', 0, 0, 'published',
 'Quy chuẩn Đăng ký Tài khoản 5 Bước | Sky First Center', 'Hướng dẫn chi tiết quy trình đăng ký và bảo mật dữ liệu cá nhân tại Trung tâm Sky First.', '2026-10-18T10:30:00Z'),

(3, 'ai-draft-phuong-phap-danh-gia-tac-dong-cong-dong', '/tin-tuc-hoat-dong/phuong-phap-danh-gia-tac-dong-cong-dong',
 '[Bản nháp AI] Khung Phương pháp Đánh giá Tác động Dự án Phát triển Cộng đồng',
 '[AI Draft] Methodological Framework for Community Project Impact Assessment',
 'Bài viết do trợ lý AI khởi tạo tự động dưới dạng bản nháp để Quản trị viên rà soát, chỉnh sửa toàn diện tiêu đề, nội dung, slug và trạng thái trước khi xuất bản.',
 'AI-generated draft article saved as draft by default for Administrators to review and edit all fields before publication.',
 '<p>Bài viết này được hệ thống AI hỗ trợ tổng hợp nháp về phương pháp theo dõi tiến độ và đánh giá minh chứng trong các dự án cộng đồng. Quản trị viên có toàn quyền chỉnh sửa tiêu đề, mô tả, nội dung, chuyên mục, đường dẫn (slug) và quyết định xuất bản hoặc gỡ xuất bản bất kỳ lúc nào.</p>',
 '<p>This draft article was synthesized by the AI assistant regarding milestone tracking and evidence evaluation in community projects. Administrators have full permissions to edit the title, description, body, category, slug, and publication status at any time.</p>',
 'Nghiên cứu Khoa học', '["AI Draft", "Phương pháp luận", "Dự án cộng đồng"]', 'AI Editorial Assistant', 1, 0, 'draft',
 'Khung Phương pháp Đánh giá Tác động Cộng đồng', 'Bản nháp nghiên cứu phương pháp đánh giá tác động cộng đồng.', NULL);