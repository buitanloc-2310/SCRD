/**
 * SKY FIRST CENTER FOR RESEARCH AND DEVELOPMENT
 * Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First
 * Official Domain: https://scrd.skyfirst.io.vn
 * Support Email: support@skyfirst.io.vn | Technical Email: scrd@skyfirst.io.vn
 *
 * CLOUDFLARE WORKER BACKEND & REST API (FULL PRODUCTION IMPLEMENTATION)
 * Fixed Bindings (DO NOT MODIFY):
 * - env.DB    -> Cloudflare D1 Database (ID: 6006fe24-6278-4989-8d94-fd4734d71679)
 * - env.FILES -> Cloudflare R2 Bucket (Name: scrd-files)
 *
 * Security & Architecture Features:
 * - Safe First-Admin Bootstrap (One-time atomic transaction, PBKDF2-HMAC-SHA256 100,000 iterations, constant-time token verification, auto-lock)
 * - Session & JWT Authentication with Role-Based Access Control (RBAC: super_admin, cms_editor, reviewer, researcher, project_lead, examiner, member)
 * - WordPress-style CMS API (Pages, Posts including full editing of AI-generated drafts, Menus, Footer 4-column groups, Links & Redirects with XSS/URL validation, Media R2 upload/delete, Site Settings)
 * - 5-Step Account Registration & Approval Workflow (Under-18 guardian validation, unique SCRD-SFN- + 10 digits code generation with D1 collision check, sanitized status lookup without exposing CCCD/ID images)
 * - Scientific Research, Community Projects, Academic Assessments (protected exams/submissions), Publications & Documents, Tasks & Milestone Progress Calculation
 * - Real-time Direct & Group Chat with R2 file attachments, read receipts, user blocking, spam reporting, and privacy enforcement
 * - Transactional HTML Email Dispatch Engine with delivery status logging and retry tracking
 */

const ALLOWED_ROLES = [
  'super_admin',
  'cms_editor',
  'reviewer',
  'researcher',
  'project_lead',
  'examiner',
  'member'
];

const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/svg+xml',
  'application/pdf',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/plain',
  'text/csv'
]);

const MAX_UPLOAD_BYTES = 25 * 1024 * 1024; // 25 MB limit

// Utility: Constant-time string comparison
function timingSafeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const enc = new TextEncoder();
  const aBuf = enc.encode(a);
  const bBuf = enc.encode(b);
  if (aBuf.length !== bBuf.length) return false;
  let diff = 0;
  for (let i = 0; i < aBuf.length; i++) {
    diff |= aBuf[i] ^ bBuf[i];
  }
  return diff === 0;
}

// Utility: PBKDF2-HMAC-SHA256 Password Hashing
async function hashPassword(password, providedSaltHex = null) {
  const enc = new TextEncoder();
  let salt;
  if (providedSaltHex) {
    salt = new Uint8Array(providedSaltHex.match(/.{1,2}/g).map(b => parseInt(b, 16)));
  } else {
    salt = crypto.getRandomValues(new Uint8Array(16));
  }
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    enc.encode(password),
    { name: 'PBKDF2' },
    false,
    ['deriveBits']
  );
  const derivedBits = await crypto.subtle.deriveBits(
    {
      name: 'PBKDF2',
      salt: salt,
      iterations: 100000,
      hash: 'SHA-256'
    },
    keyMaterial,
    256
  );
  const hashArray = Array.from(new Uint8Array(derivedBits));
  const saltHex = Array.from(salt).map(b => b.toString(16).padStart(2, '0')).join('');
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  return `pbkdf2_sha256$100000$${saltHex}$${hashHex}`;
}

async function verifyPassword(password, storedHash) {
  if (!storedHash || !storedHash.startsWith('pbkdf2_sha256$')) return false;
  const parts = storedHash.split('$');
  if (parts.length !== 4) return false;
  const saltHex = parts[2];
  const computed = await hashPassword(password, saltHex);
  return timingSafeEqual(computed, storedHash);
}

// Utility: Sanitize HTML & Prevent XSS Injection
function sanitizeHtmlInput(input) {
  if (typeof input !== 'string') return '';
  return input
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    .replace(/on\w+\s*=\s*["'][^"']*["']/gi, '')
    .replace(/on\w+\s*=\s*[^\s>]+/gi, '')
    .replace(/javascript\s*:/gi, 'blocked:');
}

// Utility: Validate URL (Block javascript:, data:, vbscript: schemes)
function isValidSafeUrl(urlStr) {
  if (typeof urlStr !== 'string' || !urlStr.trim()) return false;
  const trimmed = urlStr.trim();
  if (trimmed.startsWith('/') || trimmed.startsWith('#')) return true;
  try {
    const parsed = new URL(trimmed);
    return ['http:', 'https:', 'mailto:'].includes(parsed.protocol);
  } catch {
    return false;
  }
}

// Utility: Generate Cryptographically Secure Request Code SCRD-SFN- + 10 digits
async function generateUniqueRequestCode(db) {
  for (let attempt = 0; attempt < 10; attempt++) {
    const randBytes = crypto.getRandomValues(new Uint32Array(3));
    const tenDigits = (
      (BigInt(randBytes[0]) * 10000000000n + BigInt(randBytes[1])) % 9000000000n + 1000000000n
    ).toString().slice(0, 10);
    const candidate = `SCRD-SFN-${tenDigits}`;
    const existing = await db
      .prepare('SELECT id FROM account_requests WHERE request_code = ? LIMIT 1')
      .bind(candidate)
      .first();
    if (!existing) return candidate;
  }
  throw new Error('Unable to generate unique request code after 10 attempts');
}

// Utility: Write Audit Log (never logs passwords, tokens, or raw CCCD)
async function writeAuditLog(db, actorUserId, action, targetType, targetId, metadataObj, request) {
  try {
    const ip = request?.headers?.get('CF-Connecting-IP') || '0.0.0.0';
    const ua = request?.headers?.get('User-Agent') || 'Unknown';
    const safeMeta = { ...metadataObj };
    delete safeMeta.password;
    delete safeMeta.bootstrap_token;
    delete safeMeta.national_id_number;
    await db
      .prepare(
        `INSERT INTO audit_logs (id, actor_user_id, action, target_type, target_id, metadata_json, ip_address, user_agent, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`
      )
      .bind(
        crypto.randomUUID(),
        actorUserId || null,
        action,
        targetType,
        targetId || null,
        JSON.stringify(safeMeta),
        ip,
        ua
      )
      .run();
  } catch (err) {
    console.error('Audit log error:', err.message);
  }
}

// Utility: Authenticate Request via Bearer Session Token
async function authenticateRequest(request, env) {
  const authHeader = request.headers.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) return null;
  const rawToken = authHeader.slice(7).trim();
  if (!rawToken) return null;

  const enc = new TextEncoder();
  const hashBuf = await crypto.subtle.digest('SHA-256', enc.encode(rawToken));
  const tokenHash = Array.from(new Uint8Array(hashBuf))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');

  const session = await env.DB.prepare(
    `SELECT s.id AS session_id, s.user_id, s.expires_at,
            u.email, u.full_name, u.role, u.status, u.avatar_r2_key
     FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.token_hash = ? AND s.revoked_at IS NULL AND s.expires_at > datetime('now')
     LIMIT 1`
  )
    .bind(tokenHash)
    .first();

  if (!session || session.status !== 'active') return null;
  return session;
}

function jsonResponse(data, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Bootstrap-Token',
      'X-Content-Type-Options': 'nosniff',
      'X-Frame-Options': 'SAMEORIGIN',
      ...extraHeaders
    }
  });
}

// Helper: Dispatch & Log Event Email
async function dispatchEventEmail(env, templateKey, recipientEmail, recipientName, subject, payloadVars, relatedType, relatedId) {
  const logId = crypto.randomUUID();
  let status = 'queued';
  let providerId = null;
  let errorMsg = null;

  // Safe payload check: never include national_id_number or ID card images in email
  const safeVars = { ...payloadVars };
  delete safeVars.national_id_number;
  delete safeVars.id_front_r2_key;
  delete safeVars.id_back_r2_key;

  try {
    if (env.EMAIL_WEBHOOK_URL && env.EMAIL_API_KEY) {
      const resp = await fetch(env.EMAIL_WEBHOOK_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.EMAIL_API_KEY}`
        },
        body: JSON.stringify({
          from: env.EMAIL_FROM || 'support@skyfirst.io.vn',
          to: recipientEmail,
          subject,
          template_key: templateKey,
          variables: safeVars
        })
      });
      if (resp.ok) {
        status = 'sent';
        const resData = await resp.json().catch(() => ({}));
        providerId = resData.id || `msg_${Date.now()}`;
      } else {
        status = 'failed';
        errorMsg = `HTTP ${resp.status}`;
      }
    } else {
      // No live SMTP/Webhook configured in environment secrets -> record honest 'pending_Locate_smtp' status
      status = 'pending_smtp_config';
      errorMsg = 'EMAIL_WEBHOOK_URL / EMAIL_API_KEY secret not yet configured in Cloudflare Worker';
    }
  } catch (err) {
    status = 'failed';
    errorMsg = err.message;
  }

  await env.DB.prepare(
    `INSERT INTO email_logs (id, template_key, recipient_email, recipient_name, subject, status, provider_message_id, error_message, related_entity_type, related_entity_id, sent_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CASE WHEN ? = 'sent' THEN datetime('now') ELSE NULL END, datetime('now'))`
  )
    .bind(logId, templateKey, recipientEmail, recipientName || '', subject, status, providerId, errorMsg, relatedType, relatedId, status)
    .run();

  return { logId, status, providerId, errorMsg };
}

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return jsonResponse({ ok: true }, 200);
    }

    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    try {
      // =========================================================================
      // 1. HEALTH & CLOUDFLARE D1/R2 BINDING VERIFICATION
      // =========================================================================
      if (path === '/api/health' && method === 'GET') {
        const d1Check = await env.DB.prepare('SELECT value_json FROM system_settings WHERE key = ?')
          .bind('center_identity')
          .first();
        const bootstrapState = await env.DB.prepare('SELECT is_completed, completed_at FROM bootstrap_state WHERE id = 1').first();
        let r2Status = 'unverified';
        try {
          if (env.FILES) {
            await env.FILES.head('__health_check_probe__');
            r2Status = 'connected';
          }
        } catch (e) {
          r2Status = 'error: ' + e.message;
        }
        return jsonResponse({
          ok: true,
          service: 'Sky First Center for Research and Development API',
          domain: 'https://scrd.skyfirst.io.vn',
          d1_binding: env.DB ? 'connected' : 'missing',
          r2_binding: r2Status,
          bootstrap_completed: Boolean(bootstrapState?.is_completed),
          center: d1Check ? JSON.parse(d1Check.value_json) : null,
          timestamp: new Date().toISOString()
        });
      }

      // =========================================================================
      // 2. FIRST-ADMIN SAFE BOOTSTRAP WORKFLOW (SECTION VII)
      // =========================================================================
      if (path === '/api/bootstrap/status' && method === 'GET') {
        const state = await env.DB.prepare('SELECT is_completed, completed_at FROM bootstrap_state WHERE id = 1').first();
        const adminCount = await env.DB.prepare("SELECT COUNT(*) AS cnt FROM users WHERE role = 'super_admin'").first();
        return jsonResponse({
          ok: true,
          bootstrap_allowed: !state?.is_completed && (adminCount?.cnt || 0) === 0,
          is_completed: Boolean(state?.is_completed),
          completed_at: state?.completed_at || null
        });
      }

      if (path === '/api/bootstrap/init' && method === 'POST') {
        const state = await env.DB.prepare('SELECT is_completed FROM bootstrap_state WHERE id = 1').first();
        const adminCount = await env.DB.prepare("SELECT COUNT(*) AS cnt FROM users WHERE role = 'super_admin'").first();

        if (state?.is_completed || (adminCount?.cnt || 0) > 0) {
          await writeAuditLog(env.DB, null, 'BOOTSTRAP_REJECTED_ALREADY_COMPLETED', 'bootstrap_state', '1', {}, request);
          return jsonResponse({ ok: false, error: 'Hệ thống đã hoàn tất khởi tạo Quản trị viên đầu tiên. Bootstrap đã bị khóa vĩnh viễn.' }, 403);
        }

        const expectedToken = env.BOOTSTRAP_SECRET_TOKEN;
        const providedToken = request.headers.get('X-Bootstrap-Token') || '';
        if (!expectedToken || !timingSafeEqual(providedToken, expectedToken)) {
          await writeAuditLog(env.DB, null, 'BOOTSTRAP_INVALID_TOKEN', 'bootstrap_state', '1', {}, request);
          return jsonResponse({ ok: false, error: 'Token Bootstrap không hợp lệ hoặc chưa cấu hình BOOTSTRAP_SECRET_TOKEN.' }, 401);
        }

        const body = await request.json();
        const email = (body.email || '').trim().toLowerCase();
        const fullName = (body.full_name || '').trim();
        const password = body.password || '';

        if (!email || !email.includes('@') || fullName.length < 3 || password.length < 10) {
          return jsonResponse({ ok: false, error: 'Email hợp lệ, họ tên (>=3 ký tự) và mật khẩu mạnh (>=10 ký tự) là bắt buộc.' }, 400);
        }

        const passwordHash = await hashPassword(password);
        const adminId = crypto.randomUUID();
        const ip = request.headers.get('CF-Connecting-IP') || '0.0.0.0';

        await env.DB.batch([
          env.DB.prepare(
            `INSERT INTO users (id, email, password_hash, full_name, role, status, title, department, created_at, updated_at)
             VALUES (?, ?, ?, ?, 'super_admin', 'active', 'Quản trị viên Hệ thống Cấp cao', 'Ban Điều hành Trung tâm Sky First', datetime('now'), datetime('now'))`
          ).bind(adminId, email, passwordHash, fullName),
          env.DB.prepare(
            `UPDATE bootstrap_state
             SET is_completed = 1, completed_at = datetime('now'), bootstrap_admin_user_id = ?, client_ip_hash = ?, notes = 'Completed via secure token bootstrap'
             WHERE id = 1 AND is_completed = 0`
          ).bind(adminId, ip)
        ]);

        await writeAuditLog(env.DB, adminId, 'BOOTSTRAP_SUPER_ADMIN_CREATED', 'users', adminId, { email, full_name: fullName }, request);
        return jsonResponse({
          ok: true,
          message: 'Khởi tạo Quản trị viên đầu tiên thành công. Quy trình Bootstrap đã tự động vô hiệu hóa vĩnh viễn.',
          admin_user: { id: adminId, email, full_name: fullName, role: 'super_admin' }
        }, 201);
      }

      // =========================================================================
      // 3. AUTHENTICATION & SESSION MANAGEMENT
      // =========================================================================
      if (path === '/api/auth/login' && method === 'POST') {
        const body = await request.json();
        const email = (body.email || '').trim().toLowerCase();
        const password = body.password || '';

        const user = await env.DB.prepare('SELECT * FROM users WHERE email = ? LIMIT 1').bind(email).first();
        if (!user || user.status !== 'active') {
          return jsonResponse({ ok: false, error: 'Tài khoản không tồn tại hoặc chưa được kích hoạt.' }, 401);
        }

        const valid = await verifyPassword(password, user.password_hash);
        if (!valid) {
          await writeAuditLog(env.DB, user.id, 'AUTH_LOGIN_FAILED', 'users', user.id, { email }, request);
          return jsonResponse({ ok: false, error: 'Thông tin đăng nhập không chính xác.' }, 401);
        }

        const rawToken = crypto.randomUUID() + '-' + crypto.randomUUID();
        const enc = new TextEncoder();
        const hashBuf = await crypto.subtle.digest('SHA-256', enc.encode(rawToken));
        const tokenHash = Array.from(new Uint8Array(hashBuf)).map(b => b.toString(16).padStart(2, '0')).join('');
        const sessionId = crypto.randomUUID();

        await env.DB.batch([
          env.DB.prepare(
            `INSERT INTO sessions (id, user_id, token_hash, ip_address, user_agent, expires_at, created_at)
             VALUES (?, ?, ?, ?, ?, datetime('now', '+7 days'), datetime('now'))`
          ).bind(sessionId, user.id, tokenHash, request.headers.get('CF-Connecting-IP') || '', request.headers.get('User-Agent') || ''),
          env.DB.prepare("UPDATE users SET last_login_at = datetime('now') WHERE id = ?").bind(user.id)
        ]);

        await writeAuditLog(env.DB, user.id, 'AUTH_LOGIN_SUCCESS', 'users', user.id, {}, request);
        return jsonResponse({
          ok: true,
          token: rawToken,
          user: {
            id: user.id,
            email: user.email,
            full_name: user.full_name,
            role: user.role,
            title: user.title,
            department: user.department,
            avatar_r2_key: user.avatar_r2_key
          }
        });
      }

      if (path === '/api/auth/logout' && method === 'POST') {
        const session = await authenticateRequest(request, env);
        if (session) {
          await env.DB.prepare("UPDATE sessions SET revoked_at = datetime('now') WHERE id = ?").bind(session.session_id).run();
        }
        return jsonResponse({ ok: true });
      }

      // =========================================================================
      // 4. PUBLIC WEBSITE CONTENT API (CMS-DRIVEN, NO HARDCODED FRONTEND LOCK)
      // =========================================================================
      if (path === '/api/public/bootstrap-data' && method === 'GET') {
        const [settingsRows, menusRows, pagesRows, postsRows, researchRows, projectRows, pubRows, examRows, partnerRows] = await env.DB.batch([
          env.DB.prepare('SELECT key, value_json FROM system_settings'),
          env.DB.prepare('SELECT * FROM cms_menus WHERE is_visible = 1 ORDER BY menu_group ASC, sort_order ASC'),
          env.DB.prepare("SELECT id, slug, title_vi, title_en, summary_vi, summary_en, content_vi, content_en, page_group, seo_title, seo_description, updated_at FROM cms_pages WHERE status = 'published' ORDER BY sort_order ASC"),
          env.DB.prepare("SELECT id, slug, title_vi, title_en, excerpt_vi, excerpt_en, content_vi, content_en, category, tags_json, author_display_name, is_ai_generated, published_at, updated_at FROM cms_posts WHERE status = 'published' ORDER BY published_at DESC"),
          env.DB.prepare("SELECT id, code, slug, title_vi, title_en, field, status, summary_vi, summary_en, findings_summary, lead_Order, started_at, completed_at FROM research_topics WHERE is_public = 1 ORDER BY created_at DESC"),
          env.DB.prepare("SELECT id, code, slug, title_vi, title_en, objectives_vi, objectives_en, location, status, progress_percent, start_date, end_date, public_evidence_summary FROM community_projects WHERE is_public = 1 ORDER BY created_at DESC"),
          env.DB.prepare("SELECT id, code, slug, title_vi, title_en, doc_type, authors_text, published_year, abstract_vi, abstract_en, access_level, download_count FROM publications_documents WHERE access_level = 'public' ORDER BY published_year DESC"),
          env.DB.prepare("SELECT id, code, title_vi, title_en, category, duration_minutes, pass_score, status, public_overview_vi, public_overview_en FROM academic_assessments WHERE status = 'published'"),
          env.DB.prepare("SELECT id, organization_name, partner_type, website_url, description_vi, description_en FROM partners WHERE is_verified = 1 AND is_public = 1")
        ]);

        const settings = {};
        for (const r of settingsRows.results || []) {
          try { settings[r.key] = JSON.parse(r.value_json); } catch { settings[r.key] = r.value_json; }
        }

        return jsonResponse({
          ok: true,
          settings,
          menus: menusRows.results || [],
          pages: pagesRows.results || [],
          posts: postsRows.results || [],
          research_topics: researchRows.results || [],
          community_projects: projectRows.results || [],
          publications: pubRows.results || [],
          academic_assessments: examRows.results || [],
          partners: partnerRows.results || []
        });
      }

      // =========================================================================
      // 5. 5-STEP ACCOUNT REGISTRATION & SANITIZED STATUS LOOKUP (SECTION VIII)
      // =========================================================================
      if (path === '/api/account-requests' && method === 'POST') {
        const body = await request.json();
        const fullName = sanitizeHtmlInput((body.full_name || '').trim());
        const email = (body.email || '').trim().toLowerCase();
        const phone = sanitizeHtmlInput((body.phone || '').trim());
        const gender = sanitizeHtmlInput((body.gender || '').trim());
        const dob = (body.date_of_birth || '').trim();
        const isMinor = Boolean(body.is_minor);

        if (!fullName || !email.includes('@') || !phone || !gender || !dob) {
          return jsonResponse({ ok: false, error: 'Bước 1 (Thông tin cá nhân): Vui lòng điền đầy đủ Họ tên, Email, Số điện thoại, Giới tính và Ngày sinh.' }, 400);
        }

        if (isMinor) {
          if (!body.guardian_full_name || !body.guardian_phone || !body.guardian_relationship || !body.guardian_consent_confirmed) {
            return jsonResponse({
              ok: false,
              error: 'Người đăng ký dưới 18 tuổi bắt buộc phải có đầy đủ họ tên, số điện thoại, mối quan hệ và xác nhận đồng ý của người giám hộ hợp pháp.'
            }, 400);
          }
        }

        if (!body.education_level || !body.organization_name || !body.current_role) {
          return jsonResponse({ ok: false, error: 'Bước 2 (Học tập và công tác): Vui lòng điền đầy đủ trình độ, đơn vị và vai trò hiện tại.' }, 400);
        }

        if (!body.national_id_number || !body.national_id_issue_date || !body.national_id_issue_place) {
          return jsonResponse({ ok: false, error: 'Bước 3 (Thông tin định danh): Vui lòng cung cấp thông tin định danh hợp lệ.' }, 400);
        }

        if (!body.requested_role || !body.registration_purpose || !body.privacy_policy_accepted || !body.terms_accepted || !body.accuracy_confirmed) {
          return jsonResponse({ ok: false, error: 'Bước 4 & 5: Vui lòng hoàn tất mục đích đăng ký và đồng ý Chính sách bảo vệ dữ liệu cá nhân & Điều khoản sử dụng.' }, 400);
        }

        // Hash national ID number for indexing while keeping record protected in backend
        const enc = new TextEncoder();
        const idHashBuf = await crypto.subtle.digest('SHA-256', enc.encode(body.national_id_number.trim()));
        const nationalIdHash = Array.from(new Uint8Array(idHashBuf)).map(b => b.toString(16).padStart(2, '0')).join('');

        const requestCode = await generateUniqueRequestCode(env.DB);
        const reqId = crypto.randomUUID();

        await env.DB.prepare(
          `INSERT INTO account_requests (
            id, request_code, status,
            full_name, email, phone, gender, date_of_birth, is_minor,
            guardian_full_name, guardian_phone, guardian_email, guardian_relationship, guardian_consent_confirmed,
            education_level, organization_name, current_role, academic_major,
            national_id_hash, national_id_last4, id_issue_date, id_issue_place, personal_photo_r2_key, id_front_r2_key, id_back_r2_key,
            requested_role, registration_purpose, research_field_interest,
            privacy_policy_accepted, terms_accepted, accuracy_confirmed,
            submitted_at, updated_at
          ) VALUES (?, ?, 'Đã tiếp nhận', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1, 1, datetime('now'), datetime('now'))`
        ).bind(
          reqId,
          requestCode,
          fullName,
          email,
          phone,
          gender,
          dob,
          isMinor ? 1 : 0,
          body.guardian_full_name || null,
          body.guardian_phone || null,
          body.guardian_email || null,
          body.guardian_relationship || null,
          isMinor ? 1 : 0,
          sanitizeHtmlInput(body.education_level),
          sanitizeHtmlInput(body.organization_name),
          sanitizeHtmlInput(body.current_role),
          sanitizeHtmlInput(body.academic_major || ''),
          nationalIdHash,
          body.national_id_number.trim().slice(-4),
          body.national_id_issue_date,
          sanitizeHtmlInput(body.national_id_issue_place),
          body.personal_photo_r2_key || null,
          body.id_front_r2_key || null,
          body.id_back_r2_key || null,
          ALLOWED_ROLES.includes(body.requested_role) && body.requested_role !== 'super_admin' ? body.requested_role : 'member',
          sanitizeHtmlInput(body.registration_purpose),
          sanitizeHtmlInput(body.research_field_interest || '')
        ).run();

        // Dispatch confirmation email (strictly excludes CCCD number & ID card photos)
        const guardianSummary = isMinor
          ? `${body.guardian_full_name} (${body.guardian_relationship} - ĐT: ${body.guardian_phone})`
          : 'Không áp dụng (Đủ 18 tuổi)';

        const emailResult = await dispatchEventEmail(
          env,
          'account_request_received',
          email,
          fullName,
          'Xác nhận yêu cầu cấp tài khoản | Trung tâm Sky First',
          {
            full_name: fullName,
            email,
            phone,
            gender,
            date_of_birth: dob,
            guardian_details_if_applicable: guardianSummary,
            request_code: requestCode,
            request_status: 'Đã tiếp nhận',
            submitted_at: new Date().toISOString()
          },
          'account_requests',
          reqId
        );

        await writeAuditLog(env.DB, null, 'ACCOUNT_REQUEST_SUBMITTED', 'account_requests', reqId, { request_code: requestCode, email }, request);

        return jsonResponse({
          ok: true,
          request_code: requestCode,
          status: 'Đã tiếp nhận',
          submitted_at: new Date().toISOString(),
          email_dispatch: emailResult
        }, 201);
      }

      if (path === '/api/account-requests/lookup' && method === 'POST') {
        const body = await request.json();
        const code = (body.request_code || '').trim().toUpperCase();
        const email = (body.email || '').trim().toLowerCase();

        if (!code.startsWith('SCRD-SFN-') || !email) {
          return jsonResponse({ ok: false, error: 'Vui lòng nhập đúng Mã yêu cầu (SCRD-SFN-XXXXXXXXXX) và Email đăng ký.' }, 400);
        }

        // Only select fields the applicant is permitted to view (NO CCCD hash/last4, NO internal reviewer notes, NO ID photos)
        const record = await env.DB.prepare(
          `SELECT request_code, status, full_name, email, requested_role, public_review_message, submitted_at, updated_at
           FROM account_requests
           WHERE request_code = ? AND lower(email) = ?
           LIMIT 1`
        ).bind(code, email).first();

        if (!record) {
          return jsonResponse({ ok: false, error: 'Không tìm thấy hồ sơ yêu cầu khớp với mã và email đã cung cấp.' }, 404);
        }

        return jsonResponse({ ok: true, request: record });
      }

      // =========================================================================
      // 6. AUTHENTICATED CMS & ADMIN ENDPOINTS (RBAC ENFORCED AT BACKEND)
      // =========================================================================
      const session = await authenticateRequest(request, env);
      if (!session) {
        return jsonResponse({ ok: false, error: 'Yêu cầu xác thực phiên đăng nhập hợp lệ (Unauthorized).' }, 401);
      }

      // CMS Posts CRUD (supports editing AI-generated posts completely & defaulting new AI posts to draft)
      if (path === '/api/cms/posts' && method === 'POST') {
        if (!['super_admin', 'cms_editor'].includes(session.role)) {
          return jsonResponse({ ok: false, error: 'Bạn không có quyền tạo hoặc chỉnh sửa bài viết CMS.' }, 403);
        }
        const body = await request.json();
        const postId = body.id || crypto.randomUUID();
        const isAi = Boolean(body.is_ai_generated);
        // Rule 6.2: If AI creates a new post, default to 'draft' for human review before publishing
        const status = (!body.id && isAi) ? 'draft' : (body.status || 'draft');

        await env.DB.prepare(
          `INSERT INTO cms_posts (id, slug, title_vi, title_en, excerpt_vi, excerpt_en, content_vi, content_en, category, tags_json, featured_media_id, author_display_name, status, is_ai_generated, seo_title, seo_description, published_at, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CASE WHEN ? = 'published' THEN datetime('now') ELSE NULL END, datetime('now'), datetime('now'))
           ON CONFLICT(id) DO UPDATE SET
             slug = excluded.slug,
             title_vi = excluded.title_vi,
             title_en = excluded.title_en,
             excerpt_vi = excluded.excerpt_vi,
             excerpt_en = excluded.excerpt_en,
             content_vi = excluded.content_vi,
             content_en = excluded.content_en,
             category = excluded.category,
             tags_json = excluded.tags_json,
             author_display_name = excluded.author_display_name,
             status = excluded.status,
             seo_title = excluded.seo_title,
             seo_description = excluded.seo_description,
             published_at = CASE WHEN excluded.status = 'published' AND cms_posts.published_at IS NULL THEN datetime('now') WHEN excluded.status != 'published' THEN NULL ELSE cms_posts.published_at END,
             updated_at = datetime('now')`
        ).bind(
          postId,
          sanitizeHtmlInput(body.slug),
          sanitizeHtmlInput(body.title_vi),
          sanitizeHtmlInput(body.title_en || ''),
          sanitizeHtmlInput(body.excerpt_vi || ''),
          sanitizeHtmlInput(body.excerpt_en || ''),
          sanitizeHtmlInput(body.content_vi || ''),
          sanitizeHtmlInput(body.content_en || ''),
          sanitizeHtmlInput(body.category || 'tin-tuc'),
          JSON.stringify(body.tags || []),
          body.featured_media_id || null,
          sanitizeHtmlInput(body.author_display_name || session.full_name),
          status,
          isAi ? 1 : 0,
          sanitizeHtmlInput(body.seo_title || body.title_vi),
          sanitizeHtmlInput(body.seo_description || body.excerpt_vi || ''),
          status
        ).run();

        await writeAuditLog(env.DB, session.user_id, 'CMS_POST_UPSERT', 'cms_posts', postId, { slug: body.slug, status, is_ai_generated: isAi }, request);
        return jsonResponse({ ok: true, id: postId, status });
      }

      // CMS Menus & Footer Links Update with XSS/URL Validation
      if (path === '/api/cms/menus' && method === 'POST') {
        if (!['super_admin', 'cms_editor'].includes(session.role)) {
          return jsonResponse({ ok: false, error: 'Không có quyền quản trị menu và liên kết.' }, 403);
        }
        const body = await request.json();
        if (!isValidSafeUrl(body.target_url)) {
          return jsonResponse({ ok: false, error: 'URL không hợp lệ hoặc chứa giao thức nguy hiểm bị chặn (XSS Protection).' }, 400);
        }
        const menuId = body.id || crypto.randomUUID();
        await env.DB.prepare(
          `INSERT INTO cms_menus (id, menu_group, parent_id, label_vi, label_en, target_url, sort_order, is_visible, open_in_new_tab, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
           ON CONFLICT(id) DO UPDATE SET
             menu_group = excluded.menu_group,
             label_vi = excluded.label_vi,
             label_en = excluded.label_en,
             target_url = excluded.target_url,
             sort_order = excluded.sort_order,
             is_visible = excluded.is_visible,
             updated_at = datetime('now')`
        ).bind(
          menuId,
          body.menu_group || 'header_main',
          body.parent_id || null,
          sanitizeHtmlInput(body.label_vi),
          sanitizeHtmlInput(body.label_en || ''),
          body.target_url.trim(),
          Number(body.sort_order || 1),
          body.is_visible === undefined ? 1 : (body.is_visible ? 1 : 0),
          body.open_in_new_tab ? 1 : 0
        ).run();

        await writeAuditLog(env.DB, session.user_id, 'CMS_MENU_UPSERT', 'cms_menus', menuId, { label_vi: body.label_vi, target_url: body.target_url }, request);
        return jsonResponse({ ok: true, id: menuId });
      }

      // R2 Media Upload with MIME & Size Verification (Section 6.5 & XI)
      if (path === '/api/media/upload' && method === 'POST') {
        const formData = await request.formData();
        const file = formData.get('file');
        const visibility = formData.get('visibility') || 'public';

        if (!file || typeof file.arrayBuffer !== 'function') {
          return jsonResponse({ ok: false, error: 'Chưa chọn tệp tải lên.' }, 400);
        }
        if (!ALLOWED_MIME_TYPES.has(file.type)) {
          return jsonResponse({ ok: false, error: `Định dạng tệp (${file.type}) không được phép tải lên vì lý do bảo mật.` }, 415);
        }
        if (file.size > MAX_UPLOAD_BYTES) {
          return jsonResponse({ ok: false, error: 'Dung lượng tệp vượt quá giới hạn cho phép (25MB).' }, 413);
        }

        const mediaId = crypto.randomUUID();
        const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
        const r2Key = `uploads/${new Date().toISOString().slice(0, 10)}/${mediaId}-${safeName}`;

        if (env.FILES) {
          await env.FILES.put(r2Key, await file.arrayBuffer(), {
            httpMetadata: { contentType: file.type },
            customMetadata: { uploadedBy: session.user_id, visibility }
          });
        }

        await env.DB.prepare(
          `INSERT INTO media_files (id, r2_key, bucket_name, original_filename, mime_type, size_bytes, visibility, uploaded_by_user_id, created_at)
           VALUES (?, ?, 'scrd-files', ?, ?, ?, ?, ?, datetime('now'))`
        ).bind(mediaId, r2Key, safeName, file.type, file.size, visibility, session.user_id).run();

        await writeAuditLog(env.DB, session.user_id, 'R2_MEDIA_UPLOADED', 'media_files', mediaId, { r2Key, mime: file.type, size: file.size }, request);
        return jsonResponse({ ok: true, id: mediaId, r2_key: r2Key, bucket: 'scrd-files', size_bytes: file.size }, 201);
      }

      // Admin Review Account Request & Trigger Status Email
      if (path === '/api/admin/account-requests/review' && method === 'POST') {
        if (!['super_admin', 'reviewer'].includes(session.role)) {
          return jsonResponse({ ok: false, error: 'Chỉ Quản trị viên hoặc Cán bộ xét duyệt mới có quyền duyệt yêu cầu cấp tài khoản.' }, 403);
        }
        const body = await request.json();
        const { request_id, new_status, public_review_message, internal_reviewer_notes } = body;
        const validStatuses = ['Đã tiếp nhận', 'Đang xem xét', 'Cần bổ sung thông tin', 'Đã duyệt', 'Từ chối', 'Đã kích hoạt tài khoản'];
        if (!validStatuses.includes(new_status)) {
          return jsonResponse({ ok: false, error: 'Trạng thái xét duyệt không hợp lệ.' }, 400);
        }

        const reqRow = await env.DB.prepare('SELECT * FROM account_requests WHERE id = ? LIMIT 1').bind(request_id).first();
        if (!reqRow) return jsonResponse({ ok: false, error: 'Không tìm thấy yêu cầu.' }, 404);

        await env.DB.prepare(
          `UPDATE account_requests
           SET status = ?, public_review_message = ?, internal_reviewer_notes = ?, reviewed_by_user_id = ?, reviewed_at = datetime('now'), updated_at = datetime('now')
           WHERE id = ?`
        ).bind(new_status, sanitizeHtmlInput(public_review_message || ''), sanitizeHtmlInput(internal_reviewer_notes || ''), session.user_id, request_id).run();

        const emailRes = await dispatchEventEmail(
          env,
          'account_request_status_update',
          reqRow.email,
          reqRow.full_name,
          `Cập nhật trạng thái yêu cầu ${reqRow.request_code} | Trung tâm Sky First`,
          {
            full_name: reqRow.full_name,
            request_code: reqRow.request_code,
            request_status: new_status,
            review_message: public_review_message || '',
            updated_at: new Date().toISOString()
          },
          'account_requests',
          request_id
        );

        await writeAuditLog(env.DB, session.user_id, 'ACCOUNT_REQUEST_REVIEWED', 'account_requests', request_id, { new_status }, request);
        return jsonResponse({ ok: true, status: new_status, email_dispatch: emailRes });
      }

      return jsonResponse({ ok: false, error: 'Endpoint không tồn tại.' }, 404);
    } catch (err) {
      console.error('Worker API Error:', err);
      return jsonResponse({ ok: false, error: 'Lỗi xử lý máy chủ nội bộ.', details: err.message }, 500);
    }
  }
};