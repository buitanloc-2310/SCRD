# Báo cáo kiểm tra sơ bộ — cần xử lý trước khi triển khai

1. **Bootstrap có thông tin mặc định trong HTML**: `SFN-BOOTSTRAP-SECRET-2026`, email quản trị và mật khẩu mẫu được điền sẵn. Phải xóa giá trị mặc định; đổi mọi secret đã từng xuất hiện trong mã nguồn; chỉ dùng Cloudflare Secret và khởi tạo một lần ở backend.
2. **Bootstrap giả lập ở frontend**: `executeBootstrapAdmin()` chỉ đặt `AppState.bootstrapLocked = true` và hiện thông báo thành công; không gọi API. Không được hiển thị “đã khởi tạo” khi backend chưa xác nhận.
3. **Đăng ký giả lập trong HTML**: `submitAccountRequest5Steps()` tạo mã bằng `Math.random()` và lưu vào `AppState` phía trình duyệt, đồng thời dùng ngày giờ cố định. Không coi đây là yêu cầu đã lưu D1. Phải gửi dữ liệu tới API backend, nhận mã do backend tạo, và chỉ báo thành công sau khi D1 xác nhận.
4. **Thiếu trường biểu mẫu so với yêu cầu**: cần hoàn thiện giới tính Nam/Nữ, ngày cấp/nơi cấp/hạn giấy tờ, tải ảnh giấy tờ an toàn, phân loại vai trò/nhóm, trường/lớp/khoa/chuyên ngành/chức vụ theo điều kiện, email/quan hệ người giám hộ, xác nhận tính chính xác và điều khoản; kiểm tra cùng một bộ quy tắc ở backend.
5. **Xác minh tuổi dùng ngày cố định**: `new Date('2026-10-21')` phải thay bằng ngày hiện tại tại runtime và kiểm tra ngày sinh hợp lệ.
6. **Rò rỉ lỗi nội bộ**: Worker trả `details: err.message` trong phản hồi 500. Không trả chi tiết lỗi/SQL/binding ra công khai; ghi log đã lọc dữ liệu nhạy cảm ở phía server.
7. **Không đồng bộ session**: schema định nghĩa `user_sessions` với `revoked`, trong khi Worker truy vấn/ghi `sessions` và `revoked_at`. Cần thống nhất tên bảng/cột trước khi login có thể hoạt động.
8. **Vai trò chưa đồng bộ**: Worker dùng `researcher`, `project_lead`; cần so với CHECK constraint trong schema và thống nhất enum toàn hệ thống.
9. **Bộ test không khớp tệp**: test gốc dùng đường dẫn cố định `/working_dir/...` và các tên tệp không giống tệp được cung cấp; chưa thể xem test đó là đã chạy thành công.
10. **Khảo thí**: chưa có bằng chứng tích hợp thật với `https://exam.skyfirst.io.vn`; phải xác minh luồng đăng nhập, phân quyền, bài làm, điểm và callback/API trước khi tuyên bố đã kết nối.
11. **R2**: mọi tệp riêng tư phải tải qua endpoint backend đã xác thực/ủy quyền hoặc URL ký có hạn; không trả khóa hay URL công khai cho dữ liệu riêng tư.
12. **Trang công khai**: chỉ trả dữ liệu đã đánh dấu public ở backend; không dựa vào ẩn bằng CSS/JavaScript. Kiểm tra cả HTML, source map, API response, cache và lỗi.

## Trạng thái
Đây là đánh giá tĩnh từ mã nguồn được cung cấp, không phải pentest và không phải xác nhận triển khai. Chưa có mục nào được đánh dấu PASS nếu chưa chạy kiểm thử thực tế.
