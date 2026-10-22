-- ============================================================================
-- TRUNG TÂM NGHIÊN CỨU VÀ PHÁT TRIỂN CỘNG ĐỒNG SKY FIRST
-- SKY FIRST CENTER FOR RESEARCH AND DEVELOPMENT
-- Official Domain: https://scrd.skyfirst.io.vn
-- Exam Portal Domain: https://exam.skyfirst.io.vn
-- Support Email: support@skyfirst.io.vn
-- Cloudflare D1 Database ID: 6006fe24-6278-4989-8d94-fd4734d71679 (Binding: DB)
-- Cloudflare R2 Bucket Name: scrd-files (Binding: FILES)
-- Migration Version: 0001_unified_scrd_exam_schema.sql (Idempotent & Non-Destructive)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- 1. SYSTEM CONFIGURATION & ONE-TIME BOOTSTRAP STATE
CREATE TABLE IF NOT EXISTS system_config (
    config_key TEXT PRIMARY KEY,
    config_value TEXT NOT NULL,
    is_public INTEGER NOT NULL DEFAULT 1 CHECK (is_public IN (0, 1)),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_by TEXT
);

CREATE TABLE IF NOT EXISTS bootstrap_state (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    is_bootstrapped INTEGER NOT NULL DEFAULT 0 CHECK (is_bootstrapped IN (0, 1)),
    bootstrapped_at TEXT,
    bootstrapped_admin_id TEXT,
    bootstrap_ip TEXT,
    integrity_hash TEXT
);

INSERT OR IGNORE INTO bootstrap_state (id, is_bootstrapped) VALUES (1, 0);

-- 2. USERS, SESSIONS, PASSWORD RESET TOKENS & RATE LIMITING
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    sfn_id TEXT UNIQUE,
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    password_hash TEXT NOT NULL,
    password_salt TEXT NOT NULL DEFAULT '',
    full_name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN (
        'super_admin',
        'cms_editor',
        'reviewer',
        'research_lead',
        'researcher',
        'project_manager',
        'project_lead',
        'examiner',
        'member',
        'student'
    )),
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
    must_change_password INTEGER NOT NULL DEFAULT 0 CHECK (must_change_password IN (0, 1)),
    last_login_at TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role_status ON users(role, status);
CREATE INDEX IF NOT EXISTS idx_users_sfn_id ON users(sfn_id);

CREATE TABLE IF NOT EXISTS user_sessions (
    session_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    csrf_token TEXT NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    expires_at TEXT NOT NULL,
    revoked INTEGER NOT NULL DEFAULT 0 CHECK (revoked IN (0, 1)),
    revoked_at TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token_hash ON user_sessions(token_hash);

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TEXT NOT NULL,
    used_at TEXT,
    ip_address TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_pwd_reset_token_hash ON password_reset_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_pwd_reset_user ON password_reset_tokens(user_id);

CREATE TABLE IF NOT EXISTS rate_limits (
    rate_key TEXT PRIMARY KEY,
    window_start INTEGER NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 1,
    blocked_until TEXT
);

-- 3. 5-STEP ACCOUNT REGISTRATION REQUESTS & REVIEW AUDIT HISTORY
CREATE TABLE IF NOT EXISTS account_requests (
    id TEXT PRIMARY KEY,
    request_code TEXT NOT NULL UNIQUE CHECK (request_code GLOB 'SCRD-SFN-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'),
    -- Step 1: Personal Information & Minor (<18) Guardian Verification
    full_name TEXT NOT NULL,
    email TEXT NOT NULL COLLATE NOCASE,
    phone TEXT NOT NULL,
    gender TEXT NOT NULL CHECK (gender IN ('Nam', 'Nữ', 'male', 'female')),
    date_of_birth TEXT NOT NULL,
    calculated_age INTEGER NOT NULL DEFAULT 18,
    is_minor INTEGER NOT NULL DEFAULT 0 CHECK (is_minor IN (0, 1)),
    guardian_full_name TEXT,
    guardian_relationship TEXT,
    guardian_phone TEXT,
    guardian_email TEXT,
    guardian_consent INTEGER NOT NULL DEFAULT 0 CHECK (guardian_consent IN (0, 1)),
    personal_photo_r2_key TEXT,
    -- Step 2: Education & Work (Conditional by Applicant Group)
    applicant_group TEXT NOT NULL DEFAULT 'general',
    education_level TEXT NOT NULL,
    institution_name TEXT NOT NULL,
    major_or_field TEXT NOT NULL,
    current_occupation TEXT NOT NULL,
    work_unit TEXT,
    class_name TEXT,
    faculty_department TEXT,
    position_title TEXT,
    -- Step 3: Identity Document Information (Encrypted at Backend, Never Sent in Emails)
    id_document_type TEXT NOT NULL CHECK (id_document_type IN ('CCCD', 'Passport', 'StudentCard', 'BirthCertificate')),
    id_number_encrypted TEXT NOT NULL,
    id_number_hash TEXT,
    id_number_masked TEXT NOT NULL,
    id_issued_date TEXT NOT NULL,
    id_issued_place TEXT NOT NULL,
    id_expiry_date TEXT,
    id_front_r2_key TEXT,
    id_back_r2_key TEXT,
    -- Step 4: Purpose & Supplemental Information (Cannot Self-Assign Admin Roles)
    requested_role TEXT NOT NULL DEFAULT 'member' CHECK (requested_role IN (
        'member',
        'student',
        'research_lead',
        'researcher',
        'project_manager',
        'project_lead',
        'examiner',
        'reviewer'
    )),
    registration_purpose TEXT NOT NULL,
    research_or_project_interest TEXT NOT NULL,
    experience_summary TEXT,
    supporting_doc_r2_key TEXT,
    -- Step 5: Policy Consents, Digital Signature & Review Workflow
    privacy_policy_accepted INTEGER NOT NULL CHECK (privacy_policy_accepted = 1),
    terms_accepted INTEGER NOT NULL CHECK (terms_accepted = 1),
    data_accuracy_confirmed INTEGER NOT NULL CHECK (data_accuracy_confirmed = 1),
    signature_data TEXT,
    status TEXT NOT NULL DEFAULT 'Đã tiếp nhận' CHECK (status IN (
        'Đã tiếp nhận',
        'Đang xem xét',
        'Cần bổ sung thông tin',
        'Đã duyệt',
        'Từ chối',
        'Đã kích hoạt tài khoản'
    )),
    assigned_role TEXT,
    reviewer_id TEXT,
    review_notes_public TEXT,
    review_notes_internal TEXT,
    supplement_request_message TEXT,
    approved_user_id TEXT,
    reviewed_at TEXT,
    submitted_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (reviewer_id) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (approved_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_account_requests_code_email ON account_requests(request_code, email);
CREATE INDEX IF NOT EXISTS idx_account_requests_status ON account_requests(status);

CREATE TABLE IF NOT EXISTS account_request_history (
    id TEXT PRIMARY KEY,
    request_id TEXT NOT NULL,
    actor_user_id TEXT,
    old_status TEXT,
    new_status TEXT NOT NULL,
    note_public TEXT,
    note_internal TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (request_id) REFERENCES account_requests(id) ON DELETE CASCADE,
    FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_account_request_history_req ON account_request_history(request_id);

-- 4. CMS PAGES, REVISIONS, POSTS (UNLOCKED AI DRAFTS), MENUS & REDIRECTS
CREATE TABLE IF NOT EXISTS cms_pages (
    id TEXT PRIMARY KEY,
    slug TEXT NOT NULL UNIQUE,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    summary_vi TEXT,
    summary_en TEXT,
    content_vi TEXT NOT NULL,
    content_en TEXT NOT NULL,
    page_group TEXT NOT NULL DEFAULT 'about' CHECK (page_group IN ('home', 'about', 'policy', 'support', 'cooperation', 'general')),
    featured_media_id TEXT,
    seo_title_vi TEXT,
    seo_title_en TEXT,
    seo_description_vi TEXT,
    seo_description_en TEXT,
    sort_order INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'unpublished', 'archived')),
    version INTEGER NOT NULL DEFAULT 1,
    author_id TEXT,
    published_at TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_cms_pages_slug ON cms_pages(slug);
CREATE INDEX IF NOT EXISTS idx_cms_pages_status ON cms_pages(status);

CREATE TABLE IF NOT EXISTS cms_page_revisions (
    id TEXT PRIMARY KEY,
    page_id TEXT NOT NULL,
    version INTEGER NOT NULL,
    title_vi TEXT NOT NULL,
    content_vi TEXT NOT NULL,
    edited_by TEXT,
    edited_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (page_id) REFERENCES cms_pages(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS cms_posts (
    id TEXT PRIMARY KEY,
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
    featured_media_id TEXT,
    display_author TEXT NOT NULL,
    author_id TEXT,
    is_ai_generated INTEGER NOT NULL DEFAULT 0 CHECK (is_ai_generated IN (0, 1)),
    is_locked INTEGER NOT NULL DEFAULT 0 CHECK (is_locked = 0),
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

CREATE TABLE IF NOT EXISTS cms_menus (
    id TEXT PRIMARY KEY,
    menu_location TEXT NOT NULL CHECK (menu_location IN ('main_header', 'utility_header', 'footer_col_2', 'footer_col_3', 'footer_col_4', 'footer_bottom')),
    parent_id TEXT,
    label_vi TEXT NOT NULL,
    label_en TEXT NOT NULL,
    target_url TEXT NOT NULL,
    link_type TEXT NOT NULL DEFAULT 'internal' CHECK (link_type IN ('internal', 'external', 'cta', 'section')),
    sort_order INTEGER NOT NULL DEFAULT 1,
    is_visible INTEGER NOT NULL DEFAULT 1 CHECK (is_visible IN (0, 1)),
    open_in_new_tab INTEGER NOT NULL DEFAULT 0 CHECK (open_in_new_tab IN (0, 1)),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (parent_id) REFERENCES cms_menus(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_cms_menus_location_order ON cms_menus(menu_location, sort_order);

CREATE TABLE IF NOT EXISTS cms_redirects (
    id TEXT PRIMARY KEY,
    old_path TEXT NOT NULL UNIQUE,
    new_path TEXT NOT NULL,
    status_code INTEGER NOT NULL DEFAULT 301 CHECK (status_code IN (301, 302)),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- 5. CLOUDFLARE R2 MEDIA & PROTECTED FILES METADATA
CREATE TABLE IF NOT EXISTS r2_files (
    id TEXT PRIMARY KEY,
    r2_key TEXT NOT NULL UNIQUE,
    bucket_name TEXT NOT NULL DEFAULT 'scrd-files',
    original_filename TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL CHECK (size_bytes > 0),
    sha256_checksum TEXT,
    access_scope TEXT NOT NULL DEFAULT 'public' CHECK (access_scope IN (
        'public',
        'authenticated',
        'research_team',
        'project_team',
        'exam_protected',
        'chat_attachment',
        'identity_private',
        'admin_only'
    )),
    purpose TEXT NOT NULL DEFAULT 'general',
    owner_user_id TEXT,
    related_entity_type TEXT,
    related_entity_id TEXT,
    alt_text_vi TEXT,
    alt_text_en TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_r2_files_scope ON r2_files(access_scope);
CREATE INDEX IF NOT EXISTS idx_r2_files_owner ON r2_files(owner_user_id);

-- 6. SCIENTIFIC RESEARCH, COMMUNITY PROJECTS, TASKS, PUBLICATIONS & VERIFIED PARTNERS
CREATE TABLE IF NOT EXISTS research_studies (
    id TEXT PRIMARY KEY,
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
    lead_user_id TEXT,
    public_members_json TEXT NOT NULL DEFAULT '[]',
    progress_percent REAL NOT NULL DEFAULT 0 CHECK (progress_percent >= 0 AND progress_percent <= 100),
    start_date TEXT,
    end_date TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (lead_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS community_projects (
    id TEXT PRIMARY KEY,
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
    location TEXT,
    status TEXT NOT NULL DEFAULT 'Đang thực hiện' CHECK (status IN ('Chuẩn bị', 'Đang thực hiện', 'Hoàn thành', 'Tạm hoãn')),
    is_public INTEGER NOT NULL DEFAULT 1 CHECK (is_public IN (0, 1)),
    manager_user_id TEXT,
    progress_percent REAL NOT NULL DEFAULT 0 CHECK (progress_percent >= 0 AND progress_percent <= 100),
    start_date TEXT,
    end_date TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (manager_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS work_tasks (
    id TEXT PRIMARY KEY,
    parent_type TEXT NOT NULL CHECK (parent_type IN ('research', 'project', 'general')),
    parent_id TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    assignee_user_id TEXT,
    due_date TEXT,
    status TEXT NOT NULL DEFAULT 'todo' CHECK (status IN ('todo', 'in_progress', 'review', 'completed')),
    weight REAL NOT NULL DEFAULT 1.0 CHECK (weight > 0),
    milestone_name TEXT,
    evidence_r2_key TEXT,
    evidence_note TEXT,
    created_by TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (assignee_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_work_tasks_parent ON work_tasks(parent_type, parent_id);

CREATE TABLE IF NOT EXISTS task_comments_history (
    id TEXT PRIMARY KEY,
    task_id TEXT NOT NULL,
    user_id TEXT,
    action_type TEXT NOT NULL CHECK (action_type IN ('comment', 'status_change', 'evidence_upload')),
    content TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (task_id) REFERENCES work_tasks(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS publications_documents (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    slug TEXT UNIQUE,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('Hướng dẫn học thuật', 'Khung quy chuẩn', 'Báo cáo phương pháp', 'Biểu mẫu trung tâm')),
    summary_vi TEXT NOT NULL,
    summary_en TEXT NOT NULL,
    authors_text TEXT NOT NULL,
    access_level TEXT NOT NULL DEFAULT 'public' CHECK (access_level IN ('public', 'authenticated', 'research_only', 'admin_only')),
    r2_file_id TEXT,
    published_date TEXT NOT NULL,
    download_count INTEGER NOT NULL DEFAULT 0,
    is_verified INTEGER NOT NULL DEFAULT 1 CHECK (is_verified IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (r2_file_id) REFERENCES r2_files(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS partners (
    id TEXT PRIMARY KEY,
    code TEXT UNIQUE,
    organization_name_vi TEXT NOT NULL,
    organization_name_en TEXT,
    partner_type TEXT NOT NULL DEFAULT 'academic',
    website_url TEXT,
    logo_r2_key TEXT,
    description_vi TEXT,
    description_en TEXT,
    mou_reference TEXT,
    is_verified INTEGER NOT NULL DEFAULT 0 CHECK (is_verified IN (0, 1)),
    is_public INTEGER NOT NULL DEFAULT 0 CHECK (is_public IN (0, 1)),
    verified_by TEXT,
    verified_at TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- 7. ACADEMIC ASSESSMENT & SHARED EXAM PORTAL TABLES (exam.skyfirst.io.vn INTEGRATION)
CREATE TABLE IF NOT EXISTS academic_assessments (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    title_vi TEXT NOT NULL,
    title_en TEXT NOT NULL,
    subject_area TEXT NOT NULL,
    public_overview_vi TEXT NOT NULL,
    public_overview_en TEXT NOT NULL,
    duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
    passing_score REAL NOT NULL DEFAULT 70.0,
    questions_encrypted_json TEXT NOT NULL DEFAULT '[]',
    status TEXT NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'closed')),
    created_by TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS assessment_submissions (
    id TEXT PRIMARY KEY,
    assessment_id TEXT NOT NULL,
    candidate_user_id TEXT NOT NULL,
    answers_json TEXT NOT NULL,
    score REAL,
    passed INTEGER CHECK (passed IN (0, 1)),
    graded_by TEXT,
    submitted_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (assessment_id) REFERENCES academic_assessments(id) ON DELETE CASCADE,
    FOREIGN KEY (candidate_user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Shared Exam Delivery Tables used directly by exam.skyfirst.io.vn Worker
CREATE TABLE IF NOT EXISTS classes (
    id TEXT PRIMARY KEY,
    code TEXT UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    created_by TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS exams (
    id TEXT PRIMARY KEY,
    class_id TEXT,
    code TEXT UNIQUE,
    title TEXT NOT NULL,
    title_en TEXT,
    instructions TEXT,
    public_overview_vi TEXT,
    public_overview_en TEXT,
    duration_minutes INTEGER NOT NULL DEFAULT 60,
    time_limit_enabled INTEGER NOT NULL DEFAULT 1,
    strict_mode INTEGER NOT NULL DEFAULT 0,
    fullscreen_required INTEGER NOT NULL DEFAULT 0,
    show_score INTEGER NOT NULL DEFAULT 1,
    pass_score REAL NOT NULL DEFAULT 70.0,
    assessment_type TEXT DEFAULT 'academic',
    assessment_label TEXT DEFAULT 'Đánh giá học thuật',
    center_label TEXT DEFAULT 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First',
    result_policy TEXT DEFAULT 'score_after_submit',
    result_release_at TEXT,
    opens_at TEXT,
    closes_at TEXT,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'review', 'approved', 'published', 'closed')),
    security_profile TEXT DEFAULT 'STANDARD',
    allow_clipboard INTEGER NOT NULL DEFAULT 0,
    allow_paste INTEGER NOT NULL DEFAULT 0,
    allow_external_links INTEGER NOT NULL DEFAULT 0,
    device_policy TEXT DEFAULT 'single_session',
    resume_policy TEXT DEFAULT 'same_session',
    calculator_policy TEXT DEFAULT 'disabled',
    public_access INTEGER NOT NULL DEFAULT 0,
    public_token TEXT UNIQUE,
    require_email_verify INTEGER NOT NULL DEFAULT 0,
    sealed_version_id TEXT,
    question_json TEXT NOT NULL DEFAULT '[]',
    created_by TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS assessment_exam_versions (
    id TEXT PRIMARY KEY,
    exam_id TEXT NOT NULL,
    version_number INTEGER NOT NULL DEFAULT 1,
    snapshot_json TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exam_attempts (
    id TEXT PRIMARY KEY,
    exam_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    exam_version_id TEXT,
    status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'submitted', 'expired', 'terminated')),
    started_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    submitted_at TEXT,
    last_saved_at TEXT,
    duration_minutes INTEGER NOT NULL DEFAULT 60,
    extra_time_minutes INTEGER NOT NULL DEFAULT 0,
    time_limit_enabled INTEGER NOT NULL DEFAULT 1,
    question_snapshot_json TEXT,
    answers_json TEXT NOT NULL DEFAULT '{}',
    event_log_json TEXT NOT NULL DEFAULT '[]',
    answer_revision INTEGER NOT NULL DEFAULT 0,
    score REAL,
    max_score REAL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exam_guest_attempts (
    id TEXT PRIMARY KEY,
    exam_id TEXT NOT NULL,
    exam_version_id TEXT,
    access_key TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    candidate_code TEXT NOT NULL,
    class_name TEXT,
    status TEXT NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'submitted', 'expired', 'terminated')),
    started_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    submitted_at TEXT,
    last_saved_at TEXT,
    duration_minutes INTEGER NOT NULL DEFAULT 60,
    extra_time_minutes INTEGER NOT NULL DEFAULT 0,
    time_limit_enabled INTEGER NOT NULL DEFAULT 1,
    question_snapshot_json TEXT,
    answers_json TEXT NOT NULL DEFAULT '{}',
    event_log_json TEXT NOT NULL DEFAULT '[]',
    answer_revision INTEGER NOT NULL DEFAULT 0,
    score REAL,
    max_score REAL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (exam_id) REFERENCES exams(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exam_launch_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    attempt_id TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    used_at TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS exam_access_tokens (
    token_hash TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    attempt_id TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (attempt_id) REFERENCES exam_attempts(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS assessment_attempt_leases (
    attempt_id TEXT NOT NULL,
    source TEXT NOT NULL,
    session_id TEXT NOT NULL,
    claimed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attempt_id, source)
);

CREATE TABLE IF NOT EXISTS assessment_answer_revisions (
    id TEXT PRIMARY KEY,
    attempt_id TEXT NOT NULL,
    source TEXT NOT NULL,
    revision INTEGER NOT NULL,
    answers_json TEXT NOT NULL,
    events_json TEXT NOT NULL,
    accepted_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS assessment_manual_grades (
    id TEXT PRIMARY KEY,
    attempt_id TEXT NOT NULL,
    question_id TEXT NOT NULL,
    grader_user_id TEXT,
    score REAL,
    feedback TEXT,
    status TEXT NOT NULL DEFAULT 'draft',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(attempt_id, question_id)
);

CREATE TABLE IF NOT EXISTS assessment_receipts (
    id TEXT PRIMARY KEY,
    attempt_id TEXT NOT NULL UNIQUE,
    receipt_code TEXT NOT NULL UNIQUE,
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS assessment_result_workflows (
    attempt_id TEXT PRIMARY KEY,
    source TEXT NOT NULL,
    state TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS files (
    id TEXT PRIMARY KEY,
    owner_user_id TEXT,
    r2_key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    mime TEXT NOT NULL,
    size INTEGER NOT NULL,
    visibility TEXT NOT NULL DEFAULT 'private',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS assessment_response_files (
    id TEXT PRIMARY KEY,
    attempt_id TEXT NOT NULL,
    source TEXT NOT NULL,
    question_id TEXT NOT NULL,
    file_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS exam_audit_log (
    id TEXT PRIMARY KEY,
    exam_id TEXT,
    attempt_id TEXT,
    actor_user_id TEXT,
    event_type TEXT NOT NULL,
    detail_json TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. DIRECT & GROUP CHAT WITH RBAC, READ RECEIPTS, BLOCK & REPORT
CREATE TABLE IF NOT EXISTS chat_rooms (
    id TEXT PRIMARY KEY,
    room_type TEXT NOT NULL CHECK (room_type IN ('direct', 'group')),
    name TEXT,
    created_by TEXT NOT NULL,
    is_private INTEGER NOT NULL DEFAULT 1 CHECK (is_private = 1),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS chat_room_members (
    room_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'moderator', 'member')),
    last_read_message_id TEXT,
    is_muted INTEGER NOT NULL DEFAULT 0,
    joined_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    PRIMARY KEY (room_id, user_id),
    FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    sender_user_id TEXT NOT NULL,
    message_text TEXT NOT NULL,
    attachment_r2_file_id TEXT,
    is_deleted INTEGER NOT NULL DEFAULT 0 CHECK (is_deleted IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
    FOREIGN KEY (sender_user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (attachment_r2_file_id) REFERENCES r2_files(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS chat_blocks_reports (
    id TEXT PRIMARY KEY,
    reporter_user_id TEXT NOT NULL,
    target_user_id TEXT NOT NULL,
    action_type TEXT NOT NULL CHECK (action_type IN ('block', 'report')),
    reason TEXT,
    reported_message_id TEXT,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'resolved', 'dismissed')),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- 9. NOTIFICATIONS, SUPPORT TICKETS, EMAIL DISPATCH LOGS & SECURITY AUDIT LOGS
CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
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
    id TEXT PRIMARY KEY,
    ticket_code TEXT NOT NULL UNIQUE,
    user_id TEXT,
    sender_name TEXT NOT NULL,
    sender_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'general',
    message TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved', 'closed')),
    assigned_to TEXT,
    resolution_note TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS email_dispatch_logs (
    id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'account_request_received',
        'account_request_supplement',
        'account_request_approved',
        'account_request_rejected',
        'account_activated',
        'account_request_status_update',
        'password_reset',
        'research_notification',
        'project_notification',
        'assessment_notification',
        'task_assignment',
        'support_ticket_received',
        'security_alert'
    )),
    recipient_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    reference_code TEXT,
    delivery_status TEXT NOT NULL CHECK (delivery_status IN ('queued', 'sent', 'failed', 'blocked_by_env', 'pending_smtp_config')),
    provider_response TEXT,
    contains_sensitive_id INTEGER NOT NULL DEFAULT 0 CHECK (contains_sensitive_id = 0),
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY,
    actor_user_id TEXT,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    ip_address TEXT,
    user_agent TEXT,
    details_sanitized TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

-- ============================================================================
-- INITIAL SEED DATA (VALID DEFAULT CONFIGURATION ONLY)
-- Zero fabricated achievements, zero fake users/requests/emails/partners
-- Public support email strictly: support@skyfirst.io.vn
-- ============================================================================

INSERT OR IGNORE INTO system_config (config_key, config_value, is_public) VALUES
('site_name_vi', 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 1),
('site_name_en', 'Sky First Center for Research and Development', 1),
('site_domain', 'https://scrd.skyfirst.io.vn', 1),
('exam_portal_url', 'https://exam.skyfirst.io.vn', 1),
('support_email', 'support@skyfirst.io.vn', 1),
('hero_eyebrow_vi', 'TRUNG TÂM NGHIÊN CỨU VÀ PHÁT TRIỂN CỘNG ĐỒNG SKY FIRST', 1),
('hero_eyebrow_en', 'SKY FIRST CENTER FOR RESEARCH AND DEVELOPMENT', 1),
('hero_title_vi', 'NGHIÊN CỨU KHOA HỌC & PHÁT TRIỂN CỘNG ĐỒNG', 1),
('hero_title_en', 'SCIENTIFIC RESEARCH & COMMUNITY DEVELOPMENT', 1),
('hero_subtitle_vi', 'Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững.', 1),
('hero_subtitle_en', 'Connecting academic knowledge, standardized assessment, and sustainable community initiatives.', 1),
('hero_description_vi', 'Nền tảng chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 1),
('hero_description_en', 'The official platform of Sky First Center for Research and Development.', 1),
('hero_cta_primary_vi', 'Khám phá Lĩnh vực Hoạt động', 1),
('hero_cta_primary_en', 'Explore Core Areas', 1),
('hero_cta_secondary_vi', 'Yêu cầu Cấp Tài khoản', 1),
('hero_cta_secondary_en', 'Request Center Account', 1),
('cooperation_status_note_vi', 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First luôn mở rộng mạng lưới hợp tác học thuật và phát triển cộng đồng. Danh sách đối tác chỉ được công bố sau khi hoàn tất văn bản xác nhận chính thức theo quy chuẩn minh bạch của Trung tâm.', 1),
('cooperation_status_note_en', 'Sky First Center for Research and Development continuously expands its academic and community collaboration network. Partner listings are published only after formal verification under our transparency standards.', 1),
('copyright_vi', '© Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 1),
('copyright_en', '© Sky First Center for Research and Development.', 1);

-- 8 Main Public Menu Items (Section III.4)
INSERT OR IGNORE INTO cms_menus (id, menu_location, parent_id, label_vi, label_en, target_url, link_type, sort_order, is_visible) VALUES
('menu_main_1', 'main_header', NULL, 'Trang chủ', 'Home', '/', 'internal', 1, 1),
('menu_main_2', 'main_header', NULL, 'Giới thiệu', 'About Us', '/gioi-thieu', 'internal', 2, 1),
('menu_main_3', 'main_header', NULL, 'Nghiên cứu khoa học', 'Scientific Research', '/nghien-cuu-khoa-hoc', 'internal', 3, 1),
('menu_main_4', 'main_header', NULL, 'Dự án cộng đồng', 'Community Projects', '/du-an-cong-dong', 'internal', 4, 1),
('menu_main_5', 'main_header', NULL, 'Khảo thí và Đánh giá học thuật', 'Academic Assessment', '/khao-thi-danh-gia', 'internal', 5, 1),
('menu_main_6', 'main_header', NULL, 'Công bố và Tài liệu', 'Publications & Documents', '/cong-bo-tai-lieu', 'internal', 6, 1),
('menu_main_7', 'main_header', NULL, 'Hợp tác và Đối tác', 'Cooperation & Partners', '/hop-tac-doi-tac', 'internal', 7, 1),
('menu_main_8', 'main_header', NULL, 'Tin tức và Hoạt động', 'News & Activities', '/tin-tuc-hoat-dong', 'internal', 8, 1),

-- Utility Header Navigation (Non-technical, public account actions only)
('menu_util_1', 'utility_header', NULL, 'Tra cứu yêu cầu', 'Track Request', '/tra-cuu', 'internal', 1, 1),
('menu_util_2', 'utility_header', NULL, 'Yêu cầu cấp tài khoản', 'Request Account', '/dang-ky', 'cta', 2, 1),
('menu_util_3', 'utility_header', NULL, 'Quên mật khẩu', 'Forgot Password', '/quen-mat-khau', 'internal', 3, 1),
('menu_util_4', 'utility_header', NULL, 'Đăng nhập', 'Sign In', '/dang-nhap', 'cta', 4, 1),

-- Footer Column 2 — Về Trung tâm (Section III.5)
('menu_f2_1', 'footer_col_2', NULL, 'Giới thiệu Trung tâm', 'Center Overview', '/gioi-thieu?section=tong-quan', 'internal', 1, 1),
('menu_f2_2', 'footer_col_2', NULL, 'Sứ mệnh và tầm nhìn', 'Mission & Vision', '/gioi-thieu?section=su-menh-tam-nhin', 'internal', 2, 1),
('menu_f2_3', 'footer_col_2', NULL, 'Cơ cấu tổ chức', 'Organizational Structure', '/gioi-thieu?section=co-cau-to-chuc', 'internal', 3, 1),
('menu_f2_4', 'footer_col_2', NULL, 'Lĩnh vực hoạt động', 'Core Areas of Activity', '/gioi-thieu?section=linh-vuc-hoat-dong', 'internal', 4, 1),
('menu_f2_5', 'footer_col_2', NULL, 'Liên hệ', 'Contact Us', '/gioi-thieu?section=lien-he', 'internal', 5, 1),

-- Footer Column 3 — Kết nối Sky First (Section III.5 — verified internal/domain links, editable in CMS)
('menu_f3_1', 'footer_col_3', NULL, 'Trang Thông Tin Sky First', 'Sky First Information Page', 'https://scrd.skyfirst.io.vn/gioi-thieu', 'internal', 1, 1),
('menu_f3_2', 'footer_col_3', NULL, 'Cổng Thông Tin Số Sky First', 'Sky First Digital Portal', 'https://scrd.skyfirst.io.vn', 'internal', 2, 1),
('menu_f3_3', 'footer_col_3', NULL, 'Trung Tâm TNV Sky First', 'Sky First Volunteer Center', '/du-an-cong-dong', 'internal', 3, 1),
('menu_f3_4', 'footer_col_3', NULL, 'Fanpage Sky First', 'Sky First Official Fanpage', '/gioi-thieu?section=lien-he', 'internal', 4, 1),
('menu_f3_5', 'footer_col_3', NULL, 'Zalo/Hotline', 'Zalo / Support Hotline', 'mailto:support@skyfirst.io.vn', 'external', 5, 1),

-- Footer Column 4 — Tài khoản Trung tâm (Section III.5)
('menu_f4_1', 'footer_col_4', NULL, 'Đăng nhập', 'Sign In', '/dang-nhap', 'internal', 1, 1),
('menu_f4_2', 'footer_col_4', NULL, 'Tra cứu yêu cầu', 'Track Request', '/tra-cuu', 'internal', 2, 1),
('menu_f4_3', 'footer_col_4', NULL, 'Yêu cầu cấp tài khoản', 'Request Account', '/dang-ky', 'internal', 3, 1),
('menu_f4_4', 'footer_col_4', NULL, 'Quên mật khẩu', 'Forgot Password', '/quen-mat-khau', 'internal', 4, 1),
('menu_f4_5', 'footer_col_4', NULL, 'Hướng dẫn sử dụng', 'User Guide', '/gioi-thieu?section=huong-dan-su-dung', 'internal', 5, 1),

-- Footer Bottom Policy Links (Section III.5)
('menu_fb_1', 'footer_bottom', NULL, 'Bảo vệ dữ liệu cá nhân', 'Personal Data Protection', '/gioi-thieu?section=chinh-sach-bao-ve-du-lieu', 'internal', 1, 1),
('menu_fb_2', 'footer_bottom', NULL, 'Điều khoản sử dụng', 'Terms of Use', '/gioi-thieu?section=dieu-khoan-su-dung', 'internal', 2, 1),
('menu_fb_3', 'footer_bottom', NULL, 'Hỗ trợ người dùng', 'User Support', '/gioi-thieu?section=ho-tro-nguoi-dung', 'internal', 3, 1);

-- Default Redirects for Legacy Paths
INSERT OR IGNORE INTO cms_redirects (id, old_path, new_path, status_code, is_active) VALUES
('red_1', '/yeu-cau-cap-tai-khoan', '/dang-ky', 301, 1),
('red_2', '/tra-cuu-yeu-cau', '/tra-cuu', 301, 1);

-- 9 Official Public Introduction, Policy & Support Pages (Strictly support@skyfirst.io.vn)
INSERT OR IGNORE INTO cms_pages (id, slug, title_vi, title_en, summary_vi, summary_en, content_vi, content_en, page_group, seo_title_vi, seo_description_vi, sort_order, status, published_at) VALUES
('page_1', 'tong-quan', 'Giới thiệu Trung tâm', 'Center Overview',
 'Giới thiệu chung về Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
 'General overview of Sky First Center for Research and Development.',
 '<p><strong>Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First</strong> (tên tiếng Anh: <em>Sky First Center for Research and Development</em>) là tổ chức hoạt động trong lĩnh vực nghiên cứu khoa học ứng dụng, phát triển các sáng kiến cộng đồng, khảo thí học thuật và phổ biến tri thức.</p><p>Trung tâm vận hành trên nguyên tắc minh bạch, chuẩn mực học thuật, bảo mật dữ liệu và lấy sự phát triển bền vững của cộng đồng làm trọng tâm.</p>',
 '<p><strong>Sky First Center for Research and Development</strong> operates in applied scientific research, community development initiatives, academic assessment, and knowledge dissemination.</p><p>The Center operates on the principles of transparency, academic rigor, data privacy, and sustainable community advancement.</p>',
 'about', 'Giới thiệu Trung tâm | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Tổng quan chính thức về Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 1, 'published', '2026-10-01T08:00:00Z'),

('page_2', 'su-menh-tam-nhin', 'Sứ mệnh và tầm nhìn', 'Mission and Vision',
 'Định hướng chiến lược và giá trị cốt lõi của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
 'Strategic direction and core values of Sky First Center for Research and Development.',
 '<h3>Sứ mệnh</h3><p>Kết nối tri thức khoa học với thực tiễn đời sống thông qua các chương trình nghiên cứu nghiêm túc, các dự án cộng đồng thiết thực và hệ thống đánh giá học thuật công bằng, bảo mật.</p><h3>Tầm nhìn</h3><p>Xây dựng hệ sinh thái nghiên cứu và phát triển cộng đồng hiện đại, chuẩn hóa quy trình số hóa và đóng góp tích cực vào sự phát triển năng lực học thuật của xã hội.</p>',
 '<h3>Mission</h3><p>Bridging scientific knowledge and real-world practice through rigorous research programs, practical community projects, and a fair, secure academic assessment system.</p><h3>Vision</h3><p>Building a modern community research and development ecosystem with standardized digital workflows that positively contribute to societal academic capacity.</p>',
 'about', 'Sứ mệnh và tầm nhìn | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Sứ mệnh, tầm nhìn và giá trị cốt lõi của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 2, 'published', '2026-10-01T08:00:00Z'),

('page_3', 'co-cau-to-chuc', 'Cơ cấu tổ chức', 'Organizational Structure',
 'Mô hình quản trị và các khối chuyên môn trực thuộc Trung tâm.',
 'Governance model and specialized divisions of the Center.',
 '<p>Cơ cấu tổ chức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First được thiết kế theo mô hình phối hợp chuyên môn chặt chẽ gồm các khối chức năng:</p><ul><li><strong>Ban Điều hành Trung tâm:</strong> Định hướng chiến lược, phê duyệt chương trình và giám sát tuân thủ quy chuẩn.</li><li><strong>Khối Nghiên cứu Khoa học:</strong> Tổ chức, thẩm định và triển khai các đề tài nghiên cứu, công bố khoa học.</li><li><strong>Khối Dự án Cộng đồng:</strong> Lập kế hoạch, điều phối hoạt động thực địa và theo dõi minh chứng tiến độ dự án.</li><li><strong>Khối Khảo thí và Đánh giá Học thuật:</strong> Xây dựng ngân hàng đánh giá, tổ chức khảo thí bảo mật và quản lý kết quả học thuật.</li><li><strong>Khối Công nghệ và Quản trị Dữ liệu:</strong> Vận hành hạ tầng kỹ thuật số, bảo vệ dữ liệu cá nhân và hỗ trợ kỹ thuật.</li></ul><p><em>Lưu ý: Danh sách nhân sự cụ thể chỉ được hiển thị khi có quyết định công bố chính thức và sự đồng ý của cá nhân theo chính sách bảo vệ dữ liệu.</em></p>',
 '<p>The organizational structure of Sky First Center for Research and Development is structured around specialized functional divisions:</p><ul><li><strong>Executive Board:</strong> Strategic direction, program approval, and compliance oversight.</li><li><strong>Scientific Research Division:</strong> Managing, reviewing, and executing research topics and publications.</li><li><strong>Community Projects Division:</strong> Planning, coordinating field activities, and verifying project milestones.</li><li><strong>Academic Assessment Division:</strong> Developing assessment frameworks, managing secure testing, and protecting academic records.</li><li><strong>Technology & Data Governance Division:</strong> Operating digital infrastructure, personal data protection, and technical support.</li></ul>',
 'about', 'Cơ cấu tổ chức | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Cơ cấu tổ chức và các khối chuyên môn của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 3, 'published', '2026-10-01T08:00:00Z'),

('page_4', 'linh-vuc-hoat-dong', 'Lĩnh vực hoạt động', 'Core Areas of Activity',
 'Bốn trụ cột hoạt động trọng tâm của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
 'Four core pillars of activity at Sky First Center for Research and Development.',
 '<ul><li><strong>1. Nghiên cứu Khoa học và Ứng dụng:</strong> Thực hiện các đề tài nghiên cứu liên ngành, phương pháp giáo dục, công nghệ số và phát triển bền vững.</li><li><strong>2. Dự án Phát triển Cộng đồng:</strong> Triển khai các chương trình nâng cao năng lực, hỗ trợ kỹ năng và phát triển cộng đồng có theo dõi minh chứng rõ ràng.</li><li><strong>3. Khảo thí và Đánh giá Học thuật:</strong> Tổ chức đánh giá năng lực học thuật với cơ chế phân quyền nghiêm ngặt, bảo vệ tuyệt đối đề thi và kết quả cá nhân qua cổng khảo thí <code>https://exam.skyfirst.io.vn</code>.</li><li><strong>4. Công bố Khoa học và Thư viện Tài liệu:</strong> Xây dựng kho tài liệu chuẩn hóa, hướng dẫn học thuật và ấn phẩm phục vụ cộng đồng theo phân quyền truy cập.</li></ul>',
 '<ul><li><strong>1. Scientific & Applied Research:</strong> Conducting interdisciplinary studies in education methodology, digital technology, and sustainable development.</li><li><strong>2. Community Development Projects:</strong> Implementing capacity-building and community support programs with verified milestone tracking.</li><li><strong>3. Academic Assessment & Testing:</strong> Organizing academic evaluations with strict access control via <code>https://exam.skyfirst.io.vn</code>, protecting exam content and individual results.</li><li><strong>4. Publications & Document Library:</strong> Maintaining a standardized repository of academic guides, methodological reports, and public/restricted documents.</li></ul>',
 'about', 'Lĩnh vực hoạt động | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Các lĩnh vực hoạt động chính của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 4, 'published', '2026-10-01T08:00:00Z'),

('page_5', 'lien-he', 'Liên hệ', 'Contact Us',
 'Kênh thông tin liên hệ chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
 'Official contact channels of Sky First Center for Research and Development.',
 '<p>Mọi yêu cầu trao đổi học thuật, hợp tác dự án hoặc hỗ trợ người dùng, quý vị vui lòng liên hệ qua kênh chính thức dưới đây:</p><ul><li><strong>Đơn vị:</strong> Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First (Sky First Center for Research and Development)</li><li><strong>Cổng thông tin điện tử:</strong> <a href="https://scrd.skyfirst.io.vn">https://scrd.skyfirst.io.vn</a></li><li><strong>Cổng khảo thí học thuật:</strong> <a href="https://exam.skyfirst.io.vn">https://exam.skyfirst.io.vn</a></li><li><strong>Email hỗ trợ công khai:</strong> <a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a></li></ul>',
 '<p>For academic inquiries, project partnerships, or user support, please contact us through our official channels:</p><ul><li><strong>Organization:</strong> Sky First Center for Research and Development</li><li><strong>Official Portal:</strong> <a href="https://scrd.skyfirst.io.vn">https://scrd.skyfirst.io.vn</a></li><li><strong>Academic Assessment Portal:</strong> <a href="https://exam.skyfirst.io.vn">https://exam.skyfirst.io.vn</a></li><li><strong>Public Support Email:</strong> <a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a></li></ul>',
 'support', 'Liên hệ | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Thông tin liên hệ chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 5, 'published', '2026-10-01T08:00:00Z'),

('page_6', 'chinh-sach-bao-ve-du-lieu', 'Bảo vệ dữ liệu cá nhân', 'Personal Data Protection Policy',
 'Quy định thu thập, xử lý, mã hóa và bảo vệ dữ liệu cá nhân tại Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.',
 'Regulations on collecting, processing, encrypting, and protecting personal data at Sky First Center for Research and Development.',
 '<h3>1. Nguyên tắc thu thập và tối thiểu hóa dữ liệu</h3><p>Trung tâm chỉ thu thập các thông tin cần thiết phục vụ xác minh danh tính, xét duyệt tài khoản, quản lý nghiên cứu, dự án và khảo thí học thuật theo sự đồng ý rõ ràng của chủ thể dữ liệu.</p><h3>2. Bảo vệ thông tin định danh và người chưa thành niên</h3><p>Số giấy tờ định danh (CCCD/Hộ chiếu) được mã hóa ứng dụng bằng khóa bí mật phía máy chủ và hình ảnh giấy tờ được lưu trữ phân quyền riêng tư; tuyệt đối không đính kèm hoặc hiển thị thông tin nhạy cảm trong email thông báo hay trang tra cứu công khai. Đối với người đăng ký dưới 18 tuổi, hệ thống bắt buộc xác nhận thông tin và sự đồng ý của người giám hộ hợp pháp.</p><h3>3. Quyền của chủ thể dữ liệu</h3><p>Người dùng có quyền tra cứu, yêu cầu cập nhật, hạn chế xử lý hoặc gửi yêu cầu hỗ trợ về dữ liệu cá nhân thông qua bộ phận Hỗ trợ tại địa chỉ <a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a>.</p>',
 '<h3>1. Data Minimization & Lawful Collection</h3><p>The Center collects only essential information required for identity verification, account approval, research management, projects, and academic assessment with explicit user consent.</p><h3>2. Protection of Identity Documents & Minors</h3><p>Identity numbers are encrypted at the application layer with server-side secrets and document scans are strictly access-controlled in private storage, never exposed in automated emails or public lookup endpoints. For applicants under 18, legal guardian details and explicit consent are mandatory.</p><h3>3. Data Subject Rights</h3><p>Users have the right to inspect, update, or request assistance regarding their personal data via <a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a>.</p>',
 'policy', 'Bảo vệ dữ liệu cá nhân | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Chính sách bảo vệ dữ liệu cá nhân của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 6, 'published', '2026-10-01T08:00:00Z'),

('page_7', 'dieu-khoan-su-dung', 'Điều khoản sử dụng', 'Terms of Use',
 'Quy định về quyền, nghĩa vụ và chuẩn mực sử dụng hệ thống thông tin của Trung tâm.',
 'Rules on rights, obligations, and acceptable use of the Center information system.',
 '<h3>1. Phạm vi áp dụng</h3><p>Điều khoản này áp dụng cho toàn bộ người truy cập website công khai, người gửi yêu cầu cấp tài khoản và thành viên sử dụng bảng điều khiển nội bộ của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.</p><h3>2. Trách nhiệm bảo mật tài khoản và liêm chính học thuật</h3><p>Thành viên chịu trách nhiệm bảo mật thông tin đăng nhập, tuân thủ quy định phân quyền truy cập tài liệu, đề thi khảo thí và dữ liệu dự án. Nghiêm cấm mọi hành vi can thiệp trái phép vào API, phát tán mã độc hoặc giả mạo thông tin định danh.</p>',
 '<h3>1. Scope of Application</h3><p>These terms apply to all visitors of the public website, account applicants, and members using the internal dashboard of Sky First Center for Research and Development.</p><h3>2. Account Security & Academic Integrity</h3><p>Members are responsible for safeguarding credentials and respecting access controls for documents, assessments, and project records. Unauthorized API manipulation or identity falsification is strictly prohibited.</p>',
 'policy', 'Điều khoản sử dụng | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Điều khoản sử dụng hệ thống Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 7, 'published', '2026-10-01T08:00:00Z'),

('page_8', 'huong-dan-su-dung', 'Hướng dẫn sử dụng', 'User Guide',
 'Hướng dẫn quy trình 5 bước đăng ký tài khoản, tra cứu mã yêu cầu và sử dụng hệ thống.',
 'Step-by-step guide on the 5-step account registration, request code lookup, and system usage.',
 '<h3>1. Quy trình đăng ký cấp tài khoản (5 bước)</h3><ol><li><strong>Bước 1 - Thông tin cá nhân:</strong> Nhập họ tên, ngày sinh, giới tính Nam/Nữ, email, số điện thoại và thông tin người giám hộ (bắt buộc nếu dưới 18 tuổi).</li><li><strong>Bước 2 - Học tập và công tác:</strong> Khai báo nhóm đối tượng, trình độ học vấn, trường/đơn vị, lớp/khoa/chuyên ngành/chức vụ tương ứng.</li><li><strong>Bước 3 - Thông tin định danh:</strong> Cung cấp thông tin giấy tờ định danh (CCCD 12 số/Hộ chiếu), ngày cấp, nơi cấp và tải tệp ảnh giấy tờ bảo mật trực tiếp từ thiết bị.</li><li><strong>Bước 4 - Mục đích và thông tin bổ sung:</strong> Chọn nhóm quyền dự kiến, lĩnh vực nghiên cứu/dự án quan tâm, kinh nghiệm và tài liệu bổ sung.</li><li><strong>Bước 5 - Xác nhận và gửi hồ sơ:</strong> Kiểm tra lại thông tin, ký xác nhận, đồng ý chính sách và nhận mã tra cứu định dạng <code>SCRD-SFN-XXXXXXXXXX</code> sau khi hệ thống lưu thành công.</li></ol><h3>2. Tra cứu trạng thái hồ sơ</h3><p>Sử dụng trang <a href="/tra-cuu">Tra cứu yêu cầu</a> với Mã yêu cầu và Email đăng ký để theo dõi tiến độ xét duyệt an toàn.</p>',
 '<h3>1. 5-Step Account Registration</h3><ol><li><strong>Step 1 - Personal Details:</strong> Full name, DOB, gender, contact details, and guardian info (mandatory if under 18).</li><li><strong>Step 2 - Education & Work:</strong> Applicant group, academic background, institution, and conditional role details.</li><li><strong>Step 3 - Identity Verification:</strong> Protected ID information and direct document file uploads (encrypted and private).</li><li><strong>Step 4 - Purpose & Supplemental Info:</strong> Expected group, research/project interests, experience, and supporting files.</li><li><strong>Step 5 - Review & Confirmation:</strong> Policy consent, signature, and generation of unique <code>SCRD-SFN-XXXXXXXXXX</code> tracking code after database confirmation.</li></ol><h3>2. Status Lookup</h3><p>Use the <a href="/tra-cuu">Track Request</a> page with your Request Code and Email to check your application status.</p>',
 'support', 'Hướng dẫn sử dụng | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Hướng dẫn sử dụng cổng thông tin Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 8, 'published', '2026-10-01T08:00:00Z'),

('page_9', 'ho-tro-nguoi-dung', 'Hỗ trợ người dùng', 'User Support',
 'Trung tâm tiếp nhận yêu cầu hỗ trợ kỹ thuật, bổ sung hồ sơ và giải đáp thắc mắc.',
 'Support center for technical assistance, application supplementation, and inquiries.',
 '<p>Nếu quý vị cần hỗ trợ trong quá trình đăng ký tài khoản, tra cứu mã yêu cầu, tải tài liệu hoặc tham gia khảo thí học thuật, vui lòng gửi phiếu hỗ trợ trực tiếp hoặc liên hệ qua email chính thức:</p><ul><li><strong>Email hỗ trợ công khai:</strong> <a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a></li></ul>',
 '<p>If you need assistance with account registration, request code lookup, document downloads, or academic assessments, please submit a support ticket or email our official support channel:</p><ul><li><strong>Official Support Email:</strong> <a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a></li></ul>',
 'support', 'Hỗ trợ người dùng | Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First', 'Cổng hỗ trợ người dùng Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 9, 'published', '2026-10-01T08:00:00Z');

-- No news posts are seeded. The public news page remains empty until an editor publishes verified content.


-- Keep footer connections limited to known official channels. Apply these rows to both clean installs and subsequent migrations.
UPDATE cms_menus SET label_vi='Email hỗ trợ', label_en='Support email', target_url='mailto:support@skyfirst.io.vn', link_type='external', sort_order=1, is_visible=1 WHERE id='menu_f3_1';
UPDATE cms_menus SET label_vi='Website Sky First', label_en='Sky First website', target_url='https://www.skyfirst.io.vn', link_type='external', sort_order=2, is_visible=1 WHERE id='menu_f3_2';
UPDATE cms_menus SET label_vi='Facebook Sky First Network', label_en='Sky First Network on Facebook', target_url='https://fb.com/skyfirstnetwork', link_type='external', sort_order=3, is_visible=1 WHERE id='menu_f3_3';
DELETE FROM cms_menus WHERE id IN ('menu_f3_4','menu_f3_5');

-- Canonical information-security policy page; explanatory only, not a legal guarantee.
INSERT OR IGNORE INTO cms_pages
(id,slug,title_vi,title_en,summary_vi,summary_en,content_vi,content_en,page_group,seo_title_vi,seo_title_en,seo_description_vi,seo_description_en,sort_order,status,version,published_at,created_at,updated_at)
VALUES
('page_10','an-toan-thong-tin','An toàn thông tin','Information Security','Nguyên tắc bảo vệ tài khoản, dữ liệu và tài liệu trên hệ thống của Trung tâm.','Principles for protecting accounts, data and documents on the Center’s systems.','<h2>Nguyên tắc an toàn thông tin</h2><p>Trung tâm áp dụng phân quyền truy cập, kiểm soát phiên và biện pháp bảo vệ phù hợp đối với dữ liệu và tài liệu trên hệ thống. Người dùng cần bảo vệ thông tin đăng nhập, không chia sẻ mã xác thực, đăng xuất khi sử dụng thiết bị dùng chung và báo cáo kịp thời dấu hiệu truy cập bất thường.</p><p>Quyền truy cập được cấp theo nhiệm vụ và có thể được điều chỉnh khi thay đổi vai trò. Không gửi giấy tờ định danh hoặc dữ liệu cá nhân nhạy cảm qua kênh chưa được Trung tâm xác nhận.</p><p>Khi phát hiện sự cố, vui lòng liên hệ <a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a>. Nội dung này mô tả nguyên tắc vận hành và không thay thế các chính sách hoặc quy định pháp luật áp dụng.</p>','<h2>Information security principles</h2><p>The Center applies access control, session safeguards and appropriate protections for system data and documents. Users should protect their sign-in information, never share verification codes, sign out on shared devices and promptly report suspected unauthorized access.</p><p>Access is granted according to responsibilities and may change when a role changes. Do not send identity documents or sensitive personal data through channels that the Center has not verified.</p><p>To report an incident, contact <a href="mailto:support@skyfirst.io.vn">support@skyfirst.io.vn</a>. This page describes operational principles and does not replace applicable policies or legal requirements.</p>','policy','An toàn thông tin | Sky First','Information Security | Sky First','Nguyên tắc bảo vệ tài khoản, dữ liệu và tài liệu của Trung tâm.','Principles for protecting accounts, data and Center documents.',10,'published',1,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP);

-- BEGIN AUTO-APPLIED 0003_home_about_longform.sql
-- 0003: Expand the homepage and Center Overview in both Vietnamese and English.
-- This migration uses descriptive, non-promotional content and does not invent partners, numbers, awards, or outcomes.
UPDATE cms_pages
SET title_vi='Giới thiệu Trung tâm', title_en='About the Center',
    summary_vi='Thông tin tổng quan về phạm vi hoạt động, nguyên tắc chuyên môn, cách tổ chức công việc và trách nhiệm của Trung tâm.', summary_en='An overview of the Center’s scope, professional principles, working practices, and responsibilities.',
    content_vi='<section class="longform-section" id="gioi-thieu-1"><h2>1. Bản sắc và phạm vi hoạt động</h2>
<p>Phần này tập trung vào bản sắc và phạm vi hoạt động. Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First là tên gọi được sử dụng cho cổng thông tin chuyên môn này. Phạm vi nội dung tập trung vào nghiên cứu khoa học ứng dụng, phát triển cộng đồng, khảo thí và đánh giá học thuật, cùng việc công bố và tổ chức tài liệu phục vụ tri thức. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Trước khi triển khai nội dung về bản sắc và phạm vi hoạt động, nhóm cần xác định ai chịu ảnh hưởng, câu hỏi cần trả lời và điều kiện nào có thể làm thay đổi cách tiếp cận. Phạm vi được ghi rõ giúp tránh mở rộng yêu cầu ngoài nguồn lực hoặc bằng chứng sẵn có.</p>
<p>Phương pháp cho bản sắc và phạm vi hoạt động cần mô tả cách lựa chọn dữ liệu, tiêu chí đưa vào hoặc loại trừ, công cụ sử dụng và cách ghi nhận thay đổi. Người đọc phải phân biệt được quy trình đã thực hiện với phương án mới chỉ được đề xuất.</p>
<p>Trong quá trình thực hiện bản sắc và phạm vi hoạt động, thông tin cập nhật cần phản ánh đúng tiến độ và những việc còn phụ thuộc. Khi có thay đổi về lịch, nhân sự hoặc phạm vi, người phụ trách nên ghi lại quyết định và thông báo cho các bên bị ảnh hưởng bằng kênh phù hợp.</p>
<p>Đánh giá bản sắc và phạm vi hoạt động cần dựa trên bằng chứng tương ứng với tuyên bố được đưa ra. Báo cáo nên phân biệt đầu ra đã hoàn thành, thay đổi quan sát được và tác động chưa đủ dữ liệu để kết luận; không suy diễn quan hệ nhân quả chỉ từ việc hai sự kiện xảy ra cùng lúc.</p>
</section>
<section class="longform-section" id="gioi-thieu-2"><h2>2. Sứ mệnh</h2>
<p>Phần này tập trung vào sứ mệnh. Sứ mệnh được thể hiện qua việc kết nối câu hỏi nghiên cứu với nhu cầu thực tế, xây dựng hoạt động cộng đồng có mục tiêu và tổ chức đánh giá học thuật theo quy trình rõ ràng. Một tuyên bố sứ mệnh chỉ có ý nghĩa khi được chuyển thành quyết định và thực hành có thể quan sát, kiểm tra và cải thiện. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khâu chuẩn bị nên tách nhu cầu đã được ghi nhận khỏi giả định ban đầu. Với sứ mệnh, mỗi giả định quan trọng cần có cách kiểm tra, người chịu trách nhiệm và mốc xem xét; nếu chưa thể kiểm chứng, tài liệu phải nêu rõ giới hạn thay vì biến dự đoán thành kết luận.</p>
<p>Khi thiết kế quy trình về sứ mệnh, cần phân công vai trò, điểm kiểm tra chất lượng và cách xử lý sai lệch. Một quy trình có thể giải thích được quan trọng hơn một danh sách bước dài; mỗi bước nên có mục đích, đầu vào và đầu ra rõ ràng.</p>
<p>Hoạt động liên quan đến sứ mệnh cần tôn trọng quyền tham gia và quyền từ chối của mỗi người. Hướng dẫn nên nêu rõ việc gì sẽ diễn ra, ai có thể xem dữ liệu, cách đặt câu hỏi và nơi tiếp nhận phản ánh nếu người tham gia thấy không an toàn hoặc chưa hiểu.</p>
<p>Khi tổng kết sứ mệnh, cần công bố phạm vi dữ liệu, thời điểm cập nhật, giới hạn đo lường và những câu hỏi còn bỏ ngỏ. Một kết quả chưa như kỳ vọng vẫn có thể đem lại bài học nếu phương pháp, sai lệch và điều kiện thực hiện được mô tả trung thực.</p>
</section>
<section class="longform-section" id="gioi-thieu-3"><h2>3. Tầm nhìn và nguyên tắc</h2>
<p>Phần này tập trung vào tầm nhìn và nguyên tắc. Tầm nhìn định hướng dài hạn nhưng không thay thế kế hoạch cụ thể hoặc bằng chứng về kết quả. Các nguyên tắc nền tảng gồm minh bạch, trách nhiệm học thuật, tôn trọng con người, sử dụng nguồn lực hợp lý, bảo vệ dữ liệu và sẵn sàng điều chỉnh khi đánh giá cho thấy cách làm hiện tại chưa phù hợp. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khi xem xét tầm nhìn và nguyên tắc, nên lập danh sách bên liên quan, rào cản tham gia, điều kiện tiếp cận và nguồn thông tin hợp pháp. Cách xác định phạm vi này giúp nhóm lựa chọn hoạt động phù hợp, đồng thời tránh yêu cầu người tham gia cung cấp thông tin vượt quá mục đích.</p>
<p>Các tiêu chí đánh giá tầm nhìn và nguyên tắc nên được xác định trước khi xem kết quả để hạn chế lựa chọn tiêu chí có lợi sau khi đã biết dữ liệu. Nếu tiêu chí phải thay đổi, nhóm cần ghi lý do, thời điểm và ảnh hưởng của thay đổi đối với kết luận.</p>
<p>Để duy trì chất lượng của tầm nhìn và nguyên tắc, nhóm cần lưu bằng chứng đủ dùng, cập nhật trạng thái có ngày tháng và tránh biến số liệu tạm thời thành kết quả cuối. Tài liệu nội bộ và nội dung công khai phải được phân biệt để không làm lộ thông tin cần bảo vệ.</p>
<p>Các chỉ số liên quan đến tầm nhìn và nguyên tắc chỉ có ý nghĩa khi có định nghĩa, nguồn và thời điểm đo nhất quán. Nếu chưa có số liệu đáng tin cậy, nên ghi rõ chưa có dữ liệu xác minh thay vì ước lượng để lấp chỗ trống hoặc tạo cảm giác chắc chắn.</p>
</section>
<section class="longform-section" id="gioi-thieu-4"><h2>4. Nghiên cứu và kiểm chứng</h2>
<p>Phần này tập trung vào nghiên cứu và kiểm chứng. Hoạt động nghiên cứu cần có câu hỏi, phạm vi, phương pháp, tiêu chí phân tích và giới hạn được nêu rõ. Việc kiểm chứng không đồng nghĩa với việc mọi kết quả đều chắc chắn; đó là quá trình cho phép người khác đánh giá bằng chứng, nhận diện sai số và xem xét cách diễn giải. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Một câu hỏi tốt về nghiên cứu và kiểm chứng cần đủ cụ thể để hướng dẫn hành động nhưng đủ mở để tiếp nhận bằng chứng trái với kỳ vọng. Nhóm nên xác định điều gì nằm trong phạm vi, điều gì chưa thể trả lời và trường hợp nào cần chuyển sang đánh giá chuyên môn khác.</p>
<p>Tài liệu hóa phương pháp liên quan đến nghiên cứu và kiểm chứng giúp người khác kiểm tra logic của quyết định mà không cần suy đoán. Cần ghi nguồn, phiên bản công cụ, điều kiện thực hiện và các ngoại lệ quan trọng; không được mô tả một quy trình lý tưởng như thể nó đã diễn ra.</p>
<p>Phối hợp trong nghiên cứu và kiểm chứng nên có đầu mối chịu trách nhiệm, quy tắc chuyển giao và cách xử lý khi người phụ trách vắng mặt. Việc bàn giao cần giữ được bối cảnh quyết định, hạn chế phụ thuộc vào trí nhớ cá nhân và không chia sẻ quyền truy cập vượt nhu cầu công việc.</p>
<p>Bước rà soát cuối của nghiên cứu và kiểm chứng nên hỏi điều gì đã được chứng minh, điều gì chỉ là nhận định và điều gì cần kiểm tra tiếp. Kết luận cần tương xứng với bằng chứng, đồng thời chỉ ra hành động tiếp theo và người chịu trách nhiệm nếu cần cải thiện.</p>
</section>
<section class="longform-section" id="gioi-thieu-5"><h2>5. Chuẩn mực đạo đức</h2>
<p>Phần này tập trung vào chuẩn mực đạo đức. Chuẩn mực đạo đức cần được xem xét ngay từ thiết kế chương trình. Việc tham gia phải có cơ sở đồng thuận phù hợp, lợi ích và rủi ro cần được giải thích rõ, còn thông tin nhận dạng chỉ được tiếp cận bởi người có nhiệm vụ. Bất cứ ngoại lệ nào cũng cần được đánh giá theo hoàn cảnh cụ thể. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Để xác định nhu cầu liên quan đến chuẩn mực đạo đức, cần xem xét bối cảnh địa phương, năng lực thực hiện, thời gian và khả năng tiếp cận của người tham gia. Không nên suy rộng từ một phản ánh đơn lẻ; thông tin ban đầu cần được đối chiếu bằng nguồn độc lập khi phù hợp.</p>
<p>Việc lựa chọn phương pháp cho chuẩn mực đạo đức phải tương xứng với câu hỏi và năng lực thực hiện. Công cụ phức tạp không tự động tạo ra kết quả đáng tin cậy; điều quan trọng là dữ liệu phù hợp, tiêu chí nhất quán và khả năng giải thích các bước phân tích.</p>
<p>Khi có phản hồi về chuẩn mực đạo đức, nhóm cần ghi nhận nội dung, đánh giá mức độ ảnh hưởng và phản hồi trong thời hạn hợp lý. Không phải mọi đề xuất đều có thể được chấp nhận, nhưng lý do tiếp nhận hoặc từ chối nên rõ ràng và không gây bất lợi cho người góp ý.</p>
<p>Kết quả của chuẩn mực đạo đức cần được xem xét cùng các yếu tố có thể làm sai lệch như mẫu không đại diện, dữ liệu thiếu, thay đổi điều kiện hoặc phản hồi thiên lệch. Việc nêu rõ các giới hạn này giúp người đọc hiểu kết quả áp dụng đến đâu.</p>
</section>
<section class="longform-section" id="gioi-thieu-6"><h2>6. Cơ cấu trách nhiệm</h2>
<p>Phần này tập trung vào cơ cấu trách nhiệm. Một cơ cấu trách nhiệm hiệu quả xác định ai đề xuất, ai thẩm định, ai phê duyệt và ai theo dõi việc thực hiện. Chức danh không tự động tạo ra thẩm quyền không giới hạn. Quyền thao tác trên dữ liệu và hệ thống số cần được cấp theo nhiệm vụ, rà soát định kỳ và thu hồi khi không còn cần thiết. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Phạm vi của cơ cấu trách nhiệm nên được diễn đạt bằng ngôn ngữ người tham gia có thể hiểu, kèm mục tiêu và giới hạn rõ ràng. Việc thống nhất thuật ngữ ngay từ đầu giúp các nhóm phối hợp tránh hiểu khác nhau về đối tượng, kết quả mong đợi và trách nhiệm thực hiện.</p>
<p>Đối với cơ cấu trách nhiệm, nên xác định trước cách xử lý dữ liệu thiếu, câu trả lời mâu thuẫn và trường hợp ngoài dự kiến. Quy tắc xử lý cần được áp dụng nhất quán, đồng thời cho phép ghi nhận ngoại lệ có lý do thay vì âm thầm loại bỏ thông tin bất tiện.</p>
<p>Tài liệu vận hành cho cơ cấu trách nhiệm cần tính đến khả năng gián đoạn, lỗi công cụ và việc người dùng sử dụng thiết bị khác nhau. Hướng dẫn thay thế nên đủ đơn giản để tiếp tục công việc an toàn mà không làm mất dữ liệu hoặc bỏ qua các bước kiểm soát cần thiết.</p>
<p>Sau mỗi chu kỳ cơ cấu trách nhiệm, nhóm nên lưu bài học có thể áp dụng, quyết định sẽ thay đổi và vấn đề cần theo dõi ở lần tiếp theo. Cải tiến có trách nhiệm không chỉ ghi nhận điều thành công mà còn kiểm tra chi phí, tác dụng phụ và những nhóm chưa được phục vụ tốt.</p>
</section>
<section class="longform-section" id="gioi-thieu-7"><h2>7. Phối hợp chuyên môn</h2>
<p>Phần này tập trung vào phối hợp chuyên môn. Các nhóm chuyên môn cần có cách trao đổi quyết định, quản lý phiên bản và chuyển giao công việc rõ ràng. Khi nhiều nhóm cùng tham gia, phạm vi trách nhiệm và điểm phê duyệt phải được thống nhất để tránh khoảng trống hoặc trùng lặp. Tài liệu điều phối cần đủ rõ để người mới tiếp nhận có thể tiếp tục công việc. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Trước khi triển khai nội dung về phối hợp chuyên môn, nhóm cần xác định ai chịu ảnh hưởng, câu hỏi cần trả lời và điều kiện nào có thể làm thay đổi cách tiếp cận. Phạm vi được ghi rõ giúp tránh mở rộng yêu cầu ngoài nguồn lực hoặc bằng chứng sẵn có.</p>
<p>Phương pháp cho phối hợp chuyên môn cần mô tả cách lựa chọn dữ liệu, tiêu chí đưa vào hoặc loại trừ, công cụ sử dụng và cách ghi nhận thay đổi. Người đọc phải phân biệt được quy trình đã thực hiện với phương án mới chỉ được đề xuất.</p>
<p>Trong quá trình thực hiện phối hợp chuyên môn, thông tin cập nhật cần phản ánh đúng tiến độ và những việc còn phụ thuộc. Khi có thay đổi về lịch, nhân sự hoặc phạm vi, người phụ trách nên ghi lại quyết định và thông báo cho các bên bị ảnh hưởng bằng kênh phù hợp.</p>
<p>Đánh giá phối hợp chuyên môn cần dựa trên bằng chứng tương ứng với tuyên bố được đưa ra. Báo cáo nên phân biệt đầu ra đã hoàn thành, thay đổi quan sát được và tác động chưa đủ dữ liệu để kết luận; không suy diễn quan hệ nhân quả chỉ từ việc hai sự kiện xảy ra cùng lúc.</p>
</section>
<section class="longform-section" id="gioi-thieu-8"><h2>8. Quản trị chất lượng</h2>
<p>Phần này tập trung vào quản trị chất lượng. Quản trị chất lượng kết hợp tiêu chuẩn đầu vào, rà soát độc lập khi phù hợp, theo dõi lỗi và xác nhận việc sửa lỗi. Không phải mọi sản phẩm đều cần cùng một mức kiểm tra; cường độ rà soát nên tương ứng với rủi ro, tác động và mức độ nhạy cảm của dữ liệu. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khâu chuẩn bị nên tách nhu cầu đã được ghi nhận khỏi giả định ban đầu. Với quản trị chất lượng, mỗi giả định quan trọng cần có cách kiểm tra, người chịu trách nhiệm và mốc xem xét; nếu chưa thể kiểm chứng, tài liệu phải nêu rõ giới hạn thay vì biến dự đoán thành kết luận.</p>
<p>Khi thiết kế quy trình về quản trị chất lượng, cần phân công vai trò, điểm kiểm tra chất lượng và cách xử lý sai lệch. Một quy trình có thể giải thích được quan trọng hơn một danh sách bước dài; mỗi bước nên có mục đích, đầu vào và đầu ra rõ ràng.</p>
<p>Hoạt động liên quan đến quản trị chất lượng cần tôn trọng quyền tham gia và quyền từ chối của mỗi người. Hướng dẫn nên nêu rõ việc gì sẽ diễn ra, ai có thể xem dữ liệu, cách đặt câu hỏi và nơi tiếp nhận phản ánh nếu người tham gia thấy không an toàn hoặc chưa hiểu.</p>
<p>Khi tổng kết quản trị chất lượng, cần công bố phạm vi dữ liệu, thời điểm cập nhật, giới hạn đo lường và những câu hỏi còn bỏ ngỏ. Một kết quả chưa như kỳ vọng vẫn có thể đem lại bài học nếu phương pháp, sai lệch và điều kiện thực hiện được mô tả trung thực.</p>
</section>
<section class="longform-section" id="gioi-thieu-9"><h2>9. Quản lý xung đột lợi ích</h2>
<p>Phần này tập trung vào quản lý xung đột lợi ích. Xung đột lợi ích cần được nhận diện và xử lý minh bạch thay vì mặc định rằng người tham gia luôn khách quan. Khi có lợi ích cá nhân, quan hệ hoặc vai trò có thể ảnh hưởng đánh giá, cần khai báo và cân nhắc biện pháp như đổi người thẩm định, giới hạn quyền quyết định hoặc ghi nhận lý do xử lý. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khi xem xét quản lý xung đột lợi ích, nên lập danh sách bên liên quan, rào cản tham gia, điều kiện tiếp cận và nguồn thông tin hợp pháp. Cách xác định phạm vi này giúp nhóm lựa chọn hoạt động phù hợp, đồng thời tránh yêu cầu người tham gia cung cấp thông tin vượt quá mục đích.</p>
<p>Các tiêu chí đánh giá quản lý xung đột lợi ích nên được xác định trước khi xem kết quả để hạn chế lựa chọn tiêu chí có lợi sau khi đã biết dữ liệu. Nếu tiêu chí phải thay đổi, nhóm cần ghi lý do, thời điểm và ảnh hưởng của thay đổi đối với kết luận.</p>
<p>Để duy trì chất lượng của quản lý xung đột lợi ích, nhóm cần lưu bằng chứng đủ dùng, cập nhật trạng thái có ngày tháng và tránh biến số liệu tạm thời thành kết quả cuối. Tài liệu nội bộ và nội dung công khai phải được phân biệt để không làm lộ thông tin cần bảo vệ.</p>
<p>Các chỉ số liên quan đến quản lý xung đột lợi ích chỉ có ý nghĩa khi có định nghĩa, nguồn và thời điểm đo nhất quán. Nếu chưa có số liệu đáng tin cậy, nên ghi rõ chưa có dữ liệu xác minh thay vì ước lượng để lấp chỗ trống hoặc tạo cảm giác chắc chắn.</p>
</section>
<section class="longform-section" id="gioi-thieu-10"><h2>10. Nghiên cứu liên ngành</h2>
<p>Phần này tập trung vào nghiên cứu liên ngành. Các vấn đề cộng đồng thường liên quan đến giáo dục, công nghệ, môi trường, hành vi và điều kiện kinh tế xã hội. Nghiên cứu liên ngành cần làm rõ cách mỗi lĩnh vực đóng góp, dùng thuật ngữ nhất quán và tránh ghép các kết luận không tương thích chỉ để tạo ra một câu chuyện đơn giản. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Một câu hỏi tốt về nghiên cứu liên ngành cần đủ cụ thể để hướng dẫn hành động nhưng đủ mở để tiếp nhận bằng chứng trái với kỳ vọng. Nhóm nên xác định điều gì nằm trong phạm vi, điều gì chưa thể trả lời và trường hợp nào cần chuyển sang đánh giá chuyên môn khác.</p>
<p>Tài liệu hóa phương pháp liên quan đến nghiên cứu liên ngành giúp người khác kiểm tra logic của quyết định mà không cần suy đoán. Cần ghi nguồn, phiên bản công cụ, điều kiện thực hiện và các ngoại lệ quan trọng; không được mô tả một quy trình lý tưởng như thể nó đã diễn ra.</p>
<p>Phối hợp trong nghiên cứu liên ngành nên có đầu mối chịu trách nhiệm, quy tắc chuyển giao và cách xử lý khi người phụ trách vắng mặt. Việc bàn giao cần giữ được bối cảnh quyết định, hạn chế phụ thuộc vào trí nhớ cá nhân và không chia sẻ quyền truy cập vượt nhu cầu công việc.</p>
<p>Bước rà soát cuối của nghiên cứu liên ngành nên hỏi điều gì đã được chứng minh, điều gì chỉ là nhận định và điều gì cần kiểm tra tiếp. Kết luận cần tương xứng với bằng chứng, đồng thời chỉ ra hành động tiếp theo và người chịu trách nhiệm nếu cần cải thiện.</p>
</section>
<section class="longform-section" id="gioi-thieu-11"><h2>11. Tham gia của cộng đồng</h2>
<p>Phần này tập trung vào tham gia của cộng đồng. Cộng đồng không chỉ là đối tượng nhận hỗ trợ mà còn là nguồn tri thức về nhu cầu, rào cản và điều kiện địa phương. Cơ chế tham gia phù hợp có thể gồm trao đổi, khảo sát, phản hồi sau hoạt động và tham gia đánh giá. Việc tham gia cần tự nguyện, dễ tiếp cận và không tạo kỳ vọng sai lệch. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Để xác định nhu cầu liên quan đến tham gia của cộng đồng, cần xem xét bối cảnh địa phương, năng lực thực hiện, thời gian và khả năng tiếp cận của người tham gia. Không nên suy rộng từ một phản ánh đơn lẻ; thông tin ban đầu cần được đối chiếu bằng nguồn độc lập khi phù hợp.</p>
<p>Việc lựa chọn phương pháp cho tham gia của cộng đồng phải tương xứng với câu hỏi và năng lực thực hiện. Công cụ phức tạp không tự động tạo ra kết quả đáng tin cậy; điều quan trọng là dữ liệu phù hợp, tiêu chí nhất quán và khả năng giải thích các bước phân tích.</p>
<p>Khi có phản hồi về tham gia của cộng đồng, nhóm cần ghi nhận nội dung, đánh giá mức độ ảnh hưởng và phản hồi trong thời hạn hợp lý. Không phải mọi đề xuất đều có thể được chấp nhận, nhưng lý do tiếp nhận hoặc từ chối nên rõ ràng và không gây bất lợi cho người góp ý.</p>
<p>Kết quả của tham gia của cộng đồng cần được xem xét cùng các yếu tố có thể làm sai lệch như mẫu không đại diện, dữ liệu thiếu, thay đổi điều kiện hoặc phản hồi thiên lệch. Việc nêu rõ các giới hạn này giúp người đọc hiểu kết quả áp dụng đến đâu.</p>
</section>
<section class="longform-section" id="gioi-thieu-12"><h2>12. Thiết kế dự án có mục tiêu</h2>
<p>Phần này tập trung vào thiết kế dự án có mục tiêu. Mỗi dự án nên mô tả vấn đề cần giải quyết, nhóm hưởng lợi, hoạt động, nguồn lực, mốc thời gian và tiêu chí đánh giá. Các điều kiện tiên quyết cũng cần được nêu, bởi một kế hoạch có thể phụ thuộc vào địa điểm, nhân sự, sự chấp thuận hoặc tài trợ chưa được xác nhận. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Phạm vi của thiết kế dự án có mục tiêu nên được diễn đạt bằng ngôn ngữ người tham gia có thể hiểu, kèm mục tiêu và giới hạn rõ ràng. Việc thống nhất thuật ngữ ngay từ đầu giúp các nhóm phối hợp tránh hiểu khác nhau về đối tượng, kết quả mong đợi và trách nhiệm thực hiện.</p>
<p>Đối với thiết kế dự án có mục tiêu, nên xác định trước cách xử lý dữ liệu thiếu, câu trả lời mâu thuẫn và trường hợp ngoài dự kiến. Quy tắc xử lý cần được áp dụng nhất quán, đồng thời cho phép ghi nhận ngoại lệ có lý do thay vì âm thầm loại bỏ thông tin bất tiện.</p>
<p>Tài liệu vận hành cho thiết kế dự án có mục tiêu cần tính đến khả năng gián đoạn, lỗi công cụ và việc người dùng sử dụng thiết bị khác nhau. Hướng dẫn thay thế nên đủ đơn giản để tiếp tục công việc an toàn mà không làm mất dữ liệu hoặc bỏ qua các bước kiểm soát cần thiết.</p>
<p>Sau mỗi chu kỳ thiết kế dự án có mục tiêu, nhóm nên lưu bài học có thể áp dụng, quyết định sẽ thay đổi và vấn đề cần theo dõi ở lần tiếp theo. Cải tiến có trách nhiệm không chỉ ghi nhận điều thành công mà còn kiểm tra chi phí, tác dụng phụ và những nhóm chưa được phục vụ tốt.</p>
</section>
<section class="longform-section" id="gioi-thieu-13"><h2>13. Đánh giá tác động thận trọng</h2>
<p>Phần này tập trung vào đánh giá tác động thận trọng. Đánh giá tác động phải phân biệt đầu ra trực tiếp với thay đổi dài hạn. Số hoạt động hoặc lượt tham gia không tự chứng minh rằng năng lực đã được cải thiện. Muốn nói về tác động, cần xác định chỉ báo phù hợp, thời điểm đo, nguồn dữ liệu, yếu tố gây nhiễu và giới hạn của kết luận. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Trước khi triển khai nội dung về đánh giá tác động thận trọng, nhóm cần xác định ai chịu ảnh hưởng, câu hỏi cần trả lời và điều kiện nào có thể làm thay đổi cách tiếp cận. Phạm vi được ghi rõ giúp tránh mở rộng yêu cầu ngoài nguồn lực hoặc bằng chứng sẵn có.</p>
<p>Phương pháp cho đánh giá tác động thận trọng cần mô tả cách lựa chọn dữ liệu, tiêu chí đưa vào hoặc loại trừ, công cụ sử dụng và cách ghi nhận thay đổi. Người đọc phải phân biệt được quy trình đã thực hiện với phương án mới chỉ được đề xuất.</p>
<p>Trong quá trình thực hiện đánh giá tác động thận trọng, thông tin cập nhật cần phản ánh đúng tiến độ và những việc còn phụ thuộc. Khi có thay đổi về lịch, nhân sự hoặc phạm vi, người phụ trách nên ghi lại quyết định và thông báo cho các bên bị ảnh hưởng bằng kênh phù hợp.</p>
<p>Đánh giá đánh giá tác động thận trọng cần dựa trên bằng chứng tương ứng với tuyên bố được đưa ra. Báo cáo nên phân biệt đầu ra đã hoàn thành, thay đổi quan sát được và tác động chưa đủ dữ liệu để kết luận; không suy diễn quan hệ nhân quả chỉ từ việc hai sự kiện xảy ra cùng lúc.</p>
</section>
<section class="longform-section" id="gioi-thieu-14"><h2>14. Khảo thí và đo lường năng lực</h2>
<p>Phần này tập trung vào khảo thí và đo lường năng lực. Một bài đánh giá chỉ hữu ích nếu nội dung, thời gian, cách chấm và cách diễn giải kết quả phù hợp với mục tiêu. Tính nhất quán cần được kiểm tra, nhưng tính công bằng cũng đòi hỏi xem xét khả năng tiếp cận, ngôn ngữ câu hỏi và những điều kiện không liên quan đến năng lực đang đo. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khâu chuẩn bị nên tách nhu cầu đã được ghi nhận khỏi giả định ban đầu. Với khảo thí và đo lường năng lực, mỗi giả định quan trọng cần có cách kiểm tra, người chịu trách nhiệm và mốc xem xét; nếu chưa thể kiểm chứng, tài liệu phải nêu rõ giới hạn thay vì biến dự đoán thành kết luận.</p>
<p>Khi thiết kế quy trình về khảo thí và đo lường năng lực, cần phân công vai trò, điểm kiểm tra chất lượng và cách xử lý sai lệch. Một quy trình có thể giải thích được quan trọng hơn một danh sách bước dài; mỗi bước nên có mục đích, đầu vào và đầu ra rõ ràng.</p>
<p>Hoạt động liên quan đến khảo thí và đo lường năng lực cần tôn trọng quyền tham gia và quyền từ chối của mỗi người. Hướng dẫn nên nêu rõ việc gì sẽ diễn ra, ai có thể xem dữ liệu, cách đặt câu hỏi và nơi tiếp nhận phản ánh nếu người tham gia thấy không an toàn hoặc chưa hiểu.</p>
<p>Khi tổng kết khảo thí và đo lường năng lực, cần công bố phạm vi dữ liệu, thời điểm cập nhật, giới hạn đo lường và những câu hỏi còn bỏ ngỏ. Một kết quả chưa như kỳ vọng vẫn có thể đem lại bài học nếu phương pháp, sai lệch và điều kiện thực hiện được mô tả trung thực.</p>
</section>
<section class="longform-section" id="gioi-thieu-15"><h2>15. Bảo vệ tính toàn vẹn kỳ thi</h2>
<p>Phần này tập trung vào bảo vệ tính toàn vẹn kỳ thi. Tính toàn vẹn kỳ thi phụ thuộc vào phân quyền, bảo vệ câu hỏi, ghi nhận trạng thái bài thi và xử lý sự cố có quy trình. Hệ thống cần phân biệt bản nháp, bản lưu được máy chủ xác nhận và bài đã nộp. Người dự thi nên nhận thông báo rõ ràng khi mất kết nối hoặc khi cần thực hiện lại thao tác. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khi xem xét bảo vệ tính toàn vẹn kỳ thi, nên lập danh sách bên liên quan, rào cản tham gia, điều kiện tiếp cận và nguồn thông tin hợp pháp. Cách xác định phạm vi này giúp nhóm lựa chọn hoạt động phù hợp, đồng thời tránh yêu cầu người tham gia cung cấp thông tin vượt quá mục đích.</p>
<p>Các tiêu chí đánh giá bảo vệ tính toàn vẹn kỳ thi nên được xác định trước khi xem kết quả để hạn chế lựa chọn tiêu chí có lợi sau khi đã biết dữ liệu. Nếu tiêu chí phải thay đổi, nhóm cần ghi lý do, thời điểm và ảnh hưởng của thay đổi đối với kết luận.</p>
<p>Để duy trì chất lượng của bảo vệ tính toàn vẹn kỳ thi, nhóm cần lưu bằng chứng đủ dùng, cập nhật trạng thái có ngày tháng và tránh biến số liệu tạm thời thành kết quả cuối. Tài liệu nội bộ và nội dung công khai phải được phân biệt để không làm lộ thông tin cần bảo vệ.</p>
<p>Các chỉ số liên quan đến bảo vệ tính toàn vẹn kỳ thi chỉ có ý nghĩa khi có định nghĩa, nguồn và thời điểm đo nhất quán. Nếu chưa có số liệu đáng tin cậy, nên ghi rõ chưa có dữ liệu xác minh thay vì ước lượng để lấp chỗ trống hoặc tạo cảm giác chắc chắn.</p>
</section>
<section class="longform-section" id="gioi-thieu-16"><h2>16. Tính công bằng trong đánh giá</h2>
<p>Phần này tập trung vào tính công bằng trong đánh giá. Công bằng không có nghĩa là bỏ qua tiêu chuẩn; đó là áp dụng tiêu chuẩn phù hợp và nhất quán, đồng thời xử lý trường hợp ngoại lệ theo quy trình. Khi có khiếu nại, bằng chứng và lịch sử thao tác phải được xem xét bởi người có thẩm quyền, với cách thông báo tôn trọng và có thể hiểu được. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Một câu hỏi tốt về tính công bằng trong đánh giá cần đủ cụ thể để hướng dẫn hành động nhưng đủ mở để tiếp nhận bằng chứng trái với kỳ vọng. Nhóm nên xác định điều gì nằm trong phạm vi, điều gì chưa thể trả lời và trường hợp nào cần chuyển sang đánh giá chuyên môn khác.</p>
<p>Tài liệu hóa phương pháp liên quan đến tính công bằng trong đánh giá giúp người khác kiểm tra logic của quyết định mà không cần suy đoán. Cần ghi nguồn, phiên bản công cụ, điều kiện thực hiện và các ngoại lệ quan trọng; không được mô tả một quy trình lý tưởng như thể nó đã diễn ra.</p>
<p>Phối hợp trong tính công bằng trong đánh giá nên có đầu mối chịu trách nhiệm, quy tắc chuyển giao và cách xử lý khi người phụ trách vắng mặt. Việc bàn giao cần giữ được bối cảnh quyết định, hạn chế phụ thuộc vào trí nhớ cá nhân và không chia sẻ quyền truy cập vượt nhu cầu công việc.</p>
<p>Bước rà soát cuối của tính công bằng trong đánh giá nên hỏi điều gì đã được chứng minh, điều gì chỉ là nhận định và điều gì cần kiểm tra tiếp. Kết luận cần tương xứng với bằng chứng, đồng thời chỉ ra hành động tiếp theo và người chịu trách nhiệm nếu cần cải thiện.</p>
</section>
<section class="longform-section" id="gioi-thieu-17"><h2>17. Công bố kết quả và dữ liệu</h2>
<p>Phần này tập trung vào công bố kết quả và dữ liệu. Kết quả học thuật, dữ liệu nghiên cứu và báo cáo cá nhân có mức độ công khai khác nhau. Trước khi công bố, cần kiểm tra quyền sử dụng, sự đồng thuận, độ chính xác và nguy cơ nhận diện. Dữ liệu công khai nên được giới hạn ở phần cần thiết để người đọc hiểu kết quả mà không xâm phạm quyền riêng tư. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Để xác định nhu cầu liên quan đến công bố kết quả và dữ liệu, cần xem xét bối cảnh địa phương, năng lực thực hiện, thời gian và khả năng tiếp cận của người tham gia. Không nên suy rộng từ một phản ánh đơn lẻ; thông tin ban đầu cần được đối chiếu bằng nguồn độc lập khi phù hợp.</p>
<p>Việc lựa chọn phương pháp cho công bố kết quả và dữ liệu phải tương xứng với câu hỏi và năng lực thực hiện. Công cụ phức tạp không tự động tạo ra kết quả đáng tin cậy; điều quan trọng là dữ liệu phù hợp, tiêu chí nhất quán và khả năng giải thích các bước phân tích.</p>
<p>Khi có phản hồi về công bố kết quả và dữ liệu, nhóm cần ghi nhận nội dung, đánh giá mức độ ảnh hưởng và phản hồi trong thời hạn hợp lý. Không phải mọi đề xuất đều có thể được chấp nhận, nhưng lý do tiếp nhận hoặc từ chối nên rõ ràng và không gây bất lợi cho người góp ý.</p>
<p>Kết quả của công bố kết quả và dữ liệu cần được xem xét cùng các yếu tố có thể làm sai lệch như mẫu không đại diện, dữ liệu thiếu, thay đổi điều kiện hoặc phản hồi thiên lệch. Việc nêu rõ các giới hạn này giúp người đọc hiểu kết quả áp dụng đến đâu.</p>
</section>
<section class="longform-section" id="gioi-thieu-18"><h2>18. Thư viện tài liệu</h2>
<p>Phần này tập trung vào thư viện tài liệu. Một thư viện tài liệu tốt cần phân loại rõ, cung cấp thông tin mô tả đủ dùng, ghi nhận phiên bản và thể hiện quyền truy cập. Người dùng phải nhận biết tài liệu nào có thể tải, tài liệu nào chỉ xem và tài liệu nào không dành cho công chúng. Bản sửa đổi nên được quản lý để tránh nhầm lẫn phiên bản. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Phạm vi của thư viện tài liệu nên được diễn đạt bằng ngôn ngữ người tham gia có thể hiểu, kèm mục tiêu và giới hạn rõ ràng. Việc thống nhất thuật ngữ ngay từ đầu giúp các nhóm phối hợp tránh hiểu khác nhau về đối tượng, kết quả mong đợi và trách nhiệm thực hiện.</p>
<p>Đối với thư viện tài liệu, nên xác định trước cách xử lý dữ liệu thiếu, câu trả lời mâu thuẫn và trường hợp ngoài dự kiến. Quy tắc xử lý cần được áp dụng nhất quán, đồng thời cho phép ghi nhận ngoại lệ có lý do thay vì âm thầm loại bỏ thông tin bất tiện.</p>
<p>Tài liệu vận hành cho thư viện tài liệu cần tính đến khả năng gián đoạn, lỗi công cụ và việc người dùng sử dụng thiết bị khác nhau. Hướng dẫn thay thế nên đủ đơn giản để tiếp tục công việc an toàn mà không làm mất dữ liệu hoặc bỏ qua các bước kiểm soát cần thiết.</p>
<p>Sau mỗi chu kỳ thư viện tài liệu, nhóm nên lưu bài học có thể áp dụng, quyết định sẽ thay đổi và vấn đề cần theo dõi ở lần tiếp theo. Cải tiến có trách nhiệm không chỉ ghi nhận điều thành công mà còn kiểm tra chi phí, tác dụng phụ và những nhóm chưa được phục vụ tốt.</p>
</section>
<section class="longform-section" id="gioi-thieu-19"><h2>19. Tiếp cận song ngữ</h2>
<p>Phần này tập trung vào tiếp cận song ngữ. Giao diện Việt–Anh nên giữ cùng ý nghĩa, không chỉ đổi nhãn menu. Thông báo lỗi, điều kiện đăng ký, các bước khảo thí và thông tin chính sách đều cần có bản dịch tương đương. Khi chưa có bản dịch đã rà soát, hệ thống cần thể hiện rõ tình trạng thay vì tạo nội dung dịch máy như thể đã được duyệt. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Trước khi triển khai nội dung về tiếp cận song ngữ, nhóm cần xác định ai chịu ảnh hưởng, câu hỏi cần trả lời và điều kiện nào có thể làm thay đổi cách tiếp cận. Phạm vi được ghi rõ giúp tránh mở rộng yêu cầu ngoài nguồn lực hoặc bằng chứng sẵn có.</p>
<p>Phương pháp cho tiếp cận song ngữ cần mô tả cách lựa chọn dữ liệu, tiêu chí đưa vào hoặc loại trừ, công cụ sử dụng và cách ghi nhận thay đổi. Người đọc phải phân biệt được quy trình đã thực hiện với phương án mới chỉ được đề xuất.</p>
<p>Trong quá trình thực hiện tiếp cận song ngữ, thông tin cập nhật cần phản ánh đúng tiến độ và những việc còn phụ thuộc. Khi có thay đổi về lịch, nhân sự hoặc phạm vi, người phụ trách nên ghi lại quyết định và thông báo cho các bên bị ảnh hưởng bằng kênh phù hợp.</p>
<p>Đánh giá tiếp cận song ngữ cần dựa trên bằng chứng tương ứng với tuyên bố được đưa ra. Báo cáo nên phân biệt đầu ra đã hoàn thành, thay đổi quan sát được và tác động chưa đủ dữ liệu để kết luận; không suy diễn quan hệ nhân quả chỉ từ việc hai sự kiện xảy ra cùng lúc.</p>
</section>', content_en='<section class="longform-section" id="about-1"><h2>1. Identity and scope</h2>
<p>This section focuses on identity and scope. Sky First Center for Research and Development is the name used for this professional information portal. Its stated subject areas are applied scientific research, community development, academic assessment, and the publication and organization of knowledge resources. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Before work on identity and scope begins, the team should identify affected people, the question to answer, and the conditions that could change the approach. A clear scope prevents requests from expanding beyond available resources or the evidence that can reasonably be obtained.</p>
<p>Methods for identity and scope should explain how evidence is selected, which inclusion or exclusion criteria apply, what tools are used, and how changes are recorded. Readers must be able to distinguish procedures actually followed from options that were only proposed.</p>
<p>During work on identity and scope, updates should accurately describe progress and unresolved dependencies. When schedules, staffing, or scope change, the responsible person should record the decision and notify affected parties through an appropriate channel.</p>
<p>Evaluation of identity and scope should use evidence proportionate to the claim being made. Reports should distinguish completed outputs, observed changes, and impacts that cannot yet be established; correlation alone must not be presented as proof of causation.</p>
</section>
<section class="longform-section" id="about-2"><h2>2. Mission</h2>
<p>This section focuses on mission. The mission is expressed by connecting research questions with practical needs, designing purposeful community activities, and administering academic assessment through clear processes. A mission statement matters only when it informs observable decisions and practices that can be reviewed and improved. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Preparation should separate documented needs from initial assumptions. For mission, each important assumption needs a way to check it, an accountable person, and a review point; when verification is not possible, the limitation should be stated rather than turning a prediction into a conclusion.</p>
<p>A process for mission needs assigned responsibilities, quality checkpoints, and a way to handle deviations. An explainable workflow matters more than a long checklist; each step should have a clear purpose, input, and expected output.</p>
<p>Activities related to mission must respect each person&#x27;s ability to participate or decline. Instructions should explain what will happen, who may see the data, how to ask questions, and where to raise concerns if a participant feels unsafe or confused.</p>
<p>A review of mission should disclose the evidence scope, update date, measurement limits, and unanswered questions. A result that falls short of expectations can still be useful if the method, deviations, and operating conditions are described honestly.</p>
</section>
<section class="longform-section" id="about-3"><h2>3. Vision and principles</h2>
<p>This section focuses on vision and principles. A vision sets a long-term direction but does not replace concrete plans or evidence of results. Foundational principles include transparency, academic responsibility, respect for people, proportionate use of resources, data protection, and willingness to change when evaluation shows that a practice is unsuitable. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Reviewing vision and principles should include the people involved, barriers to participation, access conditions, and lawful information sources. This scoping work helps teams choose proportionate activities while avoiding requests for personal information that exceeds the stated purpose.</p>
<p>Evaluation criteria for vision and principles should be defined before results are reviewed, reducing the risk of selecting favorable criteria after the evidence is known. If criteria change, record the reason, timing, and effect on any conclusions.</p>
<p>To maintain the quality of vision and principles, teams should retain proportionate evidence, date status updates, and avoid presenting provisional figures as final results. Internal records must be distinguished from public material so protected information is not exposed.</p>
<p>Metrics for vision and principles are meaningful only when their definitions, sources, and measurement dates are consistent. If reliable figures are unavailable, state that evidence has not been verified rather than estimating values to fill a gap or create false certainty.</p>
</section>
<section class="longform-section" id="about-4"><h2>4. Research and verification</h2>
<p>This section focuses on research and verification. Research needs a question, defined scope, method, analytical criteria, and explicit limitations. Verification does not mean that every result is certain; it makes it possible for others to assess the evidence, identify error, and examine interpretation. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>A useful question about research and verification should be specific enough to guide action yet open enough to accommodate evidence that challenges expectations. Teams should state what is in scope, what cannot yet be answered, and when another form of professional review is needed.</p>
<p>Documenting methods for research and verification lets others examine the reasoning without guessing. Record sources, tool versions, operating conditions, and meaningful exceptions; never describe an idealized procedure as if it had actually taken place.</p>
<p>Coordination for research and verification should identify an accountable contact, handover rules, and arrangements for absences. A handover should preserve decision context, reduce dependence on personal memory, and avoid sharing access beyond what the work requires.</p>
<p>The final review of research and verification should ask what has been demonstrated, what remains an interpretation, and what needs further checking. Conclusions must match the evidence and identify practical next steps and accountable owners where improvement is needed.</p>
</section>
<section class="longform-section" id="about-5"><h2>5. Ethical standards</h2>
<p>This section focuses on ethical standards. Ethical standards should be considered during program design. Participation requires appropriate consent, benefits and risks should be explained, and identifying information should be accessible only to people with a legitimate role. Any exception needs assessment against the specific circumstances. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Needs related to ethical standards should be considered in light of local context, capacity, timing, and participant access. A single comment should not be generalized without support; initial information should be compared with independent sources when that is appropriate and feasible.</p>
<p>The method chosen for ethical standards should fit the question and the team&#x27;s capacity. A complex tool does not automatically produce trustworthy results; suitable evidence, consistent criteria, and explainable analysis are more important.</p>
<p>When feedback about ethical standards arrives, the team should record it, assess its impact, and respond within a reasonable period. Not every suggestion can be accepted, but the reason for accepting or declining it should be clear and should not penalize the person who raised it.</p>
<p>Results for ethical standards should be considered alongside possible sources of bias, such as an unrepresentative sample, missing data, changed conditions, or selective feedback. Stating these limits helps readers understand where the findings can reasonably be applied.</p>
</section>
<section class="longform-section" id="about-6"><h2>6. Responsibility structure</h2>
<p>This section focuses on responsibility structure. An effective responsibility structure identifies who proposes, reviews, approves, and monitors work. A title does not create unlimited authority. Digital-system and data permissions should be tied to tasks, reviewed periodically, and withdrawn when they are no longer needed. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>The scope of responsibility structure should use language participants can understand and state its purpose and limits. Agreeing on terminology early helps teams avoid conflicting interpretations of the target group, intended outcomes, and each party&#x27;s responsibilities.</p>
<p>For responsibility structure, define in advance how missing data, conflicting responses, and unexpected cases will be handled. Apply the rules consistently while allowing justified exceptions to be recorded rather than silently discarding inconvenient information.</p>
<p>Operational guidance for responsibility structure should account for outages, tool failures, and differences in users&#x27; devices. A fallback process should let people continue safely without losing data or bypassing necessary safeguards.</p>
<p>After each cycle of responsibility structure, record lessons that can be used, decisions that will change, and questions to monitor next time. Responsible improvement considers not only successes but also costs, side effects, and groups that remain underserved.</p>
</section>
<section class="longform-section" id="about-7"><h2>7. Professional coordination</h2>
<p>This section focuses on professional coordination. Specialized teams need clear ways to communicate decisions, manage versions, and hand work over. When several groups contribute, responsibilities and approval points should be agreed to avoid gaps or duplication. Coordination records should help a new participant continue work without relying on undocumented assumptions. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Before work on professional coordination begins, the team should identify affected people, the question to answer, and the conditions that could change the approach. A clear scope prevents requests from expanding beyond available resources or the evidence that can reasonably be obtained.</p>
<p>Methods for professional coordination should explain how evidence is selected, which inclusion or exclusion criteria apply, what tools are used, and how changes are recorded. Readers must be able to distinguish procedures actually followed from options that were only proposed.</p>
<p>During work on professional coordination, updates should accurately describe progress and unresolved dependencies. When schedules, staffing, or scope change, the responsible person should record the decision and notify affected parties through an appropriate channel.</p>
<p>Evaluation of professional coordination should use evidence proportionate to the claim being made. Reports should distinguish completed outputs, observed changes, and impacts that cannot yet be established; correlation alone must not be presented as proof of causation.</p>
</section>
<section class="longform-section" id="about-8"><h2>8. Quality governance</h2>
<p>This section focuses on quality governance. Quality governance combines input standards, independent review where appropriate, issue tracking, and confirmation of fixes. Not every output needs identical scrutiny; review intensity should match risk, impact, and data sensitivity. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Preparation should separate documented needs from initial assumptions. For quality governance, each important assumption needs a way to check it, an accountable person, and a review point; when verification is not possible, the limitation should be stated rather than turning a prediction into a conclusion.</p>
<p>A process for quality governance needs assigned responsibilities, quality checkpoints, and a way to handle deviations. An explainable workflow matters more than a long checklist; each step should have a clear purpose, input, and expected output.</p>
<p>Activities related to quality governance must respect each person&#x27;s ability to participate or decline. Instructions should explain what will happen, who may see the data, how to ask questions, and where to raise concerns if a participant feels unsafe or confused.</p>
<p>A review of quality governance should disclose the evidence scope, update date, measurement limits, and unanswered questions. A result that falls short of expectations can still be useful if the method, deviations, and operating conditions are described honestly.</p>
</section>
<section class="longform-section" id="about-9"><h2>9. Conflict-of-interest management</h2>
<p>This section focuses on conflict-of-interest management. Conflicts of interest should be identified and managed rather than assuming that every participant is always impartial. When personal interests, relationships, or roles could influence a review, disclosure and mitigation may include an alternate reviewer, constrained decision authority, or a documented rationale. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Reviewing conflict-of-interest management should include the people involved, barriers to participation, access conditions, and lawful information sources. This scoping work helps teams choose proportionate activities while avoiding requests for personal information that exceeds the stated purpose.</p>
<p>Evaluation criteria for conflict-of-interest management should be defined before results are reviewed, reducing the risk of selecting favorable criteria after the evidence is known. If criteria change, record the reason, timing, and effect on any conclusions.</p>
<p>To maintain the quality of conflict-of-interest management, teams should retain proportionate evidence, date status updates, and avoid presenting provisional figures as final results. Internal records must be distinguished from public material so protected information is not exposed.</p>
<p>Metrics for conflict-of-interest management are meaningful only when their definitions, sources, and measurement dates are consistent. If reliable figures are unavailable, state that evidence has not been verified rather than estimating values to fill a gap or create false certainty.</p>
</section>
<section class="longform-section" id="about-10"><h2>10. Interdisciplinary research</h2>
<p>This section focuses on interdisciplinary research. Community questions often involve education, technology, environment, behavior, and social conditions. Interdisciplinary work should explain each field’s contribution, use terms consistently, and avoid combining incompatible conclusions merely to produce a simple narrative. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>A useful question about interdisciplinary research should be specific enough to guide action yet open enough to accommodate evidence that challenges expectations. Teams should state what is in scope, what cannot yet be answered, and when another form of professional review is needed.</p>
<p>Documenting methods for interdisciplinary research lets others examine the reasoning without guessing. Record sources, tool versions, operating conditions, and meaningful exceptions; never describe an idealized procedure as if it had actually taken place.</p>
<p>Coordination for interdisciplinary research should identify an accountable contact, handover rules, and arrangements for absences. A handover should preserve decision context, reduce dependence on personal memory, and avoid sharing access beyond what the work requires.</p>
<p>The final review of interdisciplinary research should ask what has been demonstrated, what remains an interpretation, and what needs further checking. Conclusions must match the evidence and identify practical next steps and accountable owners where improvement is needed.</p>
</section>
<section class="longform-section" id="about-11"><h2>11. Community participation</h2>
<p>This section focuses on community participation. Communities are not only recipients of support; they hold knowledge about needs, barriers, and local conditions. Suitable participation may include discussion, surveys, post-activity feedback, and evaluation. Participation should be voluntary, accessible, and free from misleading expectations. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Needs related to community participation should be considered in light of local context, capacity, timing, and participant access. A single comment should not be generalized without support; initial information should be compared with independent sources when that is appropriate and feasible.</p>
<p>The method chosen for community participation should fit the question and the team&#x27;s capacity. A complex tool does not automatically produce trustworthy results; suitable evidence, consistent criteria, and explainable analysis are more important.</p>
<p>When feedback about community participation arrives, the team should record it, assess its impact, and respond within a reasonable period. Not every suggestion can be accepted, but the reason for accepting or declining it should be clear and should not penalize the person who raised it.</p>
<p>Results for community participation should be considered alongside possible sources of bias, such as an unrepresentative sample, missing data, changed conditions, or selective feedback. Stating these limits helps readers understand where the findings can reasonably be applied.</p>
</section>
<section class="longform-section" id="about-12"><h2>12. Purposeful project design</h2>
<p>This section focuses on purposeful project design. Each project should describe the problem, intended beneficiaries, activities, resources, milestones, and evaluation criteria. Dependencies should also be stated because delivery may depend on a location, staffing, approvals, or funding that has not been confirmed. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>The scope of purposeful project design should use language participants can understand and state its purpose and limits. Agreeing on terminology early helps teams avoid conflicting interpretations of the target group, intended outcomes, and each party&#x27;s responsibilities.</p>
<p>For purposeful project design, define in advance how missing data, conflicting responses, and unexpected cases will be handled. Apply the rules consistently while allowing justified exceptions to be recorded rather than silently discarding inconvenient information.</p>
<p>Operational guidance for purposeful project design should account for outages, tool failures, and differences in users&#x27; devices. A fallback process should let people continue safely without losing data or bypassing necessary safeguards.</p>
<p>After each cycle of purposeful project design, record lessons that can be used, decisions that will change, and questions to monitor next time. Responsible improvement considers not only successes but also costs, side effects, and groups that remain underserved.</p>
</section>
<section class="longform-section" id="about-13"><h2>13. Careful impact assessment</h2>
<p>This section focuses on careful impact assessment. Impact evaluation distinguishes immediate outputs from long-term change. Activity counts or attendance do not by themselves prove improved capability. Impact claims require suitable indicators, measurement timing, data sources, confounders, and explicit limits on interpretation. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Before work on careful impact assessment begins, the team should identify affected people, the question to answer, and the conditions that could change the approach. A clear scope prevents requests from expanding beyond available resources or the evidence that can reasonably be obtained.</p>
<p>Methods for careful impact assessment should explain how evidence is selected, which inclusion or exclusion criteria apply, what tools are used, and how changes are recorded. Readers must be able to distinguish procedures actually followed from options that were only proposed.</p>
<p>During work on careful impact assessment, updates should accurately describe progress and unresolved dependencies. When schedules, staffing, or scope change, the responsible person should record the decision and notify affected parties through an appropriate channel.</p>
<p>Evaluation of careful impact assessment should use evidence proportionate to the claim being made. Reports should distinguish completed outputs, observed changes, and impacts that cannot yet be established; correlation alone must not be presented as proof of causation.</p>
</section>
<section class="longform-section" id="about-14"><h2>14. Assessment and competency measurement</h2>
<p>This section focuses on assessment and competency measurement. An assessment is useful only when content, duration, scoring, and interpretation fit its objective. Consistency matters, while fairness also requires attention to accessibility, question language, and conditions unrelated to the competency being measured. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Preparation should separate documented needs from initial assumptions. For assessment and competency measurement, each important assumption needs a way to check it, an accountable person, and a review point; when verification is not possible, the limitation should be stated rather than turning a prediction into a conclusion.</p>
<p>A process for assessment and competency measurement needs assigned responsibilities, quality checkpoints, and a way to handle deviations. An explainable workflow matters more than a long checklist; each step should have a clear purpose, input, and expected output.</p>
<p>Activities related to assessment and competency measurement must respect each person&#x27;s ability to participate or decline. Instructions should explain what will happen, who may see the data, how to ask questions, and where to raise concerns if a participant feels unsafe or confused.</p>
<p>A review of assessment and competency measurement should disclose the evidence scope, update date, measurement limits, and unanswered questions. A result that falls short of expectations can still be useful if the method, deviations, and operating conditions are described honestly.</p>
</section>
<section class="longform-section" id="about-15"><h2>15. Protecting exam integrity</h2>
<p>This section focuses on protecting exam integrity. Exam integrity depends on authorization, question protection, recorded attempt state, and a defined incident process. Systems should distinguish local drafts, server-confirmed saves, and submitted work. Candidates need clear guidance when connectivity fails or an action must be retried. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Reviewing protecting exam integrity should include the people involved, barriers to participation, access conditions, and lawful information sources. This scoping work helps teams choose proportionate activities while avoiding requests for personal information that exceeds the stated purpose.</p>
<p>Evaluation criteria for protecting exam integrity should be defined before results are reviewed, reducing the risk of selecting favorable criteria after the evidence is known. If criteria change, record the reason, timing, and effect on any conclusions.</p>
<p>To maintain the quality of protecting exam integrity, teams should retain proportionate evidence, date status updates, and avoid presenting provisional figures as final results. Internal records must be distinguished from public material so protected information is not exposed.</p>
<p>Metrics for protecting exam integrity are meaningful only when their definitions, sources, and measurement dates are consistent. If reliable figures are unavailable, state that evidence has not been verified rather than estimating values to fill a gap or create false certainty.</p>
</section>
<section class="longform-section" id="about-16"><h2>16. Fairness in assessment</h2>
<p>This section focuses on fairness in assessment. Fairness does not mean abandoning standards; it means applying suitable, consistent standards and handling exceptions through a defined process. Complaints should be reviewed by authorized people using evidence and event history, with respectful and understandable communication. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>A useful question about fairness in assessment should be specific enough to guide action yet open enough to accommodate evidence that challenges expectations. Teams should state what is in scope, what cannot yet be answered, and when another form of professional review is needed.</p>
<p>Documenting methods for fairness in assessment lets others examine the reasoning without guessing. Record sources, tool versions, operating conditions, and meaningful exceptions; never describe an idealized procedure as if it had actually taken place.</p>
<p>Coordination for fairness in assessment should identify an accountable contact, handover rules, and arrangements for absences. A handover should preserve decision context, reduce dependence on personal memory, and avoid sharing access beyond what the work requires.</p>
<p>The final review of fairness in assessment should ask what has been demonstrated, what remains an interpretation, and what needs further checking. Conclusions must match the evidence and identify practical next steps and accountable owners where improvement is needed.</p>
</section>
<section class="longform-section" id="about-17"><h2>17. Publishing results and data</h2>
<p>This section focuses on publishing results and data. Academic results, research datasets, and individual reports have different publication permissions. Before release, teams should check authorization, consent, accuracy, and re-identification risk. Public data should be limited to what readers need to understand the result without violating privacy. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Needs related to publishing results and data should be considered in light of local context, capacity, timing, and participant access. A single comment should not be generalized without support; initial information should be compared with independent sources when that is appropriate and feasible.</p>
<p>The method chosen for publishing results and data should fit the question and the team&#x27;s capacity. A complex tool does not automatically produce trustworthy results; suitable evidence, consistent criteria, and explainable analysis are more important.</p>
<p>When feedback about publishing results and data arrives, the team should record it, assess its impact, and respond within a reasonable period. Not every suggestion can be accepted, but the reason for accepting or declining it should be clear and should not penalize the person who raised it.</p>
<p>Results for publishing results and data should be considered alongside possible sources of bias, such as an unrepresentative sample, missing data, changed conditions, or selective feedback. Stating these limits helps readers understand where the findings can reasonably be applied.</p>
</section>
<section class="longform-section" id="about-18"><h2>18. Resource library</h2>
<p>This section focuses on resource library. A useful resource library has clear categories, meaningful descriptions, version information, and visible access rules. Users should understand which items can be downloaded, which are view-only, and which are not public. Revisions should be managed to prevent version confusion. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>The scope of resource library should use language participants can understand and state its purpose and limits. Agreeing on terminology early helps teams avoid conflicting interpretations of the target group, intended outcomes, and each party&#x27;s responsibilities.</p>
<p>For resource library, define in advance how missing data, conflicting responses, and unexpected cases will be handled. Apply the rules consistently while allowing justified exceptions to be recorded rather than silently discarding inconvenient information.</p>
<p>Operational guidance for resource library should account for outages, tool failures, and differences in users&#x27; devices. A fallback process should let people continue safely without losing data or bypassing necessary safeguards.</p>
<p>After each cycle of resource library, record lessons that can be used, decisions that will change, and questions to monitor next time. Responsible improvement considers not only successes but also costs, side effects, and groups that remain underserved.</p>
</section>
<section class="longform-section" id="about-19"><h2>19. Bilingual accessibility</h2>
<p>This section focuses on bilingual accessibility. A Vietnamese–English interface should preserve meaning, not merely translate menu labels. Errors, registration conditions, assessment steps, and policies all need equivalent versions. Where reviewed translation is unavailable, the site should show that status instead of presenting an unchecked machine translation as approved text. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Before work on bilingual accessibility begins, the team should identify affected people, the question to answer, and the conditions that could change the approach. A clear scope prevents requests from expanding beyond available resources or the evidence that can reasonably be obtained.</p>
<p>Methods for bilingual accessibility should explain how evidence is selected, which inclusion or exclusion criteria apply, what tools are used, and how changes are recorded. Readers must be able to distinguish procedures actually followed from options that were only proposed.</p>
<p>During work on bilingual accessibility, updates should accurately describe progress and unresolved dependencies. When schedules, staffing, or scope change, the responsible person should record the decision and notify affected parties through an appropriate channel.</p>
<p>Evaluation of bilingual accessibility should use evidence proportionate to the claim being made. Reports should distinguish completed outputs, observed changes, and impacts that cannot yet be established; correlation alone must not be presented as proof of causation.</p>
</section>',
    page_group='about', seo_title_vi='Giới thiệu Trung tâm | Sky First', seo_title_en='About the Center | Sky First',
    seo_description_vi='Thông tin tổng quan về phạm vi hoạt động, nguyên tắc chuyên môn, cách tổ chức công việc và trách nhiệm của Trung tâm.', seo_description_en='An overview of the Center’s scope, professional principles, working practices, and responsibilities.',
    sort_order=1, status='published', updated_at=CURRENT_TIMESTAMP
WHERE slug='tong-quan';

INSERT INTO cms_pages (id,slug,title_vi,title_en,summary_vi,summary_en,content_vi,content_en,page_group,seo_title_vi,seo_title_en,seo_description_vi,seo_description_en,sort_order,status,version,published_at,created_at,updated_at)
VALUES ('page_home_longform','trang-chu-noi-dung','Tổng quan nội dung Trung tâm','About the Center: Overview and Areas of Work','Tổng quan về nghiên cứu ứng dụng, dự án cộng đồng, khảo thí học thuật, công bố tri thức và nguyên tắc vận hành của Trung tâm.','An overview of applied research, community projects, academic assessment, knowledge publication, and the Center’s operating principles.','<section class="longform-section" id="trang-chu-1"><h2>1. Nghiên cứu khoa học ứng dụng</h2>
<p>Phần này tập trung vào nghiên cứu khoa học ứng dụng. Nghiên cứu khoa học cần bắt đầu từ câu hỏi rõ ràng, bối cảnh được mô tả trung thực và phương pháp phù hợp với nguồn lực thực tế. Trung tâm hướng tới cách tiếp cận giúp người đọc hiểu vì sao một câu hỏi đáng nghiên cứu, dữ liệu nào cần thu thập và giới hạn nào phải được công khai. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Trước khi triển khai nội dung về nghiên cứu khoa học ứng dụng, nhóm cần xác định ai chịu ảnh hưởng, câu hỏi cần trả lời và điều kiện nào có thể làm thay đổi cách tiếp cận. Phạm vi được ghi rõ giúp tránh mở rộng yêu cầu ngoài nguồn lực hoặc bằng chứng sẵn có.</p>
<p>Phương pháp cho nghiên cứu khoa học ứng dụng cần mô tả cách lựa chọn dữ liệu, tiêu chí đưa vào hoặc loại trừ, công cụ sử dụng và cách ghi nhận thay đổi. Người đọc phải phân biệt được quy trình đã thực hiện với phương án mới chỉ được đề xuất.</p>
<p>Trong quá trình thực hiện nghiên cứu khoa học ứng dụng, thông tin cập nhật cần phản ánh đúng tiến độ và những việc còn phụ thuộc. Khi có thay đổi về lịch, nhân sự hoặc phạm vi, người phụ trách nên ghi lại quyết định và thông báo cho các bên bị ảnh hưởng bằng kênh phù hợp.</p>
<p>Đánh giá nghiên cứu khoa học ứng dụng cần dựa trên bằng chứng tương ứng với tuyên bố được đưa ra. Báo cáo nên phân biệt đầu ra đã hoàn thành, thay đổi quan sát được và tác động chưa đủ dữ liệu để kết luận; không suy diễn quan hệ nhân quả chỉ từ việc hai sự kiện xảy ra cùng lúc.</p>
</section>
<section class="longform-section" id="trang-chu-2"><h2>2. Thiết kế câu hỏi và phạm vi</h2>
<p>Phần này tập trung vào thiết kế câu hỏi và phạm vi. Một đề tài có ích không nhất thiết phải có phạm vi lớn. Việc giới hạn câu hỏi, xác định đối tượng, thời gian và điều kiện nghiên cứu giúp nhóm thực hiện tập trung vào điều có thể kiểm chứng, tránh hứa hẹn kết quả vượt quá dữ liệu. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khâu chuẩn bị nên tách nhu cầu đã được ghi nhận khỏi giả định ban đầu. Với thiết kế câu hỏi và phạm vi, mỗi giả định quan trọng cần có cách kiểm tra, người chịu trách nhiệm và mốc xem xét; nếu chưa thể kiểm chứng, tài liệu phải nêu rõ giới hạn thay vì biến dự đoán thành kết luận.</p>
<p>Khi thiết kế quy trình về thiết kế câu hỏi và phạm vi, cần phân công vai trò, điểm kiểm tra chất lượng và cách xử lý sai lệch. Một quy trình có thể giải thích được quan trọng hơn một danh sách bước dài; mỗi bước nên có mục đích, đầu vào và đầu ra rõ ràng.</p>
<p>Hoạt động liên quan đến thiết kế câu hỏi và phạm vi cần tôn trọng quyền tham gia và quyền từ chối của mỗi người. Hướng dẫn nên nêu rõ việc gì sẽ diễn ra, ai có thể xem dữ liệu, cách đặt câu hỏi và nơi tiếp nhận phản ánh nếu người tham gia thấy không an toàn hoặc chưa hiểu.</p>
<p>Khi tổng kết thiết kế câu hỏi và phạm vi, cần công bố phạm vi dữ liệu, thời điểm cập nhật, giới hạn đo lường và những câu hỏi còn bỏ ngỏ. Một kết quả chưa như kỳ vọng vẫn có thể đem lại bài học nếu phương pháp, sai lệch và điều kiện thực hiện được mô tả trung thực.</p>
</section>
<section class="longform-section" id="trang-chu-3"><h2>3. Tổng quan tài liệu</h2>
<p>Phần này tập trung vào tổng quan tài liệu. Tổng quan tài liệu giúp người nghiên cứu nhận diện khái niệm, phương pháp và tranh luận đã có trước khi lựa chọn hướng tiếp cận. Nguồn tham khảo cần được ghi nhận rõ, phân biệt bằng chứng gốc với ý kiến bình luận, và không trích dẫn tài liệu chưa đọc hoặc chưa xác minh. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khi xem xét tổng quan tài liệu, nên lập danh sách bên liên quan, rào cản tham gia, điều kiện tiếp cận và nguồn thông tin hợp pháp. Cách xác định phạm vi này giúp nhóm lựa chọn hoạt động phù hợp, đồng thời tránh yêu cầu người tham gia cung cấp thông tin vượt quá mục đích.</p>
<p>Các tiêu chí đánh giá tổng quan tài liệu nên được xác định trước khi xem kết quả để hạn chế lựa chọn tiêu chí có lợi sau khi đã biết dữ liệu. Nếu tiêu chí phải thay đổi, nhóm cần ghi lý do, thời điểm và ảnh hưởng của thay đổi đối với kết luận.</p>
<p>Để duy trì chất lượng của tổng quan tài liệu, nhóm cần lưu bằng chứng đủ dùng, cập nhật trạng thái có ngày tháng và tránh biến số liệu tạm thời thành kết quả cuối. Tài liệu nội bộ và nội dung công khai phải được phân biệt để không làm lộ thông tin cần bảo vệ.</p>
<p>Các chỉ số liên quan đến tổng quan tài liệu chỉ có ý nghĩa khi có định nghĩa, nguồn và thời điểm đo nhất quán. Nếu chưa có số liệu đáng tin cậy, nên ghi rõ chưa có dữ liệu xác minh thay vì ước lượng để lấp chỗ trống hoặc tạo cảm giác chắc chắn.</p>
</section>
<section class="longform-section" id="trang-chu-4"><h2>4. Phương pháp và khả năng tái lập</h2>
<p>Phần này tập trung vào phương pháp và khả năng tái lập. Phương pháp cần được mô tả đủ rõ để người khác hiểu cách thực hiện, tiêu chí lựa chọn dữ liệu, quy trình phân tích và các điều chỉnh phát sinh. Không phải dự án nào cũng có thể tái lập hoàn toàn, nhưng việc ghi lại quyết định và giới hạn sẽ tăng khả năng kiểm tra. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Một câu hỏi tốt về phương pháp và khả năng tái lập cần đủ cụ thể để hướng dẫn hành động nhưng đủ mở để tiếp nhận bằng chứng trái với kỳ vọng. Nhóm nên xác định điều gì nằm trong phạm vi, điều gì chưa thể trả lời và trường hợp nào cần chuyển sang đánh giá chuyên môn khác.</p>
<p>Tài liệu hóa phương pháp liên quan đến phương pháp và khả năng tái lập giúp người khác kiểm tra logic của quyết định mà không cần suy đoán. Cần ghi nguồn, phiên bản công cụ, điều kiện thực hiện và các ngoại lệ quan trọng; không được mô tả một quy trình lý tưởng như thể nó đã diễn ra.</p>
<p>Phối hợp trong phương pháp và khả năng tái lập nên có đầu mối chịu trách nhiệm, quy tắc chuyển giao và cách xử lý khi người phụ trách vắng mặt. Việc bàn giao cần giữ được bối cảnh quyết định, hạn chế phụ thuộc vào trí nhớ cá nhân và không chia sẻ quyền truy cập vượt nhu cầu công việc.</p>
<p>Bước rà soát cuối của phương pháp và khả năng tái lập nên hỏi điều gì đã được chứng minh, điều gì chỉ là nhận định và điều gì cần kiểm tra tiếp. Kết luận cần tương xứng với bằng chứng, đồng thời chỉ ra hành động tiếp theo và người chịu trách nhiệm nếu cần cải thiện.</p>
</section>
<section class="longform-section" id="trang-chu-5"><h2>5. Đạo đức nghiên cứu</h2>
<p>Phần này tập trung vào đạo đức nghiên cứu. Đạo đức nghiên cứu bắt đầu từ cách đặt câu hỏi, xin sự đồng thuận, bảo vệ danh tính và cân nhắc khả năng gây ảnh hưởng đến người tham gia. Đối với trẻ vị thành niên hoặc nhóm dễ bị tổn thương, nhóm nghiên cứu cần có cơ chế bảo vệ phù hợp và không xem sự im lặng là đồng thuận. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Để xác định nhu cầu liên quan đến đạo đức nghiên cứu, cần xem xét bối cảnh địa phương, năng lực thực hiện, thời gian và khả năng tiếp cận của người tham gia. Không nên suy rộng từ một phản ánh đơn lẻ; thông tin ban đầu cần được đối chiếu bằng nguồn độc lập khi phù hợp.</p>
<p>Việc lựa chọn phương pháp cho đạo đức nghiên cứu phải tương xứng với câu hỏi và năng lực thực hiện. Công cụ phức tạp không tự động tạo ra kết quả đáng tin cậy; điều quan trọng là dữ liệu phù hợp, tiêu chí nhất quán và khả năng giải thích các bước phân tích.</p>
<p>Khi có phản hồi về đạo đức nghiên cứu, nhóm cần ghi nhận nội dung, đánh giá mức độ ảnh hưởng và phản hồi trong thời hạn hợp lý. Không phải mọi đề xuất đều có thể được chấp nhận, nhưng lý do tiếp nhận hoặc từ chối nên rõ ràng và không gây bất lợi cho người góp ý.</p>
<p>Kết quả của đạo đức nghiên cứu cần được xem xét cùng các yếu tố có thể làm sai lệch như mẫu không đại diện, dữ liệu thiếu, thay đổi điều kiện hoặc phản hồi thiên lệch. Việc nêu rõ các giới hạn này giúp người đọc hiểu kết quả áp dụng đến đâu.</p>
</section>
<section class="longform-section" id="trang-chu-6"><h2>6. Dữ liệu có trách nhiệm</h2>
<p>Phần này tập trung vào dữ liệu có trách nhiệm. Dữ liệu chỉ nên được thu thập khi có mục đích xác định, phạm vi sử dụng minh bạch và thời hạn lưu trữ phù hợp. Thông tin định danh cần được tách khỏi tập phân tích khi có thể, quyền truy cập phải được giới hạn, và bản công bố cần tránh tái nhận diện cá nhân. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Phạm vi của dữ liệu có trách nhiệm nên được diễn đạt bằng ngôn ngữ người tham gia có thể hiểu, kèm mục tiêu và giới hạn rõ ràng. Việc thống nhất thuật ngữ ngay từ đầu giúp các nhóm phối hợp tránh hiểu khác nhau về đối tượng, kết quả mong đợi và trách nhiệm thực hiện.</p>
<p>Đối với dữ liệu có trách nhiệm, nên xác định trước cách xử lý dữ liệu thiếu, câu trả lời mâu thuẫn và trường hợp ngoài dự kiến. Quy tắc xử lý cần được áp dụng nhất quán, đồng thời cho phép ghi nhận ngoại lệ có lý do thay vì âm thầm loại bỏ thông tin bất tiện.</p>
<p>Tài liệu vận hành cho dữ liệu có trách nhiệm cần tính đến khả năng gián đoạn, lỗi công cụ và việc người dùng sử dụng thiết bị khác nhau. Hướng dẫn thay thế nên đủ đơn giản để tiếp tục công việc an toàn mà không làm mất dữ liệu hoặc bỏ qua các bước kiểm soát cần thiết.</p>
<p>Sau mỗi chu kỳ dữ liệu có trách nhiệm, nhóm nên lưu bài học có thể áp dụng, quyết định sẽ thay đổi và vấn đề cần theo dõi ở lần tiếp theo. Cải tiến có trách nhiệm không chỉ ghi nhận điều thành công mà còn kiểm tra chi phí, tác dụng phụ và những nhóm chưa được phục vụ tốt.</p>
</section>
<section class="longform-section" id="trang-chu-7"><h2>7. Phương pháp giáo dục</h2>
<p>Phần này tập trung vào phương pháp giáo dục. Nghiên cứu giáo dục có thể xem xét trải nghiệm học tập, tính phù hợp của tài liệu, khả năng tiếp cận và cách phản hồi hỗ trợ người học. Những đánh giá này cần mô tả đối tượng và bối cảnh cụ thể, không biến quan sát hạn chế thành kết luận chung cho mọi trường học hoặc mọi người học. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Trước khi triển khai nội dung về phương pháp giáo dục, nhóm cần xác định ai chịu ảnh hưởng, câu hỏi cần trả lời và điều kiện nào có thể làm thay đổi cách tiếp cận. Phạm vi được ghi rõ giúp tránh mở rộng yêu cầu ngoài nguồn lực hoặc bằng chứng sẵn có.</p>
<p>Phương pháp cho phương pháp giáo dục cần mô tả cách lựa chọn dữ liệu, tiêu chí đưa vào hoặc loại trừ, công cụ sử dụng và cách ghi nhận thay đổi. Người đọc phải phân biệt được quy trình đã thực hiện với phương án mới chỉ được đề xuất.</p>
<p>Trong quá trình thực hiện phương pháp giáo dục, thông tin cập nhật cần phản ánh đúng tiến độ và những việc còn phụ thuộc. Khi có thay đổi về lịch, nhân sự hoặc phạm vi, người phụ trách nên ghi lại quyết định và thông báo cho các bên bị ảnh hưởng bằng kênh phù hợp.</p>
<p>Đánh giá phương pháp giáo dục cần dựa trên bằng chứng tương ứng với tuyên bố được đưa ra. Báo cáo nên phân biệt đầu ra đã hoàn thành, thay đổi quan sát được và tác động chưa đủ dữ liệu để kết luận; không suy diễn quan hệ nhân quả chỉ từ việc hai sự kiện xảy ra cùng lúc.</p>
</section>
<section class="longform-section" id="trang-chu-8"><h2>8. Năng lực số</h2>
<p>Phần này tập trung vào năng lực số. Năng lực số bao gồm khả năng sử dụng công cụ, đánh giá độ tin cậy của thông tin, quản lý danh tính trực tuyến và bảo vệ tài khoản. Hoạt động phát triển năng lực cần bắt đầu từ tình huống đời thực, giải thích rủi ro bằng ngôn ngữ dễ hiểu và khuyến khích thói quen an toàn. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khâu chuẩn bị nên tách nhu cầu đã được ghi nhận khỏi giả định ban đầu. Với năng lực số, mỗi giả định quan trọng cần có cách kiểm tra, người chịu trách nhiệm và mốc xem xét; nếu chưa thể kiểm chứng, tài liệu phải nêu rõ giới hạn thay vì biến dự đoán thành kết luận.</p>
<p>Khi thiết kế quy trình về năng lực số, cần phân công vai trò, điểm kiểm tra chất lượng và cách xử lý sai lệch. Một quy trình có thể giải thích được quan trọng hơn một danh sách bước dài; mỗi bước nên có mục đích, đầu vào và đầu ra rõ ràng.</p>
<p>Hoạt động liên quan đến năng lực số cần tôn trọng quyền tham gia và quyền từ chối của mỗi người. Hướng dẫn nên nêu rõ việc gì sẽ diễn ra, ai có thể xem dữ liệu, cách đặt câu hỏi và nơi tiếp nhận phản ánh nếu người tham gia thấy không an toàn hoặc chưa hiểu.</p>
<p>Khi tổng kết năng lực số, cần công bố phạm vi dữ liệu, thời điểm cập nhật, giới hạn đo lường và những câu hỏi còn bỏ ngỏ. Một kết quả chưa như kỳ vọng vẫn có thể đem lại bài học nếu phương pháp, sai lệch và điều kiện thực hiện được mô tả trung thực.</p>
</section>
<section class="longform-section" id="trang-chu-9"><h2>9. Đánh giá học thuật công bằng</h2>
<p>Phần này tập trung vào đánh giá học thuật công bằng. Một hoạt động khảo thí đáng tin cậy cần có mục tiêu đánh giá rõ, hướng dẫn dễ hiểu, quy tắc nhất quán và cơ chế xử lý sự cố. Thiết kế đề cần phù hợp với năng lực dự kiến đo lường, còn quy trình chấm và phúc khảo phải được tách biệt khi nghiệp vụ yêu cầu. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khi xem xét đánh giá học thuật công bằng, nên lập danh sách bên liên quan, rào cản tham gia, điều kiện tiếp cận và nguồn thông tin hợp pháp. Cách xác định phạm vi này giúp nhóm lựa chọn hoạt động phù hợp, đồng thời tránh yêu cầu người tham gia cung cấp thông tin vượt quá mục đích.</p>
<p>Các tiêu chí đánh giá đánh giá học thuật công bằng nên được xác định trước khi xem kết quả để hạn chế lựa chọn tiêu chí có lợi sau khi đã biết dữ liệu. Nếu tiêu chí phải thay đổi, nhóm cần ghi lý do, thời điểm và ảnh hưởng của thay đổi đối với kết luận.</p>
<p>Để duy trì chất lượng của đánh giá học thuật công bằng, nhóm cần lưu bằng chứng đủ dùng, cập nhật trạng thái có ngày tháng và tránh biến số liệu tạm thời thành kết quả cuối. Tài liệu nội bộ và nội dung công khai phải được phân biệt để không làm lộ thông tin cần bảo vệ.</p>
<p>Các chỉ số liên quan đến đánh giá học thuật công bằng chỉ có ý nghĩa khi có định nghĩa, nguồn và thời điểm đo nhất quán. Nếu chưa có số liệu đáng tin cậy, nên ghi rõ chưa có dữ liệu xác minh thay vì ước lượng để lấp chỗ trống hoặc tạo cảm giác chắc chắn.</p>
</section>
<section class="longform-section" id="trang-chu-10"><h2>10. An toàn cổng khảo thí</h2>
<p>Phần này tập trung vào an toàn cổng khảo thí. Cổng khảo thí trực tuyến phải kiểm soát quyền truy cập theo từng lượt thi, bảo vệ nội dung chưa công bố và ghi nhận các sự kiện cần thiết để giải quyết tranh chấp. Nhật ký kỹ thuật không nên chứa mật khẩu, mã định danh nhạy cảm hoặc nội dung bài làm vượt quá nhu cầu vận hành. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Một câu hỏi tốt về an toàn cổng khảo thí cần đủ cụ thể để hướng dẫn hành động nhưng đủ mở để tiếp nhận bằng chứng trái với kỳ vọng. Nhóm nên xác định điều gì nằm trong phạm vi, điều gì chưa thể trả lời và trường hợp nào cần chuyển sang đánh giá chuyên môn khác.</p>
<p>Tài liệu hóa phương pháp liên quan đến an toàn cổng khảo thí giúp người khác kiểm tra logic của quyết định mà không cần suy đoán. Cần ghi nguồn, phiên bản công cụ, điều kiện thực hiện và các ngoại lệ quan trọng; không được mô tả một quy trình lý tưởng như thể nó đã diễn ra.</p>
<p>Phối hợp trong an toàn cổng khảo thí nên có đầu mối chịu trách nhiệm, quy tắc chuyển giao và cách xử lý khi người phụ trách vắng mặt. Việc bàn giao cần giữ được bối cảnh quyết định, hạn chế phụ thuộc vào trí nhớ cá nhân và không chia sẻ quyền truy cập vượt nhu cầu công việc.</p>
<p>Bước rà soát cuối của an toàn cổng khảo thí nên hỏi điều gì đã được chứng minh, điều gì chỉ là nhận định và điều gì cần kiểm tra tiếp. Kết luận cần tương xứng với bằng chứng, đồng thời chỉ ra hành động tiếp theo và người chịu trách nhiệm nếu cần cải thiện.</p>
</section>
<section class="longform-section" id="trang-chu-11"><h2>11. Phản hồi và cơ hội cải thiện</h2>
<p>Phần này tập trung vào phản hồi và cơ hội cải thiện. Phản hồi có giá trị khi chỉ ra tiêu chí, bằng chứng và bước tiếp theo có thể thực hiện. Ngôn ngữ phản hồi nên tôn trọng người học, phân biệt lỗi cụ thể với nhận xét về con người, và cung cấp hướng cải thiện thay vì chỉ đưa ra kết luận đạt hoặc chưa đạt. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Để xác định nhu cầu liên quan đến phản hồi và cơ hội cải thiện, cần xem xét bối cảnh địa phương, năng lực thực hiện, thời gian và khả năng tiếp cận của người tham gia. Không nên suy rộng từ một phản ánh đơn lẻ; thông tin ban đầu cần được đối chiếu bằng nguồn độc lập khi phù hợp.</p>
<p>Việc lựa chọn phương pháp cho phản hồi và cơ hội cải thiện phải tương xứng với câu hỏi và năng lực thực hiện. Công cụ phức tạp không tự động tạo ra kết quả đáng tin cậy; điều quan trọng là dữ liệu phù hợp, tiêu chí nhất quán và khả năng giải thích các bước phân tích.</p>
<p>Khi có phản hồi về phản hồi và cơ hội cải thiện, nhóm cần ghi nhận nội dung, đánh giá mức độ ảnh hưởng và phản hồi trong thời hạn hợp lý. Không phải mọi đề xuất đều có thể được chấp nhận, nhưng lý do tiếp nhận hoặc từ chối nên rõ ràng và không gây bất lợi cho người góp ý.</p>
<p>Kết quả của phản hồi và cơ hội cải thiện cần được xem xét cùng các yếu tố có thể làm sai lệch như mẫu không đại diện, dữ liệu thiếu, thay đổi điều kiện hoặc phản hồi thiên lệch. Việc nêu rõ các giới hạn này giúp người đọc hiểu kết quả áp dụng đến đâu.</p>
</section>
<section class="longform-section" id="trang-chu-12"><h2>12. Dự án phát triển cộng đồng</h2>
<p>Phần này tập trung vào dự án phát triển cộng đồng. Dự án cộng đồng cần được xây dựng cùng những người chịu ảnh hưởng, thay vì chỉ dựa trên giả định của đơn vị tổ chức. Khâu chuẩn bị nên ghi nhận nhu cầu, nguồn lực hiện có, trở ngại tiếp cận và tiêu chí kết thúc, đồng thời để cộng đồng phản hồi về cách triển khai. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Phạm vi của dự án phát triển cộng đồng nên được diễn đạt bằng ngôn ngữ người tham gia có thể hiểu, kèm mục tiêu và giới hạn rõ ràng. Việc thống nhất thuật ngữ ngay từ đầu giúp các nhóm phối hợp tránh hiểu khác nhau về đối tượng, kết quả mong đợi và trách nhiệm thực hiện.</p>
<p>Đối với dự án phát triển cộng đồng, nên xác định trước cách xử lý dữ liệu thiếu, câu trả lời mâu thuẫn và trường hợp ngoài dự kiến. Quy tắc xử lý cần được áp dụng nhất quán, đồng thời cho phép ghi nhận ngoại lệ có lý do thay vì âm thầm loại bỏ thông tin bất tiện.</p>
<p>Tài liệu vận hành cho dự án phát triển cộng đồng cần tính đến khả năng gián đoạn, lỗi công cụ và việc người dùng sử dụng thiết bị khác nhau. Hướng dẫn thay thế nên đủ đơn giản để tiếp tục công việc an toàn mà không làm mất dữ liệu hoặc bỏ qua các bước kiểm soát cần thiết.</p>
<p>Sau mỗi chu kỳ dự án phát triển cộng đồng, nhóm nên lưu bài học có thể áp dụng, quyết định sẽ thay đổi và vấn đề cần theo dõi ở lần tiếp theo. Cải tiến có trách nhiệm không chỉ ghi nhận điều thành công mà còn kiểm tra chi phí, tác dụng phụ và những nhóm chưa được phục vụ tốt.</p>
</section>
<section class="longform-section" id="trang-chu-13"><h2>13. Tham vấn cộng đồng</h2>
<p>Phần này tập trung vào tham vấn cộng đồng. Tham vấn là quá trình lắng nghe có mục tiêu, không phải một bước hình thức để hợp thức hóa kế hoạch đã chốt. Câu hỏi cần trung lập, lựa chọn tham gia phải thực sự tự nguyện và ý kiến trái chiều phải được ghi nhận cùng cách nhóm xử lý chúng. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Trước khi triển khai nội dung về tham vấn cộng đồng, nhóm cần xác định ai chịu ảnh hưởng, câu hỏi cần trả lời và điều kiện nào có thể làm thay đổi cách tiếp cận. Phạm vi được ghi rõ giúp tránh mở rộng yêu cầu ngoài nguồn lực hoặc bằng chứng sẵn có.</p>
<p>Phương pháp cho tham vấn cộng đồng cần mô tả cách lựa chọn dữ liệu, tiêu chí đưa vào hoặc loại trừ, công cụ sử dụng và cách ghi nhận thay đổi. Người đọc phải phân biệt được quy trình đã thực hiện với phương án mới chỉ được đề xuất.</p>
<p>Trong quá trình thực hiện tham vấn cộng đồng, thông tin cập nhật cần phản ánh đúng tiến độ và những việc còn phụ thuộc. Khi có thay đổi về lịch, nhân sự hoặc phạm vi, người phụ trách nên ghi lại quyết định và thông báo cho các bên bị ảnh hưởng bằng kênh phù hợp.</p>
<p>Đánh giá tham vấn cộng đồng cần dựa trên bằng chứng tương ứng với tuyên bố được đưa ra. Báo cáo nên phân biệt đầu ra đã hoàn thành, thay đổi quan sát được và tác động chưa đủ dữ liệu để kết luận; không suy diễn quan hệ nhân quả chỉ từ việc hai sự kiện xảy ra cùng lúc.</p>
</section>
<section class="longform-section" id="trang-chu-14"><h2>14. Khả năng tiếp cận và hòa nhập</h2>
<p>Phần này tập trung vào khả năng tiếp cận và hòa nhập. Thông tin, chương trình và hoạt động nên được thiết kế để nhiều nhóm có thể tiếp cận, kể cả người dùng thiết bị yếu, người có nhu cầu hỗ trợ hoặc người chưa quen với quy trình số. Khả năng tiếp cận cần được kiểm tra từ khâu thiết kế, không chỉ bổ sung sau khi phát sinh phản ánh. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khâu chuẩn bị nên tách nhu cầu đã được ghi nhận khỏi giả định ban đầu. Với khả năng tiếp cận và hòa nhập, mỗi giả định quan trọng cần có cách kiểm tra, người chịu trách nhiệm và mốc xem xét; nếu chưa thể kiểm chứng, tài liệu phải nêu rõ giới hạn thay vì biến dự đoán thành kết luận.</p>
<p>Khi thiết kế quy trình về khả năng tiếp cận và hòa nhập, cần phân công vai trò, điểm kiểm tra chất lượng và cách xử lý sai lệch. Một quy trình có thể giải thích được quan trọng hơn một danh sách bước dài; mỗi bước nên có mục đích, đầu vào và đầu ra rõ ràng.</p>
<p>Hoạt động liên quan đến khả năng tiếp cận và hòa nhập cần tôn trọng quyền tham gia và quyền từ chối của mỗi người. Hướng dẫn nên nêu rõ việc gì sẽ diễn ra, ai có thể xem dữ liệu, cách đặt câu hỏi và nơi tiếp nhận phản ánh nếu người tham gia thấy không an toàn hoặc chưa hiểu.</p>
<p>Khi tổng kết khả năng tiếp cận và hòa nhập, cần công bố phạm vi dữ liệu, thời điểm cập nhật, giới hạn đo lường và những câu hỏi còn bỏ ngỏ. Một kết quả chưa như kỳ vọng vẫn có thể đem lại bài học nếu phương pháp, sai lệch và điều kiện thực hiện được mô tả trung thực.</p>
</section>
<section class="longform-section" id="trang-chu-15"><h2>15. Giáo dục phù hợp độ tuổi</h2>
<p>Phần này tập trung vào giáo dục phù hợp độ tuổi. Với hoạt động liên quan đến trẻ em và thanh thiếu niên, ngôn ngữ, bài tập và cách thu thập dữ liệu phải phù hợp với độ tuổi. Cần giải thích quyền từ chối, kênh hỗ trợ và ranh giới riêng tư, đồng thời có quy trình chuyển tiếp khi xuất hiện dấu hiệu cần bảo vệ thêm. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Khi xem xét giáo dục phù hợp độ tuổi, nên lập danh sách bên liên quan, rào cản tham gia, điều kiện tiếp cận và nguồn thông tin hợp pháp. Cách xác định phạm vi này giúp nhóm lựa chọn hoạt động phù hợp, đồng thời tránh yêu cầu người tham gia cung cấp thông tin vượt quá mục đích.</p>
<p>Các tiêu chí đánh giá giáo dục phù hợp độ tuổi nên được xác định trước khi xem kết quả để hạn chế lựa chọn tiêu chí có lợi sau khi đã biết dữ liệu. Nếu tiêu chí phải thay đổi, nhóm cần ghi lý do, thời điểm và ảnh hưởng của thay đổi đối với kết luận.</p>
<p>Để duy trì chất lượng của giáo dục phù hợp độ tuổi, nhóm cần lưu bằng chứng đủ dùng, cập nhật trạng thái có ngày tháng và tránh biến số liệu tạm thời thành kết quả cuối. Tài liệu nội bộ và nội dung công khai phải được phân biệt để không làm lộ thông tin cần bảo vệ.</p>
<p>Các chỉ số liên quan đến giáo dục phù hợp độ tuổi chỉ có ý nghĩa khi có định nghĩa, nguồn và thời điểm đo nhất quán. Nếu chưa có số liệu đáng tin cậy, nên ghi rõ chưa có dữ liệu xác minh thay vì ước lượng để lấp chỗ trống hoặc tạo cảm giác chắc chắn.</p>
</section>
<section class="longform-section" id="trang-chu-16"><h2>16. Môi trường và phát triển bền vững</h2>
<p>Phần này tập trung vào môi trường và phát triển bền vững. Các sáng kiến về môi trường cần mô tả vấn đề tại địa bàn, lựa chọn hành động khả thi và tiêu chí theo dõi có thể kiểm tra. Không nên sử dụng khẩu hiệu xanh thay cho bằng chứng, cũng không công bố tác động môi trường nếu chưa nêu phương pháp đo hoặc giới hạn đánh giá. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Một câu hỏi tốt về môi trường và phát triển bền vững cần đủ cụ thể để hướng dẫn hành động nhưng đủ mở để tiếp nhận bằng chứng trái với kỳ vọng. Nhóm nên xác định điều gì nằm trong phạm vi, điều gì chưa thể trả lời và trường hợp nào cần chuyển sang đánh giá chuyên môn khác.</p>
<p>Tài liệu hóa phương pháp liên quan đến môi trường và phát triển bền vững giúp người khác kiểm tra logic của quyết định mà không cần suy đoán. Cần ghi nguồn, phiên bản công cụ, điều kiện thực hiện và các ngoại lệ quan trọng; không được mô tả một quy trình lý tưởng như thể nó đã diễn ra.</p>
<p>Phối hợp trong môi trường và phát triển bền vững nên có đầu mối chịu trách nhiệm, quy tắc chuyển giao và cách xử lý khi người phụ trách vắng mặt. Việc bàn giao cần giữ được bối cảnh quyết định, hạn chế phụ thuộc vào trí nhớ cá nhân và không chia sẻ quyền truy cập vượt nhu cầu công việc.</p>
<p>Bước rà soát cuối của môi trường và phát triển bền vững nên hỏi điều gì đã được chứng minh, điều gì chỉ là nhận định và điều gì cần kiểm tra tiếp. Kết luận cần tương xứng với bằng chứng, đồng thời chỉ ra hành động tiếp theo và người chịu trách nhiệm nếu cần cải thiện.</p>
</section>
<section class="longform-section" id="trang-chu-17"><h2>17. Chuyển đổi số có trách nhiệm</h2>
<p>Phần này tập trung vào chuyển đổi số có trách nhiệm. Chuyển đổi số cần giải quyết một nhu cầu thực thay vì số hóa mọi quy trình chỉ vì công nghệ sẵn có. Trước khi triển khai công cụ mới, cần cân nhắc chi phí vận hành, kỹ năng người sử dụng, khả năng tương thích, bảo mật, tính liên tục và phương án dự phòng khi hệ thống không sẵn sàng. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Để xác định nhu cầu liên quan đến chuyển đổi số có trách nhiệm, cần xem xét bối cảnh địa phương, năng lực thực hiện, thời gian và khả năng tiếp cận của người tham gia. Không nên suy rộng từ một phản ánh đơn lẻ; thông tin ban đầu cần được đối chiếu bằng nguồn độc lập khi phù hợp.</p>
<p>Việc lựa chọn phương pháp cho chuyển đổi số có trách nhiệm phải tương xứng với câu hỏi và năng lực thực hiện. Công cụ phức tạp không tự động tạo ra kết quả đáng tin cậy; điều quan trọng là dữ liệu phù hợp, tiêu chí nhất quán và khả năng giải thích các bước phân tích.</p>
<p>Khi có phản hồi về chuyển đổi số có trách nhiệm, nhóm cần ghi nhận nội dung, đánh giá mức độ ảnh hưởng và phản hồi trong thời hạn hợp lý. Không phải mọi đề xuất đều có thể được chấp nhận, nhưng lý do tiếp nhận hoặc từ chối nên rõ ràng và không gây bất lợi cho người góp ý.</p>
<p>Kết quả của chuyển đổi số có trách nhiệm cần được xem xét cùng các yếu tố có thể làm sai lệch như mẫu không đại diện, dữ liệu thiếu, thay đổi điều kiện hoặc phản hồi thiên lệch. Việc nêu rõ các giới hạn này giúp người đọc hiểu kết quả áp dụng đến đâu.</p>
</section>
<section class="longform-section" id="trang-chu-18"><h2>18. Công bố và chia sẻ tri thức</h2>
<p>Phần này tập trung vào công bố và chia sẻ tri thức. Công bố có trách nhiệm giúp người đọc phân biệt kết quả đã xác minh, diễn giải của tác giả và câu hỏi còn bỏ ngỏ. Tài liệu cần nêu nguồn, phạm vi áp dụng, ngày cập nhật khi phù hợp và điều kiện tái sử dụng; quyền riêng tư hoặc quyền tác giả có thể giới hạn việc công khai toàn văn. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Phạm vi của công bố và chia sẻ tri thức nên được diễn đạt bằng ngôn ngữ người tham gia có thể hiểu, kèm mục tiêu và giới hạn rõ ràng. Việc thống nhất thuật ngữ ngay từ đầu giúp các nhóm phối hợp tránh hiểu khác nhau về đối tượng, kết quả mong đợi và trách nhiệm thực hiện.</p>
<p>Đối với công bố và chia sẻ tri thức, nên xác định trước cách xử lý dữ liệu thiếu, câu trả lời mâu thuẫn và trường hợp ngoài dự kiến. Quy tắc xử lý cần được áp dụng nhất quán, đồng thời cho phép ghi nhận ngoại lệ có lý do thay vì âm thầm loại bỏ thông tin bất tiện.</p>
<p>Tài liệu vận hành cho công bố và chia sẻ tri thức cần tính đến khả năng gián đoạn, lỗi công cụ và việc người dùng sử dụng thiết bị khác nhau. Hướng dẫn thay thế nên đủ đơn giản để tiếp tục công việc an toàn mà không làm mất dữ liệu hoặc bỏ qua các bước kiểm soát cần thiết.</p>
<p>Sau mỗi chu kỳ công bố và chia sẻ tri thức, nhóm nên lưu bài học có thể áp dụng, quyết định sẽ thay đổi và vấn đề cần theo dõi ở lần tiếp theo. Cải tiến có trách nhiệm không chỉ ghi nhận điều thành công mà còn kiểm tra chi phí, tác dụng phụ và những nhóm chưa được phục vụ tốt.</p>
</section>
<section class="longform-section" id="trang-chu-19"><h2>19. Tài liệu học thuật dễ sử dụng</h2>
<p>Phần này tập trung vào tài liệu học thuật dễ sử dụng. Tài liệu nên có cấu trúc nhất quán, tiêu đề mô tả đúng nội dung, định dạng có thể đọc trên nhiều thiết bị và hướng dẫn sử dụng rõ ràng. Với bản tải xuống, cần kiểm tra tên tệp, phiên bản, quyền truy cập và việc tài liệu có chứa thông tin cá nhân hoặc nội dung chưa được phép công bố hay không. Các nội dung dưới đây là định hướng chuyên môn; kế hoạch cụ thể cần được phê duyệt và điều chỉnh theo bối cảnh thực tế.</p>
<p>Trước khi triển khai nội dung về tài liệu học thuật dễ sử dụng, nhóm cần xác định ai chịu ảnh hưởng, câu hỏi cần trả lời và điều kiện nào có thể làm thay đổi cách tiếp cận. Phạm vi được ghi rõ giúp tránh mở rộng yêu cầu ngoài nguồn lực hoặc bằng chứng sẵn có.</p>
<p>Phương pháp cho tài liệu học thuật dễ sử dụng cần mô tả cách lựa chọn dữ liệu, tiêu chí đưa vào hoặc loại trừ, công cụ sử dụng và cách ghi nhận thay đổi. Người đọc phải phân biệt được quy trình đã thực hiện với phương án mới chỉ được đề xuất.</p>
<p>Trong quá trình thực hiện tài liệu học thuật dễ sử dụng, thông tin cập nhật cần phản ánh đúng tiến độ và những việc còn phụ thuộc. Khi có thay đổi về lịch, nhân sự hoặc phạm vi, người phụ trách nên ghi lại quyết định và thông báo cho các bên bị ảnh hưởng bằng kênh phù hợp.</p>
<p>Đánh giá tài liệu học thuật dễ sử dụng cần dựa trên bằng chứng tương ứng với tuyên bố được đưa ra. Báo cáo nên phân biệt đầu ra đã hoàn thành, thay đổi quan sát được và tác động chưa đủ dữ liệu để kết luận; không suy diễn quan hệ nhân quả chỉ từ việc hai sự kiện xảy ra cùng lúc.</p>
</section>','<section class="longform-section" id="home-1"><h2>1. Applied scientific research</h2>
<p>This section focuses on applied scientific research. Applied research starts with a clear question, an honestly described context, and methods proportionate to the available resources. The Center’s approach helps readers understand why a question matters, what evidence is needed, and which limitations must remain visible. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Before work on applied scientific research begins, the team should identify affected people, the question to answer, and the conditions that could change the approach. A clear scope prevents requests from expanding beyond available resources or the evidence that can reasonably be obtained.</p>
<p>Methods for applied scientific research should explain how evidence is selected, which inclusion or exclusion criteria apply, what tools are used, and how changes are recorded. Readers must be able to distinguish procedures actually followed from options that were only proposed.</p>
<p>During work on applied scientific research, updates should accurately describe progress and unresolved dependencies. When schedules, staffing, or scope change, the responsible person should record the decision and notify affected parties through an appropriate channel.</p>
<p>Evaluation of applied scientific research should use evidence proportionate to the claim being made. Reports should distinguish completed outputs, observed changes, and impacts that cannot yet be established; correlation alone must not be presented as proof of causation.</p>
</section>
<section class="longform-section" id="home-2"><h2>2. Questions and scope</h2>
<p>This section focuses on questions and scope. A useful study does not need an expansive scope. Defining its question, population, timeframe, and operating conditions helps a team focus on what can be examined and avoid promising conclusions that the evidence cannot support. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Preparation should separate documented needs from initial assumptions. For questions and scope, each important assumption needs a way to check it, an accountable person, and a review point; when verification is not possible, the limitation should be stated rather than turning a prediction into a conclusion.</p>
<p>A process for questions and scope needs assigned responsibilities, quality checkpoints, and a way to handle deviations. An explainable workflow matters more than a long checklist; each step should have a clear purpose, input, and expected output.</p>
<p>Activities related to questions and scope must respect each person&#x27;s ability to participate or decline. Instructions should explain what will happen, who may see the data, how to ask questions, and where to raise concerns if a participant feels unsafe or confused.</p>
<p>A review of questions and scope should disclose the evidence scope, update date, measurement limits, and unanswered questions. A result that falls short of expectations can still be useful if the method, deviations, and operating conditions are described honestly.</p>
</section>
<section class="longform-section" id="home-3"><h2>3. Literature review</h2>
<p>This section focuses on literature review. A literature review locates a question within existing concepts, methods, and debates. References should be traceable, primary evidence should be distinguished from commentary, and a team should never cite a work it has not actually examined or verified. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Reviewing literature review should include the people involved, barriers to participation, access conditions, and lawful information sources. This scoping work helps teams choose proportionate activities while avoiding requests for personal information that exceeds the stated purpose.</p>
<p>Evaluation criteria for literature review should be defined before results are reviewed, reducing the risk of selecting favorable criteria after the evidence is known. If criteria change, record the reason, timing, and effect on any conclusions.</p>
<p>To maintain the quality of literature review, teams should retain proportionate evidence, date status updates, and avoid presenting provisional figures as final results. Internal records must be distinguished from public material so protected information is not exposed.</p>
<p>Metrics for literature review are meaningful only when their definitions, sources, and measurement dates are consistent. If reliable figures are unavailable, state that evidence has not been verified rather than estimating values to fill a gap or create false certainty.</p>
</section>
<section class="longform-section" id="home-4"><h2>4. Methods and reproducibility</h2>
<p>This section focuses on methods and reproducibility. Methods should describe how work was conducted, how evidence was selected, how analysis proceeded, and what changed along the way. Not every project can be fully replicated, but documenting decisions and limitations makes its reasoning easier to scrutinize. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>A useful question about methods and reproducibility should be specific enough to guide action yet open enough to accommodate evidence that challenges expectations. Teams should state what is in scope, what cannot yet be answered, and when another form of professional review is needed.</p>
<p>Documenting methods for methods and reproducibility lets others examine the reasoning without guessing. Record sources, tool versions, operating conditions, and meaningful exceptions; never describe an idealized procedure as if it had actually taken place.</p>
<p>Coordination for methods and reproducibility should identify an accountable contact, handover rules, and arrangements for absences. A handover should preserve decision context, reduce dependence on personal memory, and avoid sharing access beyond what the work requires.</p>
<p>The final review of methods and reproducibility should ask what has been demonstrated, what remains an interpretation, and what needs further checking. Conclusions must match the evidence and identify practical next steps and accountable owners where improvement is needed.</p>
</section>
<section class="longform-section" id="home-5"><h2>5. Research ethics</h2>
<p>This section focuses on research ethics. Research ethics begins with the question itself, consent, identity protection, and the possible effects on participants. Work involving minors or people in vulnerable situations requires safeguards suited to that context; silence must not be treated as consent. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Needs related to research ethics should be considered in light of local context, capacity, timing, and participant access. A single comment should not be generalized without support; initial information should be compared with independent sources when that is appropriate and feasible.</p>
<p>The method chosen for research ethics should fit the question and the team&#x27;s capacity. A complex tool does not automatically produce trustworthy results; suitable evidence, consistent criteria, and explainable analysis are more important.</p>
<p>When feedback about research ethics arrives, the team should record it, assess its impact, and respond within a reasonable period. Not every suggestion can be accepted, but the reason for accepting or declining it should be clear and should not penalize the person who raised it.</p>
<p>Results for research ethics should be considered alongside possible sources of bias, such as an unrepresentative sample, missing data, changed conditions, or selective feedback. Stating these limits helps readers understand where the findings can reasonably be applied.</p>
</section>
<section class="longform-section" id="home-6"><h2>6. Responsible data</h2>
<p>This section focuses on responsible data. Data should be collected only for a defined purpose, with transparent uses and a proportionate retention period. Identifiers should be separated from analytical datasets where feasible, access should be limited, and published material should not make individuals re-identifiable. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>The scope of responsible data should use language participants can understand and state its purpose and limits. Agreeing on terminology early helps teams avoid conflicting interpretations of the target group, intended outcomes, and each party&#x27;s responsibilities.</p>
<p>For responsible data, define in advance how missing data, conflicting responses, and unexpected cases will be handled. Apply the rules consistently while allowing justified exceptions to be recorded rather than silently discarding inconvenient information.</p>
<p>Operational guidance for responsible data should account for outages, tool failures, and differences in users&#x27; devices. A fallback process should let people continue safely without losing data or bypassing necessary safeguards.</p>
<p>After each cycle of responsible data, record lessons that can be used, decisions that will change, and questions to monitor next time. Responsible improvement considers not only successes but also costs, side effects, and groups that remain underserved.</p>
</section>
<section class="longform-section" id="home-7"><h2>7. Educational methods</h2>
<p>This section focuses on educational methods. Education research can examine learning experience, material suitability, accessibility, and the usefulness of feedback. Findings should describe their specific participants and context instead of turning limited observations into universal claims about every school or learner. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Before work on educational methods begins, the team should identify affected people, the question to answer, and the conditions that could change the approach. A clear scope prevents requests from expanding beyond available resources or the evidence that can reasonably be obtained.</p>
<p>Methods for educational methods should explain how evidence is selected, which inclusion or exclusion criteria apply, what tools are used, and how changes are recorded. Readers must be able to distinguish procedures actually followed from options that were only proposed.</p>
<p>During work on educational methods, updates should accurately describe progress and unresolved dependencies. When schedules, staffing, or scope change, the responsible person should record the decision and notify affected parties through an appropriate channel.</p>
<p>Evaluation of educational methods should use evidence proportionate to the claim being made. Reports should distinguish completed outputs, observed changes, and impacts that cannot yet be established; correlation alone must not be presented as proof of causation.</p>
</section>
<section class="longform-section" id="home-8"><h2>8. Digital capability</h2>
<p>This section focuses on digital capability. Digital capability includes using tools, evaluating information quality, managing online identity, and protecting accounts. Capacity-building should start with realistic situations, explain risks in accessible language, and reinforce practical habits rather than relying on technical terminology alone. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Preparation should separate documented needs from initial assumptions. For digital capability, each important assumption needs a way to check it, an accountable person, and a review point; when verification is not possible, the limitation should be stated rather than turning a prediction into a conclusion.</p>
<p>A process for digital capability needs assigned responsibilities, quality checkpoints, and a way to handle deviations. An explainable workflow matters more than a long checklist; each step should have a clear purpose, input, and expected output.</p>
<p>Activities related to digital capability must respect each person&#x27;s ability to participate or decline. Instructions should explain what will happen, who may see the data, how to ask questions, and where to raise concerns if a participant feels unsafe or confused.</p>
<p>A review of digital capability should disclose the evidence scope, update date, measurement limits, and unanswered questions. A result that falls short of expectations can still be useful if the method, deviations, and operating conditions are described honestly.</p>
</section>
<section class="longform-section" id="home-9"><h2>9. Fair academic assessment</h2>
<p>This section focuses on fair academic assessment. Trustworthy assessment needs clear objectives, understandable instructions, consistent rules, and a process for handling incidents. Questions should match the intended construct, while grading and review should be separated where the assessment process requires it. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Reviewing fair academic assessment should include the people involved, barriers to participation, access conditions, and lawful information sources. This scoping work helps teams choose proportionate activities while avoiding requests for personal information that exceeds the stated purpose.</p>
<p>Evaluation criteria for fair academic assessment should be defined before results are reviewed, reducing the risk of selecting favorable criteria after the evidence is known. If criteria change, record the reason, timing, and effect on any conclusions.</p>
<p>To maintain the quality of fair academic assessment, teams should retain proportionate evidence, date status updates, and avoid presenting provisional figures as final results. Internal records must be distinguished from public material so protected information is not exposed.</p>
<p>Metrics for fair academic assessment are meaningful only when their definitions, sources, and measurement dates are consistent. If reliable figures are unavailable, state that evidence has not been verified rather than estimating values to fill a gap or create false certainty.</p>
</section>
<section class="longform-section" id="home-10"><h2>10. Assessment portal security</h2>
<p>This section focuses on assessment portal security. An online assessment portal should authorize each attempt, protect unreleased assessment material, and record only the events needed to resolve disputes. Technical logs should not contain passwords, sensitive identifiers, or excessive copies of candidate responses. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>A useful question about assessment portal security should be specific enough to guide action yet open enough to accommodate evidence that challenges expectations. Teams should state what is in scope, what cannot yet be answered, and when another form of professional review is needed.</p>
<p>Documenting methods for assessment portal security lets others examine the reasoning without guessing. Record sources, tool versions, operating conditions, and meaningful exceptions; never describe an idealized procedure as if it had actually taken place.</p>
<p>Coordination for assessment portal security should identify an accountable contact, handover rules, and arrangements for absences. A handover should preserve decision context, reduce dependence on personal memory, and avoid sharing access beyond what the work requires.</p>
<p>The final review of assessment portal security should ask what has been demonstrated, what remains an interpretation, and what needs further checking. Conclusions must match the evidence and identify practical next steps and accountable owners where improvement is needed.</p>
</section>
<section class="longform-section" id="home-11"><h2>11. Feedback and improvement</h2>
<p>This section focuses on feedback and improvement. Feedback is useful when it names the criterion, points to evidence, and suggests a practical next step. It should respect learners, distinguish a specific error from a judgment about a person, and explain improvement opportunities instead of offering only a pass-or-fail label. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Needs related to feedback and improvement should be considered in light of local context, capacity, timing, and participant access. A single comment should not be generalized without support; initial information should be compared with independent sources when that is appropriate and feasible.</p>
<p>The method chosen for feedback and improvement should fit the question and the team&#x27;s capacity. A complex tool does not automatically produce trustworthy results; suitable evidence, consistent criteria, and explainable analysis are more important.</p>
<p>When feedback about feedback and improvement arrives, the team should record it, assess its impact, and respond within a reasonable period. Not every suggestion can be accepted, but the reason for accepting or declining it should be clear and should not penalize the person who raised it.</p>
<p>Results for feedback and improvement should be considered alongside possible sources of bias, such as an unrepresentative sample, missing data, changed conditions, or selective feedback. Stating these limits helps readers understand where the findings can reasonably be applied.</p>
</section>
<section class="longform-section" id="home-12"><h2>12. Community development projects</h2>
<p>This section focuses on community development projects. Community initiatives should be shaped with people affected by them, not solely around an organizer’s assumptions. Preparation should document needs, available resources, access barriers, and completion criteria while giving community members a meaningful way to comment on delivery. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>The scope of community development projects should use language participants can understand and state its purpose and limits. Agreeing on terminology early helps teams avoid conflicting interpretations of the target group, intended outcomes, and each party&#x27;s responsibilities.</p>
<p>For community development projects, define in advance how missing data, conflicting responses, and unexpected cases will be handled. Apply the rules consistently while allowing justified exceptions to be recorded rather than silently discarding inconvenient information.</p>
<p>Operational guidance for community development projects should account for outages, tool failures, and differences in users&#x27; devices. A fallback process should let people continue safely without losing data or bypassing necessary safeguards.</p>
<p>After each cycle of community development projects, record lessons that can be used, decisions that will change, and questions to monitor next time. Responsible improvement considers not only successes but also costs, side effects, and groups that remain underserved.</p>
</section>
<section class="longform-section" id="home-13"><h2>13. Community consultation</h2>
<p>This section focuses on community consultation. Consultation is purposeful listening, not a ceremonial step used to justify a plan already decided. Questions should be neutral, participation should be voluntary, and dissenting views should be recorded along with how the team considered them. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Before work on community consultation begins, the team should identify affected people, the question to answer, and the conditions that could change the approach. A clear scope prevents requests from expanding beyond available resources or the evidence that can reasonably be obtained.</p>
<p>Methods for community consultation should explain how evidence is selected, which inclusion or exclusion criteria apply, what tools are used, and how changes are recorded. Readers must be able to distinguish procedures actually followed from options that were only proposed.</p>
<p>During work on community consultation, updates should accurately describe progress and unresolved dependencies. When schedules, staffing, or scope change, the responsible person should record the decision and notify affected parties through an appropriate channel.</p>
<p>Evaluation of community consultation should use evidence proportionate to the claim being made. Reports should distinguish completed outputs, observed changes, and impacts that cannot yet be established; correlation alone must not be presented as proof of causation.</p>
</section>
<section class="longform-section" id="home-14"><h2>14. Accessibility and inclusion</h2>
<p>This section focuses on accessibility and inclusion. Information and activities should be designed for people using modest devices, people needing accommodations, and people unfamiliar with digital workflows. Accessibility is best considered from the start, rather than added only after a complaint reveals a barrier. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Preparation should separate documented needs from initial assumptions. For accessibility and inclusion, each important assumption needs a way to check it, an accountable person, and a review point; when verification is not possible, the limitation should be stated rather than turning a prediction into a conclusion.</p>
<p>A process for accessibility and inclusion needs assigned responsibilities, quality checkpoints, and a way to handle deviations. An explainable workflow matters more than a long checklist; each step should have a clear purpose, input, and expected output.</p>
<p>Activities related to accessibility and inclusion must respect each person&#x27;s ability to participate or decline. Instructions should explain what will happen, who may see the data, how to ask questions, and where to raise concerns if a participant feels unsafe or confused.</p>
<p>A review of accessibility and inclusion should disclose the evidence scope, update date, measurement limits, and unanswered questions. A result that falls short of expectations can still be useful if the method, deviations, and operating conditions are described honestly.</p>
</section>
<section class="longform-section" id="home-15"><h2>15. Age-appropriate learning</h2>
<p>This section focuses on age-appropriate learning. For work involving children and adolescents, language, activities, and data collection should fit the participant’s age. Teams should explain the right to decline, support channels, and privacy boundaries, with a safeguarding process when additional support appears necessary. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Reviewing age-appropriate learning should include the people involved, barriers to participation, access conditions, and lawful information sources. This scoping work helps teams choose proportionate activities while avoiding requests for personal information that exceeds the stated purpose.</p>
<p>Evaluation criteria for age-appropriate learning should be defined before results are reviewed, reducing the risk of selecting favorable criteria after the evidence is known. If criteria change, record the reason, timing, and effect on any conclusions.</p>
<p>To maintain the quality of age-appropriate learning, teams should retain proportionate evidence, date status updates, and avoid presenting provisional figures as final results. Internal records must be distinguished from public material so protected information is not exposed.</p>
<p>Metrics for age-appropriate learning are meaningful only when their definitions, sources, and measurement dates are consistent. If reliable figures are unavailable, state that evidence has not been verified rather than estimating values to fill a gap or create false certainty.</p>
</section>
<section class="longform-section" id="home-16"><h2>16. Environment and sustainability</h2>
<p>This section focuses on environment and sustainability. Environmental initiatives should describe the local issue, choose feasible actions, and set verifiable monitoring criteria. Green language cannot substitute for evidence, and environmental impact should not be claimed without explaining the measurement method or its limitations. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>A useful question about environment and sustainability should be specific enough to guide action yet open enough to accommodate evidence that challenges expectations. Teams should state what is in scope, what cannot yet be answered, and when another form of professional review is needed.</p>
<p>Documenting methods for environment and sustainability lets others examine the reasoning without guessing. Record sources, tool versions, operating conditions, and meaningful exceptions; never describe an idealized procedure as if it had actually taken place.</p>
<p>Coordination for environment and sustainability should identify an accountable contact, handover rules, and arrangements for absences. A handover should preserve decision context, reduce dependence on personal memory, and avoid sharing access beyond what the work requires.</p>
<p>The final review of environment and sustainability should ask what has been demonstrated, what remains an interpretation, and what needs further checking. Conclusions must match the evidence and identify practical next steps and accountable owners where improvement is needed.</p>
</section>
<section class="longform-section" id="home-17"><h2>17. Responsible digital transformation</h2>
<p>This section focuses on responsible digital transformation. Digital transformation should solve a real need rather than digitize every process simply because a tool exists. Before adopting technology, teams should consider operating cost, user skills, compatibility, security, continuity, and a fallback for service interruptions. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Needs related to responsible digital transformation should be considered in light of local context, capacity, timing, and participant access. A single comment should not be generalized without support; initial information should be compared with independent sources when that is appropriate and feasible.</p>
<p>The method chosen for responsible digital transformation should fit the question and the team&#x27;s capacity. A complex tool does not automatically produce trustworthy results; suitable evidence, consistent criteria, and explainable analysis are more important.</p>
<p>When feedback about responsible digital transformation arrives, the team should record it, assess its impact, and respond within a reasonable period. Not every suggestion can be accepted, but the reason for accepting or declining it should be clear and should not penalize the person who raised it.</p>
<p>Results for responsible digital transformation should be considered alongside possible sources of bias, such as an unrepresentative sample, missing data, changed conditions, or selective feedback. Stating these limits helps readers understand where the findings can reasonably be applied.</p>
</section>
<section class="longform-section" id="home-18"><h2>18. Publishing and knowledge sharing</h2>
<p>This section focuses on publishing and knowledge sharing. Responsible publication helps readers distinguish verified findings, author interpretation, and unanswered questions. Documents should identify sources, scope, and appropriate update information; privacy or copyright may restrict sharing a full text. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>The scope of publishing and knowledge sharing should use language participants can understand and state its purpose and limits. Agreeing on terminology early helps teams avoid conflicting interpretations of the target group, intended outcomes, and each party&#x27;s responsibilities.</p>
<p>For publishing and knowledge sharing, define in advance how missing data, conflicting responses, and unexpected cases will be handled. Apply the rules consistently while allowing justified exceptions to be recorded rather than silently discarding inconvenient information.</p>
<p>Operational guidance for publishing and knowledge sharing should account for outages, tool failures, and differences in users&#x27; devices. A fallback process should let people continue safely without losing data or bypassing necessary safeguards.</p>
<p>After each cycle of publishing and knowledge sharing, record lessons that can be used, decisions that will change, and questions to monitor next time. Responsible improvement considers not only successes but also costs, side effects, and groups that remain underserved.</p>
</section>
<section class="longform-section" id="home-19"><h2>19. Usable academic resources</h2>
<p>This section focuses on usable academic resources. Resources should have consistent structure, descriptive headings, device-friendly formats, and clear instructions. Downloadable files need checks for filename, version, access rights, and any personal information or content that has not been authorized for publication. The material below provides professional guidance; each specific plan should be approved and adapted to its actual context.</p>
<p>Before work on usable academic resources begins, the team should identify affected people, the question to answer, and the conditions that could change the approach. A clear scope prevents requests from expanding beyond available resources or the evidence that can reasonably be obtained.</p>
<p>Methods for usable academic resources should explain how evidence is selected, which inclusion or exclusion criteria apply, what tools are used, and how changes are recorded. Readers must be able to distinguish procedures actually followed from options that were only proposed.</p>
<p>During work on usable academic resources, updates should accurately describe progress and unresolved dependencies. When schedules, staffing, or scope change, the responsible person should record the decision and notify affected parties through an appropriate channel.</p>
<p>Evaluation of usable academic resources should use evidence proportionate to the claim being made. Reports should distinguish completed outputs, observed changes, and impacts that cannot yet be established; correlation alone must not be presented as proof of causation.</p>
</section>','home','Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First','Sky First Center for Research and Development','Tổng quan về nghiên cứu ứng dụng, dự án cộng đồng, khảo thí học thuật, công bố tri thức và nguyên tắc vận hành của Trung tâm.','An overview of applied research, community projects, academic assessment, knowledge publication, and the Center’s operating principles.',99,'published',1,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)
ON CONFLICT(slug) DO UPDATE SET
  title_vi=excluded.title_vi,title_en=excluded.title_en,summary_vi=excluded.summary_vi,summary_en=excluded.summary_en,
  content_vi=excluded.content_vi,content_en=excluded.content_en,page_group='home',seo_title_vi=excluded.seo_title_vi,
  seo_title_en=excluded.seo_title_en,seo_description_vi=excluded.seo_description_vi,seo_description_en=excluded.seo_description_en,
  sort_order=99,status='published',updated_at=CURRENT_TIMESTAMP;

-- END AUTO-APPLIED 0003_home_about_longform.sql
