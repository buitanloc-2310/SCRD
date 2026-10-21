# Sky First Center — gói mã nguồn kiểm tra và hoàn thiện

Tên miền dự kiến: https://scrd.skyfirst.io.vn
D1: 6006fe24-6278-4989-8d94-fd4734d71679
R2: scrd-files (binding Worker dự kiến: FILES)

## CẢNH BÁO
Gói này chứa mã nguồn được cung cấp để kiểm tra, chưa phải bản đã xác minh production. Không triển khai công khai trước khi hoàn thành các mục dưới đây. Không có bằng chứng trong gói rằng D1/R2, email, CMS, Bootstrap hoặc hệ thống khảo thí đang kết nối thật.

## Các tệp
- `index.html`: giao diện website được cung cấp.
- `backend_worker.js`: Cloudflare Worker API được cung cấp.
- `d1_schema_migration.sql`: schema/migration D1 được cung cấp.
- `run_rigorous_tests.py`: bộ test gốc; cần chỉnh đường dẫn và đồng bộ schema trước khi chạy.
- `desktop_main.js`: Electron main process; không tự tạo installer.
- `wrangler.toml.example`: mẫu cấu hình, cần xác minh trước khi dùng.
- `SECURITY_AUDIT_VI.md`: các lỗi trọng yếu cần sửa.

## Quy trình GitHub + Cloudflare
1. Tạo repository GitHub riêng tư và tải các tệp lên.
2. Đổi `wrangler.toml.example` thành `wrangler.toml`, xác minh D1 ID/binding và R2 bucket/binding.
3. Không đưa token, API key, bootstrap secret hoặc thông tin đăng nhập vào GitHub; đặt bằng Cloudflare Worker Secrets.
4. Chạy migration trên bản D1 thử nghiệm trước; không chạy trực tiếp production khi chưa backup.
5. Chạy test, sửa toàn bộ lỗi, kiểm tra API bằng tài khoản không đăng nhập và tài khoản ít quyền.
6. Chỉ deploy sau khi kiểm thử bảo mật và xác nhận tích hợp `exam.skyfirst.io.vn`.

## Lưu ý
Các thông tin `D1/R2 Ready`, `Đang hoạt động` trên giao diện không phải bằng chứng kết nối thật. Mọi trạng thái chỉ được hiển thị khi API kiểm tra được tài nguyên thực tế.
