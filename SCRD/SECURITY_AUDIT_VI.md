# Kiểm tra bảo mật và giới hạn bàn giao

## Các kiểm soát có kiểm thử cục bộ

- Bootstrap quản trị một lần qua token cấu hình; lần khởi tạo sau bị từ chối.
- Đăng nhập cấp token và CSRF token; endpoint hồ sơ trả thông tin an toàn.
- Hồ sơ đăng ký được cấp mã duy nhất theo dạng `SCRD-SFN-` + 10 chữ số sau khi ghi D1 thành công.
- Số định danh được mã hóa ở backend, đồng thời lưu hash và dạng che; tra cứu công khai không trả trường định danh hoặc ghi chú nội bộ.
- Upload riêng tư không được phục vụ công khai; loại MIME ảnh được kiểm tra.
- CMS làm sạch HTML đầu vào và chỉ lưu các khóa cấu hình cho phép.
- API không tồn tại và lỗi không tiết lộ chi tiết nội bộ trong phản hồi công khai.
- Tích hợp Exam kiểm tra launch token dùng một lần, truy cập attempt, autosave theo revision, chấm điểm phía server và biên nhận.

## Kết quả test cục bộ được chạy khi đóng gói

- SCRD Worker + D1 SQLite + R2 giả lập: 14/14 PASS.
- SCRD ↔ Exam trên D1 tạm thời dùng chung: 5/5 PASS.
- Exam validation: 31/31 PASS.
- Kiểm tra cú pháp JavaScript: PASS.

Các kết quả trên là kết quả kiểm thử trong môi trường cục bộ, không phải kiểm thử production Cloudflare.

## Các điều kiện không thể xác minh chỉ từ ZIP

- Tên D1 thực tế trong Cloudflare; cấu hình hiện để placeholder thay vì đoán tên.
- Quyền truy cập Cloudflare, bucket thực tế, secrets, DNS và custom domains.
- Migration production đã chạy hay chưa và dữ liệu production có tương thích hay không.
- Nhà cung cấp email và việc gửi email thật.
- Quy trình vận hành, thời hạn lưu/xóa dữ liệu, phê duyệt chính sách và quyền nhân sự thực tế.
- Kiểm thử trình duyệt production, tải thực, quét lỗ hổng độc lập và xác minh backup/rollback.

Không đưa thông tin nhạy cảm vào log. Không deploy production trước khi các điều kiện cấu hình và vận hành được xác nhận.
