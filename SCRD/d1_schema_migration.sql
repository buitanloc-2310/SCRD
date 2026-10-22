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
('hero_title_vi', 'Hệ sinh thái Nghiên cứu Khoa học, Khảo thí Học thuật và Phát triển Cộng đồng', 1),
('hero_title_en', 'Ecosystem for Scientific Research, Academic Assessment and Community Development', 1),
('hero_subtitle_vi', 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First xây dựng nền tảng tri thức chuẩn mực, thúc đẩy các chương trình nghiên cứu ứng dụng, khảo thí minh bạch và dự án phục vụ cộng đồng bền vững.', 1),
('hero_subtitle_en', 'Sky First Center for Research and Development builds a rigorous knowledge platform, advancing applied research programs, transparent academic assessment, and sustainable community initiatives.', 1),
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

-- Initial CMS Posts (Published Official Announcements + 1 Unlocked AI Draft Post)
INSERT OR IGNORE INTO cms_posts (id, slug, custom_path, title_vi, title_en, excerpt_vi, excerpt_en, content_vi, content_en, category, tags_json, display_author, is_ai_generated, is_locked, status, seo_title, seo_description, published_at) VALUES
('post_1', 'ra-mat-nen-tang-so-sky-first-center', '/tin-tuc-hoat-dong/ra-mat-nen-tang-so-sky-first-center',
 'Vận hành Hệ thống Thông tin và Quản trị Nghiên cứu Sky First Center',
 'Operating the Sky First Center Information and Research Governance System',
 'Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First đưa vào vận hành cổng thông tin tích hợp quản lý nghiên cứu khoa học, dự án cộng đồng và khảo thí học thuật.',
 'Sky First Center for Research and Development operates its integrated portal for scientific research, community projects, and academic assessment.',
 '<p>Nhằm chuẩn hóa quy trình quản lý khoa học và phục vụ cộng đồng, <strong>Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First</strong> triển khai nền tảng số hóa đồng bộ trên trình duyệt web.</p><p>Hệ thống tích hợp quy trình đăng ký tài khoản 5 bước với mã yêu cầu <code>SCRD-SFN-</code>, quản trị nội dung minh bạch và bảo vệ dữ liệu cá nhân theo chuẩn mực an toàn thông tin.</p>',
 '<p>To standardize scientific management and community service workflows, <strong>Sky First Center for Research and Development</strong> deploys a unified web platform.</p><p>The system integrates a 5-step account registration workflow with <code>SCRD-SFN-</code> tracking codes, transparent content management, and strict personal data protection.</p>',
 'Hoạt động Trung tâm', '["Hệ thống số", "Quản trị nghiên cứu", "Cộng đồng"]', 'Ban Biên tập Sky First', 0, 0, 'published',
 'Vận hành Hệ thống Thông tin Sky First Center', 'Thông báo chính thức về việc vận hành cổng thông tin Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', '2026-10-15T09:00:00Z'),

('post_2', 'quy-chuan-dang-ky-tai-khoan-va-bao-mat-dinh-danh', '/tin-tuc-hoat-dong/quy-chuan-dang-ky-tai-khoan-va-bao-mat-dinh-danh',
 'Hướng dẫn Quy chuẩn Đăng ký Tài khoản 5 Bước và Bảo vệ Dữ liệu Cá nhân',
 'Guidelines on the 5-Step Account Registration Standard and Personal Data Protection',
 'Quy trình xét duyệt tài khoản tại Trung tâm đảm bảo kiểm soát phân quyền chặt chẽ, bảo vệ người chưa thành niên và không tiết lộ dữ liệu định danh qua email.',
 'The account approval workflow ensures strict role-based access control, minor protection, and zero sensitive ID exposure in emails.',
 '<p>Mọi hồ sơ đăng ký tài khoản tại Trung tâm đều được cấp mã tra cứu duy nhất theo cấu trúc <code>SCRD-SFN-</code> kèm 10 chữ số ngẫu nhiên mật mã sau khi lưu thành công vào hệ thống. Người đăng ký có thể chủ động kiểm tra trạng thái xử lý trực tuyến mà không lộ thông tin nhạy cảm.</p>',
 '<p>Every account application at the Center is assigned a unique tracking code following the <code>SCRD-SFN-</code> + 10 cryptographically random digits format after database confirmation, allowing secure status lookup without exposing sensitive identity data.</p>',
 'Thông báo Học thuật', '["Bảo mật dữ liệu", "Tài khoản", "Quy chuẩn"]', 'Khối Quản trị Dữ liệu', 0, 0, 'published',
 'Quy chuẩn Đăng ký Tài khoản 5 Bước | Sky First Center', 'Hướng dẫn chi tiết quy trình đăng ký và bảo mật dữ liệu cá nhân tại Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First.', '2026-10-18T10:30:00Z'),

('post_3_ai', 'ai-draft-phuong-phap-danh-gia-tac-dong-cong-dong', '/tin-tuc-hoat-dong/phuong-phap-danh-gia-tac-dong-cong-dong',
 '[Bản nháp AI] Khung Phương pháp Đánh giá Tác động Dự án Phát triển Cộng đồng',
 '[AI Draft] Methodological Framework for Community Project Impact Assessment',
 'Bài viết do trợ lý AI khởi tạo tự động dưới dạng bản nháp để Quản trị viên rà soát, chỉnh sửa toàn diện tiêu đề, nội dung, slug và trạng thái trước khi xuất bản.',
 'AI-generated draft article saved as draft by default for Administrators to review and edit all fields before publication.',
 '<p>Bài viết này được hệ thống AI hỗ trợ tổng hợp nháp về phương pháp theo dõi tiến độ và đánh giá minh chứng trong các dự án cộng đồng. Quản trị viên có toàn quyền chỉnh sửa tiêu đề, mô tả, nội dung, chuyên mục, đường dẫn (slug), thẻ, ảnh đại diện, SEO và quyết định xuất bản hoặc gỡ xuất bản bất kỳ lúc nào.</p>',
 '<p>This draft article was synthesized by the AI assistant regarding milestone tracking and evidence evaluation in community projects. Administrators have full permissions to edit the title, description, body, category, slug, tags, featured image, SEO, and publication status at any time.</p>',
 'Nghiên cứu Khoa học', '["AI Draft", "Phương pháp luận", "Dự án cộng đồng"]', 'AI Editorial Assistant', 1, 0, 'draft',
 'Khung Phương pháp Đánh giá Tác động Cộng đồng', 'Bản nháp nghiên cứu phương pháp đánh giá tác động cộng đồng.', NULL);
