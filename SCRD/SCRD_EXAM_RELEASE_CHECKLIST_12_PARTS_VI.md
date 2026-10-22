# CHECKLIST NGHIỆM THU 12 PHẦN — SCRD + EXAM

Tài liệu phân biệt những gì có trong mã nguồn với những gì đã được xác minh trong môi trường thật. Dấu “có test cục bộ” không đồng nghĩa đã deploy hoặc đã nghiệm thu production.

## P1 — Rà soát và bảo toàn hệ thống
- [x] Rà soát source SCRD, backend Worker, API, migrations, tests và cổng Exam.
- [x] Giữ ZIP gốc nguyên trạng, sửa trên bản làm việc riêng.
- [x] Bổ sung/duy trì kiểm tra cú pháp và test cục bộ.
- [ ] Xác nhận các cấu hình với tài khoản Cloudflare thực tế.

## P2 — Header, nhận diện và hero
- [x] Xóa thanh kỹ thuật khỏi header công khai trong source.
- [x] Xóa CTA đăng ký/CMS khỏi header công khai trong source.
- [x] Cập nhật tiêu đề/đoạn phụ đề hero mặc định VI/EN.
- [x] Tách mô tả hero thành trường CMS chỉnh sửa được.
- [x] Cập nhật cache-busting frontend.
- [ ] Xác minh ảnh chụp trình duyệt production sau triển khai.

## P3 — Kiến trúc trang và route nghiệp vụ
- [x] Giữ các route riêng cho đăng ký, tra cứu, đăng nhập và quên mật khẩu.
- [x] Route `/admin/settings` đi vào tab cài đặt CMS hiện có và kiểm tra vai trò.
- [ ] Xác nhận mọi route trên môi trường đã triển khai.
- [ ] Không tuyên bố các route là ứng dụng/subdomain độc lập nếu chưa tách kiến trúc.

## P4 — Đăng ký 5 bước
- [x] Bước 3 dùng ảnh chân dung cá nhân; API từ chối mục đích `id_front`/`id_back`.
- [x] Preview ảnh chân dung trong bước 3 và khi rà soát bước 5.
- [x] Payload sử dụng allowlist; không gửi data URL preview/ID photo cũ.
- [x] Kiểm tra ngày cấp và hạn sử dụng ở frontend/backend.
- [x] Kiểm tra giữ/reset state biểu mẫu trong source tests.
- [ ] Kiểm tra E2E bằng trình duyệt thật.

## P5 — Điều khoản, xác nhận và chữ ký
- [x] Hiển thị nội dung cam kết/điều khoản trước các checkbox.
- [x] Tách xác nhận dữ liệu, điều khoản và quyền riêng tư.
- [x] Hỗ trợ ký trên canvas và tải ảnh chữ ký.
- [x] Bắt buộc chữ ký và checkbox phía backend.
- [ ] Nội dung điều khoản phải được đơn vị vận hành duyệt chính thức.
- [ ] Kiểm tra khả năng lưu/hiển thị chữ ký trong môi trường staging thật.

## P6 — Tra cứu hồ sơ
- [x] Có route và API tra cứu riêng.
- [x] Kiểm thử response công khai không trả dữ liệu định danh/ghi chú nội bộ.
- [ ] Xác minh throttling, dữ liệu và kết quả trên D1 thật.

## P7 — Đăng nhập và hỗ trợ quên mật khẩu
- [x] Trang quên mật khẩu hướng dẫn liên hệ quản trị viên/hotline `0924 910 210`.
- [x] API legacy forgot/reset token trả HTTP 410.
- [x] Có luồng đổi mật khẩu bắt buộc sau mật khẩu tạm thời.
- [x] Đổi mật khẩu thu hồi các phiên khác.
- [ ] Chưa kiểm tra email/hotline thực tế và mọi luồng phiên trên production.

## P8 — Quản trị, CMS và chat
- [x] Dashboard/API overview và route settings được kiểm tra.
- [x] Có xem chi tiết hồ sơ và quyền hiển thị ảnh/chữ ký cho reviewer.
- [x] Có quản lý người dùng/role và cấp mật khẩu tạm thời cho super admin.
- [x] Chat 1–1, nhóm và kiểm tra thành viên ở backend.
- [x] Tệp chat kiểm tra membership.
- [x] Tệp hồ sơ staging chưa gửi bị chặn, kể cả với reviewer.
- [ ] Chưa có E2EE hoặc WebSocket/DO realtime.
- [ ] Chưa có bằng chứng CMS drag-and-drop đầy đủ; hệ thống vẫn dùng module/tab hiện có.

## P9 — Website công khai
- [x] Có 8 route/menu seed và test UI cho menu.
- [x] Nội dung dài Trang chủ/Giới thiệu song ngữ vượt ngưỡng kiểm tra tự động.
- [x] Hero VI/EN có trường title/subtitle/description riêng.
- [x] Có test source contract cho responsive, link protocol và header.
- [ ] Chưa kiểm tra trực quan tất cả trang bằng browser E2E thật.
- [ ] Chưa nghiệm thu nội dung VI/EN theo biên tập ngữ nghĩa.

## P10 — Exam
- [x] Test các loại câu hỏi, giờ thi, autosave/revision, nhiều tab và payload.
- [x] Test integration launch token, attempt, server scoring và receipt.
- [x] Cập nhật cache-busting và origin trong source.
- [ ] Tên database trong `EXAM/wrangler.json` cần được xác nhận, không được đoán.
- [ ] Chưa nghiệm thu một kỳ thi trên môi trường Cloudflare thật.

## P11 — Bảo mật, quyền và dữ liệu
- [x] Test CSRF, bootstrap one-time và access policy đã có.
- [x] Tệp hồ sơ riêng tư được kiểm soát theo trạng thái gắn vào hồ sơ.
- [x] Dữ liệu định danh và chữ ký dùng encryption helper ở backend hiện có.
- [x] Không xóa bừa token phiên/CSRF/Exam hoặc bảng reset cũ.
- [ ] Cần audit bảo mật độc lập và test production/staging.
- [ ] Cần xác minh backup, key recovery và chính sách retention/cleanup tệp staging.

## P12 — Kiểm thử và đóng gói
- [x] Syntax check đạt.
- [x] Migration chain: 6/6.
- [x] Content checks: 6/6 (độ dài, cấu trúc và không lặp đoạn).
- [x] UI regression: 29/29.
- [x] SCRD smoke: 18/18.
- [x] Integration SCRD ↔ Exam: 5/5.
- [x] Exam validation: 31/31.
- [x] Chạy lại test trên ZIP sau khi giải nén vào thư mục sạch; xem `TEST_LOG_FULL_REPAIR_20261022.txt`.
- [ ] Chưa deploy production.

## Tóm tắt kiểm thử

- 89 kiểm tra nội dung/UI/nghiệp vụ cục bộ: 6 + 29 + 18 + 5 + 31; cộng 19 release audit = 108 kiểm tra tự động.
- Chuỗi migration 6/6 theo thứ tự.
- Syntax check đạt.
- Đây không phải 108 bài browser E2E; gồm kiểm tra tĩnh và test local với SQLite/R2 giả lập.

## Cấu hình cần xử lý trước production

- `wrangler.toml`: `REPLACE_WITH_ACTUAL_D1_DATABASE_NAME`.
- `EXAM/wrangler.json`: `CONFIRM_ACTUAL_D1_DATABASE_NAME`.
- Xác minh đúng bucket R2, secrets, DNS, custom domain, bindings và migration history.
- Sao lưu D1, staging test và rollback plan trước khi thay đổi production.


## Bổ sung cho bản Super Comprehensive
- [x] Trình quản lý bố cục Trang chủ: thứ tự, bật/tắt khối, lưu CMS/D1, kiểm tra backend.
- [x] Khối Trang chủ dữ liệu thật: khảo thí, công bố/tài liệu, đối tác đã xác minh.
- [x] Quản lý danh sách/sửa/xóa nghiên cứu, dự án, nhiệm vụ; kiểm soát liên kết và tính lại tiến độ.
- [x] Nội dung long-form VI/EN đã giảm trùng lặp; test kiểm tra 380 đoạn không lặp nguyên văn.
- [x] Release audit 19/19.
- [ ] Browser E2E trên staging/production — chưa thực hiện.
- [ ] Xác minh D1 name/secrets/bindings thật — cần người vận hành có quyền Cloudflare.
