# MANIFEST BÀN GIAO — SCRD + EXAM SUPER COMPREHENSIVE REPAIR

## Gói nguồn
- Tên dự kiến: `SkyFirst_SCRD_EXAM_SUPER_COMPREHENSIVE_REPAIR_20261022.zip`
- Thư mục gốc trong ZIP: `SCRD_UI_Release_20261022/`
- Nội dung: source SCRD + Exam, 6 migrations, tests, assets và tài liệu tiếng Việt.
- Source archive gốc được giữ nguyên; không thay đổi production.

## Các migration cần biết
- `migrations/0001_initial_schema.sql`
- `migrations/0002_cleanup_unverified_content.sql`
- `migrations/0003_home_about_longform.sql`
- `migrations/0004_public_hero_copy_update.sql`
- `migrations/0005_temporary_password_guard.sql`
- `migrations/0006_hero_description_split.sql`

## Kiểm thử được tích hợp trong gói
- `npm test`
- Syntax check đạt.
- Migration chain: 6/6.
- Content validation: 6/6 (bao gồm độ dài, cấu trúc và không lặp đoạn).
- UI regression: 29/29.
- SCRD smoke: 18/18.
- SCRD ↔ Exam integration: 5/5.
- Exam validation: 31/31.
- Tổng kiểm tra nội dung/UI/nghiệp vụ: 89/89; cộng release audit: 108/108.

Xem `TEST_LOG_FULL_REPAIR_20261022.txt` cho output lần chạy cuối; `SUPER_COMPREHENSIVE_AUDIT_VI.md` và `REQUIREMENT_TRACEABILITY_12_PARTS_VI.md` là tài liệu tổng hợp authoritative. Các test SCRD/integration chạy cục bộ bằng SQLite và R2 giả lập; test UI chủ yếu kiểm tra source/static contracts.

## Giới hạn không che giấu
- Không triển khai production.
- Hai file Wrangler còn placeholder tên D1 cần thay bằng tên đúng lấy từ Cloudflare.
- Chưa xác minh D1/R2 production, secrets, DNS, email thật hoặc quyền Cloudflare.
- Không hoàn thành browser E2E trong môi trường này.
- Chat chưa có E2EE/realtime WebSocket/DO.
- Điều khoản/chính sách dữ liệu cần được đơn vị vận hành duyệt.
- Chưa có job tự động dọn dẹp tệp upload staging mồ côi.

## Tài liệu chính
- `README_VI.md`
- `FULL_REPAIR_REPORT_VI.md`
- `SCRD_EXAM_RELEASE_CHECKLIST_12_PARTS_VI.md`
- `SECURITY_AUDIT_VI.md`
- `UI_REFINEMENT_REPORT_VI.md`
- `TEST_REPORT_2026-10-22_VI.md`
- `CHANGELOG_SUPER_COMPREHENSIVE_VI.md`
