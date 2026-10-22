# Báo cáo kiểm thử SCRD + Exam — 22/10/2026

## Kết quả kiểm thử cục bộ

- Cú pháp JavaScript của Worker và frontend: PASS.
- Cấu hình `wrangler.toml` (TOML): PASS.
- Cấu hình `EXAM/wrangler.json` (JSON): PASS.
- Nội dung Trang chủ/Giới thiệu: 4/4 kiểm tra ngưỡng tối thiểu PASS.
  - Giới thiệu VI: 6.243 tokens; EN: 4.030 words/tokens.
  - Trang chủ VI: 6.198 tokens; EN: 4.016 words/tokens.
- Hồi quy giao diện tĩnh: 9/9 PASS.
- SCRD Worker + SQLite/D1 mô phỏng + R2 giả lập: 14/14 PASS.
- Tích hợp SCRD ↔ Exam trên D1 thử nghiệm dùng chung: 5/5 PASS.
- Exam validation: 31/31 PASS.

## Giới hạn

- Tổng kiểm thử nội dung/giao diện/nghiệp vụ: 63 PASS.
- Đây là kiểm thử local, không chứng minh đã triển khai thành công trên Cloudflare production.
- Sanity-check layout bằng preview/mocks ghi nhận không tràn ngang tại 360, 390, 768 và 1440 px; đây không phải E2E trình duyệt hoàn chỉnh trên domain thực.
- Chưa thể xác minh tên D1 thực tế từ Cloudflare Dashboard; các cấu hình giữ placeholder có chủ đích, không đoán tên.
- Secrets, email thật, DNS/custom domains, backup/rollback và quyền production cần được xác minh trong tài khoản Cloudflare có thẩm quyền.
- Không chạy lệnh deploy production trong quá trình kiểm thử.

## Hướng dẫn tiếp theo

1. Xác minh tên D1 thật từ Cloudflare Dashboard và cập nhật cả `wrangler.toml` và `EXAM/wrangler.json`.
2. Cấu hình secrets bằng Wrangler Secret, không đưa secrets vào mã nguồn.
3. Kiểm tra migration trên staging/backup trước khi chạy trên D1 đang có dữ liệu.
4. Chạy kiểm thử trình duyệt desktop/mobile và E2E trên staging; chỉ sau đó mới quyết định triển khai production.
