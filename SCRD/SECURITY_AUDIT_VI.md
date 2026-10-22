# RÀ SOÁT BẢO MẬT — SCRD + EXAM

Tài liệu này ghi lại những kiểm soát được thấy trong source và những giới hạn cần kiểm tra thêm. Đây không phải chứng nhận bảo mật độc lập hay xác nhận rằng production an toàn tuyệt đối.

## Kiểm soát được kiểm tra trong mã nguồn/test local

- Các endpoint mutation áp dụng phiên và CSRF theo luồng đang có; test xác nhận thiếu/sai CSRF bị từ chối. Cấu hình bố cục trang chủ được xác thực về danh sách khối, không cho trùng/thiếu khối và giữ Hero đầu trang.
- Bootstrap quản trị viên ban đầu là luồng one-time; test xác nhận không tạo được quản trị viên thứ hai sau khi hoàn thành.
- Mật khẩu tạm thời được đánh dấu bằng `must_change_password`; test xác minh yêu cầu đổi trước khi tiếp tục và thu hồi phiên khác khi đổi mật khẩu.
- ID number và chữ ký được mã hóa bằng helper backend hiện có; dữ liệu công khai của lookup không trả các trường nhạy cảm và ghi chú nội bộ trong test.
- Upload kiểm tra loại file/magic bytes và giới hạn dung lượng trong các luồng được test.
- Tệp hồ sơ mang loại `account_request_staging` bị chặn đọc trước khi hồ sơ được submit, kể cả khi session thuộc reviewer; tệp được liên kết với hồ sơ đã gửi thì chỉ vai trò được phép đọc.
- Chat attachments yêu cầu thành viên có mặt trong phòng chat; các API phòng/tin nhắn kiểm tra membership.
- Thí sinh không nhận dữ liệu đáp án qua API chuẩn trong các test integration Exam.
- Error handling được test để không tiết lộ thông tin nội bộ qua route lỗi/endpoint không tồn tại.

- Các thay đổi mới thêm: xác thực cấu hình homepage layout ở backend, chặn xóa chương trình còn nhiệm vụ liên kết, kiểm tra parent task tồn tại và giới hạn trọng số.
- Mã mới không tiếp tục lưu unsalted SHA-256 của số định danh ít entropy vào trường `id_number_hash` không được dùng trong luồng hiện tại; dữ liệu hash cũ trong D1 thật không tự động bị xóa.

## Kết quả kiểm thử cục bộ

- Syntax checks: đạt.
- Migration chain: 6/6.
- UI/source regression: 29/29.
- SCRD Worker với SQLite/D1 giả lập và R2 giả lập: 18/18.
- SCRD ↔ Exam integration: 5/5.
- Exam validation: 31/31.

Đây là các bài test giới hạn theo tình huống đã mã hóa; không phải pentest, quét lỗ hổng độc lập hoặc browser E2E toàn hệ thống.

## Giới hạn/rủi ro cần theo dõi

1. Không có xác minh D1/R2 production, secrets, CORS/origin, DNS, custom domain hoặc email thật trong phiên sửa mã nguồn.
2. `wrangler.toml` và `EXAM/wrangler.json` vẫn có placeholder tên database D1; cần điền đúng từ Cloudflare Dashboard.
3. Chưa xác minh backup/restore và rollback trên dữ liệu thật.
4. Các tài liệu điều khoản/quyền riêng tư là nội dung dự thảo cần phê duyệt.
5. Chat chưa hỗ trợ mã hóa đầu cuối E2EE hoặc realtime WebSocket/DO. Không nên quảng bá các tính năng này.
6. Chưa có job tự động dọn dẹp tệp upload staging mồ côi; cần xác định retention period và cơ chế xoá an toàn.
7. Upload tệp được bảo vệ bởi metadata/endpoint nhưng cần kiểm thử thêm trên trình duyệt và Cloudflare thật trước production.
8. Chưa hoàn thành browser E2E trên production/staging; runtime trình duyệt trong môi trường hiện tại không khởi chạy thành công.
9. Chưa có kiểm toán bảo mật độc lập đối với toàn bộ codebase.

## Điều kiện trước production

- Sao lưu D1, xác minh migration history và thử migration trên staging.
- Xác minh mọi binding/secret/origin/domain trong đúng environment.
- Chạy browser E2E từ đầu đến cuối cho đăng ký, xét duyệt, đổi mật khẩu tạm thời, tra cứu, CMS, chat và Exam.
- Kiểm tra quyền truy cập chéo bằng các vai trò khác nhau và các ID tệp/hội thoại đã biết.
- Kiểm tra phục hồi sau mất mạng, lỗi database, upload thất bại và deploy rollback.
- Phê duyệt nội dung điều khoản/quyền riêng tư và chính sách lưu giữ/cleanup.

**Tuyên bố:** không có production deployment nào được thực hiện trong đợt sửa mã nguồn này.
