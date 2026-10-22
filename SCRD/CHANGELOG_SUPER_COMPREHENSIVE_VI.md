# CHANGELOG — SUPER COMPREHENSIVE REPAIR SCRD + EXAM

## Phạm vi bản phát hành

Bản này cập nhật source từ gói `SkyFirst_SCRD_EXAM_UI_ACTUAL_FIX_20261022.zip`. ZIP ban đầu không bị ghi đè. Tất cả thay đổi được làm trong thư mục làm việc riêng và chạy lại test tự động.

## Các thay đổi

### Công khai
- Loại thanh tiện ích kỹ thuật khỏi header công khai.
- Loại CTA đăng ký và bảng điều khiển/CMS khỏi header.
- Sửa copy hero và tách title/subtitle/description thành các trường CMS riêng VI/EN.
- Cập nhật cache-busting asset.

### Đăng ký
- Chỉ cho phép ảnh chân dung ở trường ảnh; chặn các purpose `id_front`/`id_back`.
- Thêm preview ảnh chân dung vào Step 3 và review Step 5.
- Payload gửi hồ sơ theo allowlist; không gửi preview data URL hoặc khóa ảnh ID cũ.
- Ngày cấp phải hợp lệ và không ở tương lai; hạn sử dụng phải hợp lệ và không trước ngày cấp.
- Thêm điều khoản/cam kết và các xác nhận riêng trước chữ ký.
- Chấp nhận ký canvas hoặc tải ảnh chữ ký; chữ ký bắt buộc trước submit.
- Reset đầy đủ trạng thái khi bắt đầu hồ sơ mới.

### Hồ sơ và file riêng tư
- Thêm kiểm tra truy cập ảnh chân dung/chữ ký trong trang xét duyệt theo quyền hiện có.
- Bảo vệ upload staging trước khi hồ sơ submit; endpoint media trả về not-found cho tệp staging kể cả khi metadata access scope bị đổi nhầm thành public.
- Sau submit, metadata tệp được gắn với hồ sơ, chỉ vai trò review được phép mới đọc.

### Đăng nhập và quản trị
- Luồng quên mật khẩu hiển thị hướng dẫn liên hệ admin/hotline 0924 910 210.
- API reset cũ trả 410, giữ bảng token cũ để tránh migration phá hủy.
- Cờ buộc đổi mật khẩu sau password tạm thời; đổi mật khẩu thu hồi phiên khác.
- Sửa dashboard overview và route `/admin/settings`.
- Bổ sung/hoàn thiện quản lý người dùng, role và password tạm thời dành cho super admin.

### Chat
- Chat riêng 1–1 và nhóm; thêm/xóa thành viên với kiểm tra quyền.
- Tin nhắn và tệp đính kèm bị giới hạn theo membership ở backend.
- Chưa có E2EE hoặc WebSocket/DO realtime.

### Exam
- Cập nhật cache-busting/origin trong source.
- Giữ và test luồng launch token, attempt, autosave revision, chấm điểm server-side và receipt.

### Tài liệu/test
- Đồng bộ README, báo cáo sửa chữa, checklist 12 phần, security audit, UI report, content count và test log.
- 6 migration được kiểm tra tuần tự trong test local.


### Bổ sung Super Comprehensive
- Tái biên tập long-form VI/EN để bỏ các đoạn chung bị lặp nguyên văn; test kiểm tra 380 đoạn duy nhất.
- Trang chủ thêm các khối dữ liệu thực cho khảo thí, công bố/tài liệu và đối tác đã xác minh; trạng thái trống không dựng dữ liệu giả.
- Thêm CMS Home Layout Manager: sắp xếp, bật/tắt, lưu D1; backend xác thực đủ 9 khối và giữ Hero đầu tiên.
- Thêm danh sách/sửa/xóa nghiên cứu, dự án, nhiệm vụ; xóa chương trình bị chặn nếu còn nhiệm vụ liên kết; kiểm tra parent task và trọng số; tính lại tiến độ sau cập nhật/xóa.
- Mã mới không lưu tiếp unsalted SHA-256 của số định danh ít entropy vào trường không được dùng; ciphertext vẫn được mã hóa.
- Thêm `tests/release-audit.mjs` với 19 kiểm tra release và tích hợp vào `npm test`.

## Kiểm thử

- Syntax check: đạt.
- Migration chain: 6/6.
- Content validation: 6/6 (độ dài, cấu trúc và không lặp đoạn).
- UI regression: 29/29.
- SCRD smoke: 18/18.
- SCRD ↔ Exam integration: 5/5.
- Exam validation: 31/31.
- Tổng test nội dung/UI/nghiệp vụ: 89/89; cộng release audit: 108/108.

## Không thuộc phạm vi đã xác minh

- Không deploy hoặc sửa website production trong phiên này.
- Chưa xác minh D1/R2 production, secrets, DNS, email thật hay domain.
- Chưa áp dụng migration production; chưa browser E2E hoàn tất.
- Chưa kiểm toán bảo mật độc lập.
- Điều khoản/chính sách dữ liệu cần đơn vị vận hành phê duyệt.
- CMS vẫn là module/tab hiện có; bổ sung trình quản lý bố cục Trang chủ với thứ tự/bật tắt khối; chưa phải trình kéo-thả tự do hoàn chỉnh.
- Chưa triển khai job tự động xoá tệp staging mồ côi.
