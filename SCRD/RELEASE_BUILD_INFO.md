# Thông tin build — Super Comprehensive Repair

- Tên ZIP: `SkyFirst_SCRD_EXAM_SUPER_COMPREHENSIVE_REPAIR_20261022.zip`
- Thời điểm đóng gói: 22/10/2026 (giờ Việt Nam)
- Phạm vi: source SCRD + Exam, migrations, tests, assets, hướng dẫn triển khai và báo cáo 12 phần.
- Bộ test cuối: syntax đạt; migration 6/6; content 6/6; UI 29/29; SCRD smoke 18/18; tích hợp 5/5; Exam 31/31; release audit 19/19.
- Tổng: 89 kiểm tra nội dung/UI/nghiệp vụ và 19 kiểm tra release audit = 108 kiểm tra tự động, ngoài syntax và migration chain.
- Môi trường test SCRD/integration: SQLite/D1 adapter và R2 giả lập.
- Không deploy production, không áp dụng migration lên D1 thật, không sửa dữ liệu production.
- Cấu hình tên D1 còn placeholder cần xác minh chính xác từ Cloudflare Dashboard; không đoán tên database.
- `RELEASE_MANIFEST.json` chứa SHA-256/size của file gói (trừ manifest và file hash-list để tránh tham chiếu vòng).
- `RELEASE_FILE_HASHES_SHA256.txt` chứa SHA-256 của mọi file khác trong gói, bao gồm manifest JSON; chính file hash-list không thể tự chứa hash của nó.
