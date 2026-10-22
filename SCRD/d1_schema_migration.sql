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
('hero_subtitle_vi', 'Kết nối tri thức học thuật, khảo thí chuẩn hóa và sáng kiến cộng đồng bền vững. Nền tảng chính thức của Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', 1),
('hero_subtitle_en', 'Connecting academic knowledge, standardized assessment, and sustainable community initiatives. The official platform of Sky First Center for Research and Development.', 1),
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
<p>Trong phạm vi bản sắc và phạm vi hoạt động, Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First là tên gọi được sử dụng cho cổng thông tin chuyên môn này. Phạm vi nội dung tập trung vào nghiên cứu khoa học ứng dụng, phát triển cộng đồng, khảo thí và đánh giá học thuật, cùng việc công bố và tổ chức tài liệu phục vụ tri thức. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá bản sắc và phạm vi hoạt động, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-2"><h2>2. Sứ mệnh</h2>
<p>Trong phạm vi sứ mệnh, Sứ mệnh được thể hiện qua việc kết nối câu hỏi nghiên cứu với nhu cầu thực tế, xây dựng hoạt động cộng đồng có mục tiêu và tổ chức đánh giá học thuật theo quy trình rõ ràng. Một tuyên bố sứ mệnh chỉ có ý nghĩa khi được chuyển thành quyết định và thực hành có thể quan sát, kiểm tra và cải thiện. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá sứ mệnh, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-3"><h2>3. Tầm nhìn và nguyên tắc</h2>
<p>Trong phạm vi tầm nhìn và nguyên tắc, Tầm nhìn định hướng dài hạn nhưng không thay thế kế hoạch cụ thể hoặc bằng chứng về kết quả. Các nguyên tắc nền tảng gồm minh bạch, trách nhiệm học thuật, tôn trọng con người, sử dụng nguồn lực hợp lý, bảo vệ dữ liệu và sẵn sàng điều chỉnh khi đánh giá cho thấy cách làm hiện tại chưa phù hợp. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá tầm nhìn và nguyên tắc, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-4"><h2>4. Nghiên cứu và kiểm chứng</h2>
<p>Trong phạm vi nghiên cứu và kiểm chứng, Hoạt động nghiên cứu cần có câu hỏi, phạm vi, phương pháp, tiêu chí phân tích và giới hạn được nêu rõ. Việc kiểm chứng không đồng nghĩa với việc mọi kết quả đều chắc chắn; đó là quá trình cho phép người khác đánh giá bằng chứng, nhận diện sai số và xem xét cách diễn giải. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá nghiên cứu và kiểm chứng, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-5"><h2>5. Chuẩn mực đạo đức</h2>
<p>Trong phạm vi chuẩn mực đạo đức, Chuẩn mực đạo đức cần được xem xét ngay từ thiết kế chương trình. Việc tham gia phải có cơ sở đồng thuận phù hợp, lợi ích và rủi ro cần được giải thích rõ, còn thông tin nhận dạng chỉ được tiếp cận bởi người có nhiệm vụ. Bất cứ ngoại lệ nào cũng cần được đánh giá theo hoàn cảnh cụ thể. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá chuẩn mực đạo đức, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-6"><h2>6. Cơ cấu trách nhiệm</h2>
<p>Trong phạm vi cơ cấu trách nhiệm, Một cơ cấu trách nhiệm hiệu quả xác định ai đề xuất, ai thẩm định, ai phê duyệt và ai theo dõi việc thực hiện. Chức danh không tự động tạo ra thẩm quyền không giới hạn. Quyền thao tác trên dữ liệu và hệ thống số cần được cấp theo nhiệm vụ, rà soát định kỳ và thu hồi khi không còn cần thiết. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá cơ cấu trách nhiệm, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-7"><h2>7. Phối hợp chuyên môn</h2>
<p>Trong phạm vi phối hợp chuyên môn, Các nhóm chuyên môn cần có cách trao đổi quyết định, quản lý phiên bản và chuyển giao công việc rõ ràng. Khi nhiều nhóm cùng tham gia, phạm vi trách nhiệm và điểm phê duyệt phải được thống nhất để tránh khoảng trống hoặc trùng lặp. Tài liệu điều phối cần đủ rõ để người mới tiếp nhận có thể tiếp tục công việc. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá phối hợp chuyên môn, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-8"><h2>8. Quản trị chất lượng</h2>
<p>Trong phạm vi quản trị chất lượng, Quản trị chất lượng kết hợp tiêu chuẩn đầu vào, rà soát độc lập khi phù hợp, theo dõi lỗi và xác nhận việc sửa lỗi. Không phải mọi sản phẩm đều cần cùng một mức kiểm tra; cường độ rà soát nên tương ứng với rủi ro, tác động và mức độ nhạy cảm của dữ liệu. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá quản trị chất lượng, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-9"><h2>9. Quản lý xung đột lợi ích</h2>
<p>Trong phạm vi quản lý xung đột lợi ích, Xung đột lợi ích cần được nhận diện và xử lý minh bạch thay vì mặc định rằng người tham gia luôn khách quan. Khi có lợi ích cá nhân, quan hệ hoặc vai trò có thể ảnh hưởng đánh giá, cần khai báo và cân nhắc biện pháp như đổi người thẩm định, giới hạn quyền quyết định hoặc ghi nhận lý do xử lý. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá quản lý xung đột lợi ích, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-10"><h2>10. Nghiên cứu liên ngành</h2>
<p>Trong phạm vi nghiên cứu liên ngành, Các vấn đề cộng đồng thường liên quan đến giáo dục, công nghệ, môi trường, hành vi và điều kiện kinh tế xã hội. Nghiên cứu liên ngành cần làm rõ cách mỗi lĩnh vực đóng góp, dùng thuật ngữ nhất quán và tránh ghép các kết luận không tương thích chỉ để tạo ra một câu chuyện đơn giản. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá nghiên cứu liên ngành, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-11"><h2>11. Tham gia của cộng đồng</h2>
<p>Trong phạm vi tham gia của cộng đồng, Cộng đồng không chỉ là đối tượng nhận hỗ trợ mà còn là nguồn tri thức về nhu cầu, rào cản và điều kiện địa phương. Cơ chế tham gia phù hợp có thể gồm trao đổi, khảo sát, phản hồi sau hoạt động và tham gia đánh giá. Việc tham gia cần tự nguyện, dễ tiếp cận và không tạo kỳ vọng sai lệch. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá tham gia của cộng đồng, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-12"><h2>12. Thiết kế dự án có mục tiêu</h2>
<p>Trong phạm vi thiết kế dự án có mục tiêu, Mỗi dự án nên mô tả vấn đề cần giải quyết, nhóm hưởng lợi, hoạt động, nguồn lực, mốc thời gian và tiêu chí đánh giá. Các điều kiện tiên quyết cũng cần được nêu, bởi một kế hoạch có thể phụ thuộc vào địa điểm, nhân sự, sự chấp thuận hoặc tài trợ chưa được xác nhận. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá thiết kế dự án có mục tiêu, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-13"><h2>13. Đánh giá tác động thận trọng</h2>
<p>Trong phạm vi đánh giá tác động thận trọng, Đánh giá tác động phải phân biệt đầu ra trực tiếp với thay đổi dài hạn. Số hoạt động hoặc lượt tham gia không tự chứng minh rằng năng lực đã được cải thiện. Muốn nói về tác động, cần xác định chỉ báo phù hợp, thời điểm đo, nguồn dữ liệu, yếu tố gây nhiễu và giới hạn của kết luận. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá đánh giá tác động thận trọng, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-14"><h2>14. Khảo thí và đo lường năng lực</h2>
<p>Trong phạm vi khảo thí và đo lường năng lực, Một bài đánh giá chỉ hữu ích nếu nội dung, thời gian, cách chấm và cách diễn giải kết quả phù hợp với mục tiêu. Tính nhất quán cần được kiểm tra, nhưng tính công bằng cũng đòi hỏi xem xét khả năng tiếp cận, ngôn ngữ câu hỏi và những điều kiện không liên quan đến năng lực đang đo. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá khảo thí và đo lường năng lực, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-15"><h2>15. Bảo vệ tính toàn vẹn kỳ thi</h2>
<p>Trong phạm vi bảo vệ tính toàn vẹn kỳ thi, Tính toàn vẹn kỳ thi phụ thuộc vào phân quyền, bảo vệ câu hỏi, ghi nhận trạng thái bài thi và xử lý sự cố có quy trình. Hệ thống cần phân biệt bản nháp, bản lưu được máy chủ xác nhận và bài đã nộp. Người dự thi nên nhận thông báo rõ ràng khi mất kết nối hoặc khi cần thực hiện lại thao tác. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá bảo vệ tính toàn vẹn kỳ thi, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-16"><h2>16. Tính công bằng trong đánh giá</h2>
<p>Trong phạm vi tính công bằng trong đánh giá, Công bằng không có nghĩa là bỏ qua tiêu chuẩn; đó là áp dụng tiêu chuẩn phù hợp và nhất quán, đồng thời xử lý trường hợp ngoại lệ theo quy trình. Khi có khiếu nại, bằng chứng và lịch sử thao tác phải được xem xét bởi người có thẩm quyền, với cách thông báo tôn trọng và có thể hiểu được. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá tính công bằng trong đánh giá, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-17"><h2>17. Công bố kết quả và dữ liệu</h2>
<p>Trong phạm vi công bố kết quả và dữ liệu, Kết quả học thuật, dữ liệu nghiên cứu và báo cáo cá nhân có mức độ công khai khác nhau. Trước khi công bố, cần kiểm tra quyền sử dụng, sự đồng thuận, độ chính xác và nguy cơ nhận diện. Dữ liệu công khai nên được giới hạn ở phần cần thiết để người đọc hiểu kết quả mà không xâm phạm quyền riêng tư. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá công bố kết quả và dữ liệu, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-18"><h2>18. Thư viện tài liệu</h2>
<p>Trong phạm vi thư viện tài liệu, Một thư viện tài liệu tốt cần phân loại rõ, cung cấp thông tin mô tả đủ dùng, ghi nhận phiên bản và thể hiện quyền truy cập. Người dùng phải nhận biết tài liệu nào có thể tải, tài liệu nào chỉ xem và tài liệu nào không dành cho công chúng. Bản sửa đổi nên được quản lý để tránh nhầm lẫn phiên bản. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá thư viện tài liệu, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="gioi-thieu-19"><h2>19. Tiếp cận song ngữ</h2>
<p>Trong phạm vi tiếp cận song ngữ, Giao diện Việt–Anh nên giữ cùng ý nghĩa, không chỉ đổi nhãn menu. Thông báo lỗi, điều kiện đăng ký, các bước khảo thí và thông tin chính sách đều cần có bản dịch tương đương. Khi chưa có bản dịch đã rà soát, hệ thống cần thể hiện rõ tình trạng thay vì tạo nội dung dịch máy như thể đã được duyệt. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá tiếp cận song ngữ, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>', content_en='<section class="longform-section" id="about-1"><h2>1. Identity and scope</h2>
<p>Within the scope of identity and scope, Sky First Center for Research and Development is the name used for this professional information portal. Its stated subject areas are applied scientific research, community development, academic assessment, and the publication and organization of knowledge resources. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating identity and scope, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-2"><h2>2. Mission</h2>
<p>Within the scope of mission, The mission is expressed by connecting research questions with practical needs, designing purposeful community activities, and administering academic assessment through clear processes. A mission statement matters only when it informs observable decisions and practices that can be reviewed and improved. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating mission, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-3"><h2>3. Vision and principles</h2>
<p>Within the scope of vision and principles, A vision sets a long-term direction but does not replace concrete plans or evidence of results. Foundational principles include transparency, academic responsibility, respect for people, proportionate use of resources, data protection, and willingness to change when evaluation shows that a practice is unsuitable. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating vision and principles, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-4"><h2>4. Research and verification</h2>
<p>Within the scope of research and verification, Research needs a question, defined scope, method, analytical criteria, and explicit limitations. Verification does not mean that every result is certain; it makes it possible for others to assess the evidence, identify error, and examine interpretation. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating research and verification, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-5"><h2>5. Ethical standards</h2>
<p>Within the scope of ethical standards, Ethical standards should be considered during program design. Participation requires appropriate consent, benefits and risks should be explained, and identifying information should be accessible only to people with a legitimate role. Any exception needs assessment against the specific circumstances. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating ethical standards, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-6"><h2>6. Responsibility structure</h2>
<p>Within the scope of responsibility structure, An effective responsibility structure identifies who proposes, reviews, approves, and monitors work. A title does not create unlimited authority. Digital-system and data permissions should be tied to tasks, reviewed periodically, and withdrawn when they are no longer needed. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating responsibility structure, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-7"><h2>7. Professional coordination</h2>
<p>Within the scope of professional coordination, Specialized teams need clear ways to communicate decisions, manage versions, and hand work over. When several groups contribute, responsibilities and approval points should be agreed to avoid gaps or duplication. Coordination records should help a new participant continue work without relying on undocumented assumptions. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating professional coordination, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-8"><h2>8. Quality governance</h2>
<p>Within the scope of quality governance, Quality governance combines input standards, independent review where appropriate, issue tracking, and confirmation of fixes. Not every output needs identical scrutiny; review intensity should match risk, impact, and data sensitivity. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating quality governance, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-9"><h2>9. Conflict-of-interest management</h2>
<p>Within the scope of conflict-of-interest management, Conflicts of interest should be identified and managed rather than assuming that every participant is always impartial. When personal interests, relationships, or roles could influence a review, disclosure and mitigation may include an alternate reviewer, constrained decision authority, or a documented rationale. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating conflict-of-interest management, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-10"><h2>10. Interdisciplinary research</h2>
<p>Within the scope of interdisciplinary research, Community questions often involve education, technology, environment, behavior, and social conditions. Interdisciplinary work should explain each field’s contribution, use terms consistently, and avoid combining incompatible conclusions merely to produce a simple narrative. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating interdisciplinary research, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-11"><h2>11. Community participation</h2>
<p>Within the scope of community participation, Communities are not only recipients of support; they hold knowledge about needs, barriers, and local conditions. Suitable participation may include discussion, surveys, post-activity feedback, and evaluation. Participation should be voluntary, accessible, and free from misleading expectations. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating community participation, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-12"><h2>12. Purposeful project design</h2>
<p>Within the scope of purposeful project design, Each project should describe the problem, intended beneficiaries, activities, resources, milestones, and evaluation criteria. Dependencies should also be stated because delivery may depend on a location, staffing, approvals, or funding that has not been confirmed. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating purposeful project design, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-13"><h2>13. Careful impact assessment</h2>
<p>Within the scope of careful impact assessment, Impact evaluation distinguishes immediate outputs from long-term change. Activity counts or attendance do not by themselves prove improved capability. Impact claims require suitable indicators, measurement timing, data sources, confounders, and explicit limits on interpretation. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating careful impact assessment, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-14"><h2>14. Assessment and competency measurement</h2>
<p>Within the scope of assessment and competency measurement, An assessment is useful only when content, duration, scoring, and interpretation fit its objective. Consistency matters, while fairness also requires attention to accessibility, question language, and conditions unrelated to the competency being measured. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating assessment and competency measurement, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-15"><h2>15. Protecting exam integrity</h2>
<p>Within the scope of protecting exam integrity, Exam integrity depends on authorization, question protection, recorded attempt state, and a defined incident process. Systems should distinguish local drafts, server-confirmed saves, and submitted work. Candidates need clear guidance when connectivity fails or an action must be retried. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating protecting exam integrity, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-16"><h2>16. Fairness in assessment</h2>
<p>Within the scope of fairness in assessment, Fairness does not mean abandoning standards; it means applying suitable, consistent standards and handling exceptions through a defined process. Complaints should be reviewed by authorized people using evidence and event history, with respectful and understandable communication. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating fairness in assessment, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-17"><h2>17. Publishing results and data</h2>
<p>Within the scope of publishing results and data, Academic results, research datasets, and individual reports have different publication permissions. Before release, teams should check authorization, consent, accuracy, and re-identification risk. Public data should be limited to what readers need to understand the result without violating privacy. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating publishing results and data, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-18"><h2>18. Resource library</h2>
<p>Within the scope of resource library, A useful resource library has clear categories, meaningful descriptions, version information, and visible access rules. Users should understand which items can be downloaded, which are view-only, and which are not public. Revisions should be managed to prevent version confusion. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating resource library, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="about-19"><h2>19. Bilingual accessibility</h2>
<p>Within the scope of bilingual accessibility, A Vietnamese–English interface should preserve meaning, not merely translate menu labels. Errors, registration conditions, assessment steps, and policies all need equivalent versions. Where reviewed translation is unavailable, the site should show that status instead of presenting an unchecked machine translation as approved text. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating bilingual accessibility, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>',
    page_group='about', seo_title_vi='Giới thiệu Trung tâm | Sky First', seo_title_en='About the Center | Sky First',
    seo_description_vi='Thông tin tổng quan về phạm vi hoạt động, nguyên tắc chuyên môn, cách tổ chức công việc và trách nhiệm của Trung tâm.', seo_description_en='An overview of the Center’s scope, professional principles, working practices, and responsibilities.',
    sort_order=1, status='published', updated_at=CURRENT_TIMESTAMP
WHERE slug='tong-quan';

INSERT INTO cms_pages (id,slug,title_vi,title_en,summary_vi,summary_en,content_vi,content_en,page_group,seo_title_vi,seo_title_en,seo_description_vi,seo_description_en,sort_order,status,version,published_at,created_at,updated_at)
VALUES ('page_home_longform','trang-chu-noi-dung','Tổng quan nội dung Trung tâm','About the Center: Overview and Areas of Work','Tổng quan về nghiên cứu ứng dụng, dự án cộng đồng, khảo thí học thuật, công bố tri thức và nguyên tắc vận hành của Trung tâm.','An overview of applied research, community projects, academic assessment, knowledge publication, and the Center’s operating principles.','<section class="longform-section" id="trang-chu-1"><h2>1. Nghiên cứu khoa học ứng dụng</h2>
<p>Trong phạm vi nghiên cứu khoa học ứng dụng, Nghiên cứu khoa học cần bắt đầu từ câu hỏi rõ ràng, bối cảnh được mô tả trung thực và phương pháp phù hợp với nguồn lực thực tế. Trung tâm hướng tới cách tiếp cận giúp người đọc hiểu vì sao một câu hỏi đáng nghiên cứu, dữ liệu nào cần thu thập và giới hạn nào phải được công khai. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá nghiên cứu khoa học ứng dụng, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-2"><h2>2. Thiết kế câu hỏi và phạm vi</h2>
<p>Trong phạm vi thiết kế câu hỏi và phạm vi, Một đề tài có ích không nhất thiết phải có phạm vi lớn. Việc giới hạn câu hỏi, xác định đối tượng, thời gian và điều kiện nghiên cứu giúp nhóm thực hiện tập trung vào điều có thể kiểm chứng, tránh hứa hẹn kết quả vượt quá dữ liệu. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá thiết kế câu hỏi và phạm vi, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-3"><h2>3. Tổng quan tài liệu</h2>
<p>Trong phạm vi tổng quan tài liệu, Tổng quan tài liệu giúp người nghiên cứu nhận diện khái niệm, phương pháp và tranh luận đã có trước khi lựa chọn hướng tiếp cận. Nguồn tham khảo cần được ghi nhận rõ, phân biệt bằng chứng gốc với ý kiến bình luận, và không trích dẫn tài liệu chưa đọc hoặc chưa xác minh. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá tổng quan tài liệu, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-4"><h2>4. Phương pháp và khả năng tái lập</h2>
<p>Trong phạm vi phương pháp và khả năng tái lập, Phương pháp cần được mô tả đủ rõ để người khác hiểu cách thực hiện, tiêu chí lựa chọn dữ liệu, quy trình phân tích và các điều chỉnh phát sinh. Không phải dự án nào cũng có thể tái lập hoàn toàn, nhưng việc ghi lại quyết định và giới hạn sẽ tăng khả năng kiểm tra. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá phương pháp và khả năng tái lập, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-5"><h2>5. Đạo đức nghiên cứu</h2>
<p>Trong phạm vi đạo đức nghiên cứu, Đạo đức nghiên cứu bắt đầu từ cách đặt câu hỏi, xin sự đồng thuận, bảo vệ danh tính và cân nhắc khả năng gây ảnh hưởng đến người tham gia. Đối với trẻ vị thành niên hoặc nhóm dễ bị tổn thương, nhóm nghiên cứu cần có cơ chế bảo vệ phù hợp và không xem sự im lặng là đồng thuận. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá đạo đức nghiên cứu, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-6"><h2>6. Dữ liệu có trách nhiệm</h2>
<p>Trong phạm vi dữ liệu có trách nhiệm, Dữ liệu chỉ nên được thu thập khi có mục đích xác định, phạm vi sử dụng minh bạch và thời hạn lưu trữ phù hợp. Thông tin định danh cần được tách khỏi tập phân tích khi có thể, quyền truy cập phải được giới hạn, và bản công bố cần tránh tái nhận diện cá nhân. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá dữ liệu có trách nhiệm, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-7"><h2>7. Phương pháp giáo dục</h2>
<p>Trong phạm vi phương pháp giáo dục, Nghiên cứu giáo dục có thể xem xét trải nghiệm học tập, tính phù hợp của tài liệu, khả năng tiếp cận và cách phản hồi hỗ trợ người học. Những đánh giá này cần mô tả đối tượng và bối cảnh cụ thể, không biến quan sát hạn chế thành kết luận chung cho mọi trường học hoặc mọi người học. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá phương pháp giáo dục, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-8"><h2>8. Năng lực số</h2>
<p>Trong phạm vi năng lực số, Năng lực số bao gồm khả năng sử dụng công cụ, đánh giá độ tin cậy của thông tin, quản lý danh tính trực tuyến và bảo vệ tài khoản. Hoạt động phát triển năng lực cần bắt đầu từ tình huống đời thực, giải thích rủi ro bằng ngôn ngữ dễ hiểu và khuyến khích thói quen an toàn. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá năng lực số, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-9"><h2>9. Đánh giá học thuật công bằng</h2>
<p>Trong phạm vi đánh giá học thuật công bằng, Một hoạt động khảo thí đáng tin cậy cần có mục tiêu đánh giá rõ, hướng dẫn dễ hiểu, quy tắc nhất quán và cơ chế xử lý sự cố. Thiết kế đề cần phù hợp với năng lực dự kiến đo lường, còn quy trình chấm và phúc khảo phải được tách biệt khi nghiệp vụ yêu cầu. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá đánh giá học thuật công bằng, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-10"><h2>10. An toàn cổng khảo thí</h2>
<p>Trong phạm vi an toàn cổng khảo thí, Cổng khảo thí trực tuyến phải kiểm soát quyền truy cập theo từng lượt thi, bảo vệ nội dung chưa công bố và ghi nhận các sự kiện cần thiết để giải quyết tranh chấp. Nhật ký kỹ thuật không nên chứa mật khẩu, mã định danh nhạy cảm hoặc nội dung bài làm vượt quá nhu cầu vận hành. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá an toàn cổng khảo thí, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-11"><h2>11. Phản hồi và cơ hội cải thiện</h2>
<p>Trong phạm vi phản hồi và cơ hội cải thiện, Phản hồi có giá trị khi chỉ ra tiêu chí, bằng chứng và bước tiếp theo có thể thực hiện. Ngôn ngữ phản hồi nên tôn trọng người học, phân biệt lỗi cụ thể với nhận xét về con người, và cung cấp hướng cải thiện thay vì chỉ đưa ra kết luận đạt hoặc chưa đạt. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá phản hồi và cơ hội cải thiện, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-12"><h2>12. Dự án phát triển cộng đồng</h2>
<p>Trong phạm vi dự án phát triển cộng đồng, Dự án cộng đồng cần được xây dựng cùng những người chịu ảnh hưởng, thay vì chỉ dựa trên giả định của đơn vị tổ chức. Khâu chuẩn bị nên ghi nhận nhu cầu, nguồn lực hiện có, trở ngại tiếp cận và tiêu chí kết thúc, đồng thời để cộng đồng phản hồi về cách triển khai. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá dự án phát triển cộng đồng, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-13"><h2>13. Tham vấn cộng đồng</h2>
<p>Trong phạm vi tham vấn cộng đồng, Tham vấn là quá trình lắng nghe có mục tiêu, không phải một bước hình thức để hợp thức hóa kế hoạch đã chốt. Câu hỏi cần trung lập, lựa chọn tham gia phải thực sự tự nguyện và ý kiến trái chiều phải được ghi nhận cùng cách nhóm xử lý chúng. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá tham vấn cộng đồng, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-14"><h2>14. Khả năng tiếp cận và hòa nhập</h2>
<p>Trong phạm vi khả năng tiếp cận và hòa nhập, Thông tin, chương trình và hoạt động nên được thiết kế để nhiều nhóm có thể tiếp cận, kể cả người dùng thiết bị yếu, người có nhu cầu hỗ trợ hoặc người chưa quen với quy trình số. Khả năng tiếp cận cần được kiểm tra từ khâu thiết kế, không chỉ bổ sung sau khi phát sinh phản ánh. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá khả năng tiếp cận và hòa nhập, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-15"><h2>15. Giáo dục phù hợp độ tuổi</h2>
<p>Trong phạm vi giáo dục phù hợp độ tuổi, Với hoạt động liên quan đến trẻ em và thanh thiếu niên, ngôn ngữ, bài tập và cách thu thập dữ liệu phải phù hợp với độ tuổi. Cần giải thích quyền từ chối, kênh hỗ trợ và ranh giới riêng tư, đồng thời có quy trình chuyển tiếp khi xuất hiện dấu hiệu cần bảo vệ thêm. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá giáo dục phù hợp độ tuổi, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-16"><h2>16. Môi trường và phát triển bền vững</h2>
<p>Trong phạm vi môi trường và phát triển bền vững, Các sáng kiến về môi trường cần mô tả vấn đề tại địa bàn, lựa chọn hành động khả thi và tiêu chí theo dõi có thể kiểm tra. Không nên sử dụng khẩu hiệu xanh thay cho bằng chứng, cũng không công bố tác động môi trường nếu chưa nêu phương pháp đo hoặc giới hạn đánh giá. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá môi trường và phát triển bền vững, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-17"><h2>17. Chuyển đổi số có trách nhiệm</h2>
<p>Trong phạm vi chuyển đổi số có trách nhiệm, Chuyển đổi số cần giải quyết một nhu cầu thực thay vì số hóa mọi quy trình chỉ vì công nghệ sẵn có. Trước khi triển khai công cụ mới, cần cân nhắc chi phí vận hành, kỹ năng người sử dụng, khả năng tương thích, bảo mật, tính liên tục và phương án dự phòng khi hệ thống không sẵn sàng. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá chuyển đổi số có trách nhiệm, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-18"><h2>18. Công bố và chia sẻ tri thức</h2>
<p>Trong phạm vi công bố và chia sẻ tri thức, Công bố có trách nhiệm giúp người đọc phân biệt kết quả đã xác minh, diễn giải của tác giả và câu hỏi còn bỏ ngỏ. Tài liệu cần nêu nguồn, phạm vi áp dụng, ngày cập nhật khi phù hợp và điều kiện tái sử dụng; quyền riêng tư hoặc quyền tác giả có thể giới hạn việc công khai toàn văn. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá công bố và chia sẻ tri thức, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>
<section class="longform-section" id="trang-chu-19"><h2>19. Tài liệu học thuật dễ sử dụng</h2>
<p>Trong phạm vi tài liệu học thuật dễ sử dụng, Tài liệu nên có cấu trúc nhất quán, tiêu đề mô tả đúng nội dung, định dạng có thể đọc trên nhiều thiết bị và hướng dẫn sử dụng rõ ràng. Với bản tải xuống, cần kiểm tra tên tệp, phiên bản, quyền truy cập và việc tài liệu có chứa thông tin cá nhân hoặc nội dung chưa được phép công bố hay không. Nội dung được trình bày như định hướng chuyên môn và không thay thế cho kế hoạch được phê duyệt riêng của từng chương trình.</p>
<p>Ở bước xác định nhu cầu, nhóm phụ trách cần làm rõ vấn đề, đối tượng liên quan, điều kiện thực hiện và dữ liệu có thể thu thập hợp pháp. Những giả định chưa có bằng chứng phải được ghi nhận riêng để tránh bị hiểu thành sự thật đã xác minh.</p>
<p>Khi thiết kế cách làm, cần xác định người chịu trách nhiệm, tiêu chí chất lượng, mốc rà soát và phương án xử lý rủi ro. Cách tiếp cận phù hợp phải dễ giải thích cho người tham gia, tương xứng với nguồn lực và có thể điều chỉnh khi bối cảnh thay đổi.</p>
<p>Trong quá trình thực hiện, thông tin được ghi nhận cần đủ để giải thích quyết định nhưng không thu thập dữ liệu cá nhân dư thừa. Các bên liên quan nên có kênh phản hồi dễ tiếp cận; ý kiến khác biệt được xem xét trên cơ sở lý do và bằng chứng thay vì bị bỏ qua.</p>
<p>Khi đánh giá tài liệu học thuật dễ sử dụng, cần phân biệt điều đã hoàn thành, điều đang diễn ra và điều còn chờ xác minh. Báo cáo nên chỉ ra giới hạn, nguồn dữ liệu và bước tiếp theo có thể thực hiện. Nếu chưa có minh chứng, cách diễn đạt đúng là chưa đủ dữ liệu để kết luận.</p>
</section>','<section class="longform-section" id="home-1"><h2>1. Applied scientific research</h2>
<p>Within the scope of applied scientific research, Applied research starts with a clear question, an honestly described context, and methods proportionate to the available resources. The Center’s approach helps readers understand why a question matters, what evidence is needed, and which limitations must remain visible. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating applied scientific research, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-2"><h2>2. Questions and scope</h2>
<p>Within the scope of questions and scope, A useful study does not need an expansive scope. Defining its question, population, timeframe, and operating conditions helps a team focus on what can be examined and avoid promising conclusions that the evidence cannot support. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating questions and scope, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-3"><h2>3. Literature review</h2>
<p>Within the scope of literature review, A literature review locates a question within existing concepts, methods, and debates. References should be traceable, primary evidence should be distinguished from commentary, and a team should never cite a work it has not actually examined or verified. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating literature review, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-4"><h2>4. Methods and reproducibility</h2>
<p>Within the scope of methods and reproducibility, Methods should describe how work was conducted, how evidence was selected, how analysis proceeded, and what changed along the way. Not every project can be fully replicated, but documenting decisions and limitations makes its reasoning easier to scrutinize. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating methods and reproducibility, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-5"><h2>5. Research ethics</h2>
<p>Within the scope of research ethics, Research ethics begins with the question itself, consent, identity protection, and the possible effects on participants. Work involving minors or people in vulnerable situations requires safeguards suited to that context; silence must not be treated as consent. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating research ethics, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-6"><h2>6. Responsible data</h2>
<p>Within the scope of responsible data, Data should be collected only for a defined purpose, with transparent uses and a proportionate retention period. Identifiers should be separated from analytical datasets where feasible, access should be limited, and published material should not make individuals re-identifiable. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating responsible data, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-7"><h2>7. Educational methods</h2>
<p>Within the scope of educational methods, Education research can examine learning experience, material suitability, accessibility, and the usefulness of feedback. Findings should describe their specific participants and context instead of turning limited observations into universal claims about every school or learner. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating educational methods, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-8"><h2>8. Digital capability</h2>
<p>Within the scope of digital capability, Digital capability includes using tools, evaluating information quality, managing online identity, and protecting accounts. Capacity-building should start with realistic situations, explain risks in accessible language, and reinforce practical habits rather than relying on technical terminology alone. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating digital capability, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-9"><h2>9. Fair academic assessment</h2>
<p>Within the scope of fair academic assessment, Trustworthy assessment needs clear objectives, understandable instructions, consistent rules, and a process for handling incidents. Questions should match the intended construct, while grading and review should be separated where the assessment process requires it. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating fair academic assessment, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-10"><h2>10. Assessment portal security</h2>
<p>Within the scope of assessment portal security, An online assessment portal should authorize each attempt, protect unreleased assessment material, and record only the events needed to resolve disputes. Technical logs should not contain passwords, sensitive identifiers, or excessive copies of candidate responses. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating assessment portal security, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-11"><h2>11. Feedback and improvement</h2>
<p>Within the scope of feedback and improvement, Feedback is useful when it names the criterion, points to evidence, and suggests a practical next step. It should respect learners, distinguish a specific error from a judgment about a person, and explain improvement opportunities instead of offering only a pass-or-fail label. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating feedback and improvement, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-12"><h2>12. Community development projects</h2>
<p>Within the scope of community development projects, Community initiatives should be shaped with people affected by them, not solely around an organizer’s assumptions. Preparation should document needs, available resources, access barriers, and completion criteria while giving community members a meaningful way to comment on delivery. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating community development projects, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-13"><h2>13. Community consultation</h2>
<p>Within the scope of community consultation, Consultation is purposeful listening, not a ceremonial step used to justify a plan already decided. Questions should be neutral, participation should be voluntary, and dissenting views should be recorded along with how the team considered them. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating community consultation, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-14"><h2>14. Accessibility and inclusion</h2>
<p>Within the scope of accessibility and inclusion, Information and activities should be designed for people using modest devices, people needing accommodations, and people unfamiliar with digital workflows. Accessibility is best considered from the start, rather than added only after a complaint reveals a barrier. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating accessibility and inclusion, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-15"><h2>15. Age-appropriate learning</h2>
<p>Within the scope of age-appropriate learning, For work involving children and adolescents, language, activities, and data collection should fit the participant’s age. Teams should explain the right to decline, support channels, and privacy boundaries, with a safeguarding process when additional support appears necessary. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating age-appropriate learning, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-16"><h2>16. Environment and sustainability</h2>
<p>Within the scope of environment and sustainability, Environmental initiatives should describe the local issue, choose feasible actions, and set verifiable monitoring criteria. Green language cannot substitute for evidence, and environmental impact should not be claimed without explaining the measurement method or its limitations. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating environment and sustainability, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-17"><h2>17. Responsible digital transformation</h2>
<p>Within the scope of responsible digital transformation, Digital transformation should solve a real need rather than digitize every process simply because a tool exists. Before adopting technology, teams should consider operating cost, user skills, compatibility, security, continuity, and a fallback for service interruptions. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating responsible digital transformation, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-18"><h2>18. Publishing and knowledge sharing</h2>
<p>Within the scope of publishing and knowledge sharing, Responsible publication helps readers distinguish verified findings, author interpretation, and unanswered questions. Documents should identify sources, scope, and appropriate update information; privacy or copyright may restrict sharing a full text. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating publishing and knowledge sharing, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>
<section class="longform-section" id="home-19"><h2>19. Usable academic resources</h2>
<p>Within the scope of usable academic resources, Resources should have consistent structure, descriptive headings, device-friendly formats, and clear instructions. Downloadable files need checks for filename, version, access rights, and any personal information or content that has not been authorized for publication. This description is a professional orientation and does not replace a separately approved plan for any specific program.</p>
<p>At the needs-assessment stage, the responsible team should clarify the problem, affected groups, operating conditions, and evidence that can lawfully be collected. Assumptions without supporting evidence should be recorded separately so they are not mistaken for verified facts.</p>
<p>When designing an approach, teams should define ownership, quality criteria, review milestones, and risk responses. A suitable approach should be explainable to participants, proportionate to available resources, and adjustable when circumstances change.</p>
<p>During delivery, records should be sufficient to explain decisions without collecting unnecessary personal data. Stakeholders need an accessible feedback channel, and different views should be considered through reasons and evidence instead of being disregarded.</p>
<p>When evaluating usable academic resources, distinguish completed work, work in progress, and matters that remain unverified. Reports should identify limitations, sources, and practical next steps. When supporting evidence is missing, the accurate statement is that there is not yet enough information to conclude.</p>
</section>','home','Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First','Sky First Center for Research and Development','Tổng quan về nghiên cứu ứng dụng, dự án cộng đồng, khảo thí học thuật, công bố tri thức và nguyên tắc vận hành của Trung tâm.','An overview of applied research, community projects, academic assessment, knowledge publication, and the Center’s operating principles.',99,'published',1,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)
ON CONFLICT(slug) DO UPDATE SET
  title_vi=excluded.title_vi,title_en=excluded.title_en,summary_vi=excluded.summary_vi,summary_en=excluded.summary_en,
  content_vi=excluded.content_vi,content_en=excluded.content_en,page_group='home',seo_title_vi=excluded.seo_title_vi,
  seo_title_en=excluded.seo_title_en,seo_description_vi=excluded.seo_description_vi,seo_description_en=excluded.seo_description_en,
  sort_order=99,status='published',updated_at=CURRENT_TIMESTAMP;

-- END AUTO-APPLIED 0003_home_about_longform.sql
