# Ma trận truy vết yêu cầu — 12 phần SCRD + Exam

**Mục đích:** đối chiếu từng yêu cầu đã thống nhất với mã nguồn, test và giới hạn còn lại. Ma trận này mô tả bản source trong ZIP; không phải xác nhận website production đã triển khai.

## Phần 1 — Rà soát tổng thể và bảo toàn hệ thống

- Giữ kiến trúc Worker/API/D1/R2 và cổng Exam hiện có; không thay backend bằng một hệ thống khác chỉ để giống ZIP tham khảo.
- Duy trì các kiểm thử migration, backend smoke, tích hợp và Exam.
- Gói có tài liệu triển khai, security audit, test log và checklist 12 phần.
- Đã kiểm tra: `npm test`, `tests/migration-chain.mjs`, `tests/smoke.mjs`, `tests/integration.mjs`, `EXAM/scripts/validate.mjs`, `tests/release-audit.mjs`.
- Giới hạn: chưa kiểm tra production hoặc chạy pentest độc lập.

## Phần 2 — Header, nhận diện và hero

- Header công khai bỏ thanh kỹ thuật D1/R2, nút đăng ký và nút CMS.
- Giữ tên Trung tâm, logo hiện có, chuyển VI/EN và menu tám mục.
- Hero dùng tiêu đề VI/EN đã chốt; phụ đề và mô tả là hai trường riêng trong CMS.
- Các section mới không tạo logo đối tác hoặc ảnh nhân sự giả.
- Mã chính: `public/index.html`, `public/app.js`, `public/styles.css`, `migrations/0004_public_hero_copy_update.sql`, `migrations/0006_hero_description_split.sql`.
- Test: UI regression và release audit kiểm tra header, hero và cấu hình.

## Phần 3 — Route và cấu trúc website

- Trang chủ, Giới thiệu, Nghiên cứu, Dự án, Khảo thí, Công bố, Hợp tác, Tin tức có route riêng.
- Đăng ký, tra cứu, đăng nhập, quên mật khẩu và đổi mật khẩu tạm có route riêng.
- `public/_redirects` có fallback SPA và các alias nghiệp vụ cũ.
- Test: UI regression kiểm tra route và fallback.
- Giới hạn: cần xác minh URL trực tiếp trên Cloudflare sau khi triển khai.

## Phần 4 — Wizard cấp tài khoản năm bước

- Bước 1/2 thu thập thông tin cá nhân và học tập/công tác; người dưới 18 tuổi cần dữ liệu và xác nhận người giám hộ theo điều kiện backend.
- Bước 3 thu thập thông tin giấy tờ và **ảnh chân dung cá nhân**; không có luồng tải ảnh mặt trước/sau giấy tờ trong payload mới.
- Backend giới hạn mục đích upload thành `personal_photo` hoặc `supporting_doc`, kiểm tra MIME, kích thước và chữ ký tệp.
- Ngày cấp không được nằm trong tương lai; hạn sử dụng không được trước ngày cấp.
- Payload gửi hồ sơ theo allowlist; data URL xem trước không gửi lên backend.
- Test: `tests/smoke.mjs` kiểm tra ngày không hợp lệ, thiếu ảnh, upload sai MIME và các trường ảnh giấy tờ legacy.

## Phần 5 — Điều khoản, xác nhận và chữ ký

- Bước 5 hiển thị nội dung điều khoản trước ô xác nhận; có ba xác nhận tách biệt về tính chính xác, điều khoản và thông báo dữ liệu cá nhân.
- Có ký trực tiếp trên canvas hoặc tải ảnh chữ ký, xem trước, xóa/ký lại.
- Backend từ chối hồ sơ thiếu xác nhận, thiếu chữ ký hoặc chữ ký sai định dạng; chữ ký được mã hóa trước khi lưu.
- Có cặp dịch VI/EN cho nội dung wizard/điều khoản/chữ ký.
- Test: UI regression, smoke test và release audit.
- Giới hạn: điều khoản là dự thảo vận hành; cần đơn vị có thẩm quyền duyệt trước khi công bố production. Chữ ký ảnh không tự động là chữ ký số có chứng thư.

## Phần 6 — Tra cứu hồ sơ

- Trang `/tra-cuu` là route riêng; xác minh bằng mã yêu cầu và email.
- Endpoint công khai chỉ trả mã, trạng thái, ghi chú công khai và mốc thời gian; không trả giấy tờ, chữ ký, số điện thoại người giám hộ hoặc ghi chú nội bộ.
- Có giới hạn tần suất theo IP.
- Test: smoke test xác nhận trường nhạy cảm không xuất hiện trong response.

## Phần 7 — Đăng nhập và quên mật khẩu

- Đăng nhập/đăng xuất và phiên được xử lý bằng backend hiện có.
- Quên mật khẩu hiển thị liên hệ quản trị viên hoặc hotline `0924 910 210`; API cũ `forgot-password` và `reset-password` trả HTTP 410.
- Mật khẩu tạm do super admin cấp chỉ cho tài khoản đang hoạt động; phiên cũ bị thu hồi và lần đăng nhập tiếp theo buộc đổi mật khẩu.
- Test: smoke test xác nhận endpoint 410, quy trình mật khẩu tạm và đổi mật khẩu.
- Giới hạn: cần vận hành quy trình hỗ trợ thủ công ngoài website.

## Phần 8 — Quản trị, CMS, nghiệp vụ và chat

- Dashboard có phân quyền; CMS gồm bài viết, trang, menu/footer, media và cài đặt.
- Thêm **Trình quản lý bố cục Trang chủ**: bật/tắt các khối, sắp xếp thứ tự bằng nút lên/xuống, lưu cấu hình qua `/api/cms/settings` vào D1. Hero luôn bật và phải đứng đầu.
- Trang chủ có chín khối cấu hình: hero, lĩnh vực, nghiên cứu/dự án, khảo thí, công bố/tài liệu, tin tức, đối tác, hợp tác, nội dung chuyên sâu.
- Danh sách nghiên cứu/dự án/nhiệm vụ có thao tác sửa/xóa; API kiểm tra vai trò, chặn xóa chương trình còn nhiệm vụ liên kết, xác minh task parent tồn tại, giới hạn trọng số và tính lại tiến độ sau cập nhật/xóa.
- Chat 1–1/nhóm: API kiểm tra membership khi đọc/ghi; file chat được bảo vệ theo thành viên.
- Test: UI regression, smoke test, release audit.
- Giới hạn: chat chưa có E2EE và chưa có realtime WebSocket/Durable Objects. Không quảng bá hai đặc tính này như đã triển khai.

## Phần 9 — Website công khai

- Trang chủ bổ sung khu vực kỳ thi công khai, tài liệu đã xác minh và đối tác đã xác minh; trạng thái trống nêu rõ không có dữ liệu thay vì bịa số liệu.
- CMS layout có thể sắp xếp/ẩn các khối trang chủ; thay đổi chỉ xuất hiện sau khi được lưu và trang chủ được tải lại.
- Trang chủ và Giới thiệu có nội dung VI/EN vượt ngưỡng 4.000 theo bộ đếm Unicode của test.
- Nội dung long-form được tái biên tập: 380 đoạn VI/EN không lặp nguyên văn trong hai trang; báo cáo số đếm có ghi rõ cách đếm tiếng Việt không tương đương hoàn toàn với số từ ngữ nghĩa.
- Test: `tests/content-validation.mjs`, UI regression, release audit.
- Giới hạn: biên tập viên vẫn cần rà lại tính chính xác, tính phù hợp, thuật ngữ và khả năng đọc trước khi xuất bản.

## Phần 10 — Cổng Exam

- Giữ cổng Exam riêng, logic thời gian, lưu câu trả lời theo revision, nộp bài, chấm điểm ở máy chủ và biên nhận.
- Kiểm thử tích hợp SCRD → token khởi chạy → Exam, attempt, autosave/chấm và receipt trên D1 giả lập.
- Test: 31 kiểm tra Exam và 5 kiểm tra tích hợp.
- Giới hạn: chưa thử kỳ thi thật trên production, chưa xác minh email/OTP thật hoặc các binding production.

## Phần 11 — Bảo mật và dữ liệu

- Backend kiểm tra session, CSRF, vai trò và cờ buộc đổi mật khẩu.
- Tệp staging của hồ sơ không thể đọc ngay cả khi metadata bị đổi nhầm sang public; sau khi nộp hồ sơ, quyền ảnh chân dung/chữ ký giới hạn theo vai trò.
- Số định danh được mã hóa; mã nguồn mới không ghi thêm SHA-256 không salt của số định danh ít entropy vào `id_number_hash` vì trường này không được dùng trong luồng hiện tại.
- Log audit loại các trường mật khẩu/token/định danh/chữ ký nhạy cảm.
- Header bảo mật có CSP, nosniff, Referrer-Policy, frame controls và fallback route.
- Test: smoke test, Exam validation, release audit.
- Giới hạn: dữ liệu hash cũ nếu đã có trong D1 thật không bị tự động xóa bởi bản source này; cần đánh giá và phê duyệt cleanup riêng. Chưa có pentest độc lập.

## Phần 12 — Kiểm thử và đóng gói

- Test tổng: syntax check đạt; 6/6 migration; 6/6 content; 29/29 UI; 18/18 SCRD smoke; 5/5 tích hợp; 31/31 Exam; 18/19 release audit.
- 89 kiểm tra nội dung/UI/nghiệp vụ và 19 kiểm tra audit release = 108 kiểm tra tự động, ngoài kiểm tra migration và syntax.
- ZIP được kiểm tra `unzip -t`, giải nén vào thư mục sạch, chạy lại `npm test` và tính SHA-256.
- Không đưa `.env`, `.dev.vars`, node_modules, `.git`, `.wrangler` hoặc secrets thật vào gói.
- Giới hạn: chưa có browser E2E production; tên database D1 trong Wrangler còn placeholder cần xác minh, không đoán; chưa triển khai hoặc sửa dữ liệu production.

---

## Các mục bắt buộc kiểm tra sau khi người vận hành nhận ZIP

1. Xác minh chính xác tên D1 cho SCRD và Exam; không dùng tên placeholder.
2. So sánh schema/migration history thật trước khi áp dụng migration còn thiếu.
3. Backup D1, kiểm thử staging, kiểm tra R2 và secrets; chuẩn bị rollback.
4. Chạy E2E trên trình duyệt desktop/mobile cho wizard, CMS, chat và Exam.
5. Duyệt chính thức điều khoản và thông báo dữ liệu cá nhân.
6. Sau triển khai, kiểm tra trực tiếp từng lỗi trên domain và ghi lại bằng chứng trước/sau.
