# BÁO CÁO ĐIỀU CHỈNH GIAO DIỆN VÀ LUỒNG NGƯỜI DÙNG

## Website công khai

- Loại bỏ thanh tiện ích kỹ thuật khỏi header và loại CTA đăng ký/dashboard CMS khỏi hàng header công khai.
- Giữ điều hướng tám mục theo cấu trúc menu hiện có; các route nghiệp vụ được giữ riêng.
- Chốt lại copy hero theo yêu cầu: tiêu đề “NGHIÊN CỨU KHOA HỌC & PHÁT TRIỂN CỘNG ĐỒNG”, phụ đề ngắn và mô tả riêng biệt, với cặp VI/EN.
- CMS settings cho phép chỉnh các trường hero riêng; migration 0006 chỉ chuẩn hóa các giá trị mặc định đã biết và giữ nội dung tùy chỉnh.
- Bổ sung cache-busting source assets SCRD.

## Đăng ký tài khoản

- Trường tải ảnh ở Bước 3 chỉ nhận ảnh chân dung cá nhân và tài liệu minh chứng bổ sung; backend không nhận purpose `id_front` hoặc `id_back` ở endpoint đăng ký.
- Bổ sung preview chân dung tại Bước 3 và bản rà soát Bước 5, cùng các trường định danh, mục đích và xác nhận chính.
- Payload gửi hồ sơ được dựng từ danh sách field cho phép; data URL preview và field ảnh giấy tờ cũ không được gửi trong payload.
- Bổ sung kiểm tra ngày cấp không ở tương lai và hạn giấy tờ không trước ngày cấp.
- Bước 5 hiển thị nội dung cam kết/điều khoản và các xác nhận tách biệt trước khi ký/gửi.
- Hỗ trợ chữ ký trực tiếp trên canvas hoặc tải ảnh chữ ký; hiển thị preview và bắt buộc có chữ ký hợp lệ trước khi gửi.
- Có bản dịch tiếng Anh cho các nội dung được bổ sung và hành động reset hồ sơ mới.

## Quên mật khẩu và quản trị

- Trang quên mật khẩu dùng hướng dẫn liên hệ quản trị viên hoặc hotline 0924 910 210.
- Endpoint legacy quên/đặt lại mật khẩu trả 410; bảng token cũ được bảo toàn để tương thích, không tuyên bố đã xoá khỏi schema.
- Sửa luồng dashboard overview và `/admin/settings` route.
- Bổ sung/hoàn thiện chi tiết hồ sơ cho reviewer, user/role management cho super admin, cùng luồng cấp mật khẩu tạm thời bắt buộc đổi ở lần đăng nhập.

## Chat

- Thêm luồng chat trực tiếp 1–1 và nhóm, quản lý thành viên.
- Chat attachment được ràng buộc với phòng chat; đọc tệp cần membership.
- Tệp upload trước khi hồ sơ đăng ký được gửi không thể đọc được qua media endpoint kể cả bởi reviewer; sau khi submit mới theo chính sách quyền của hồ sơ.
- Không có E2EE hoặc WebSocket/DO realtime trong bản này.

## Exam

- Cập nhật cache-busting cho asset và kiểm tra origin liên kết SCRD.
- Các luồng làm bài, đồng bộ revision, autosave, nộp bài và chấm điểm máy chủ được bảo toàn và chạy test local.

## Giới hạn kiểm chứng

Đây là thay đổi trong mã nguồn và test local. Không deploy production, không thay đổi dữ liệu production, không xác minh D1/R2 thật. Browser E2E không hoàn tất trong môi trường hiện tại; cần kiểm tra giao diện trên browser/staging thật trước nghiệm thu.
