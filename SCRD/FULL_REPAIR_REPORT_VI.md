# BÁO CÁO SỬA CHỮA TOÀN DIỆN SCRD + EXAM

**Bản:** Full Repair — 22/10/2026  
**Thư mục gốc khi triển khai:** `SCRD_UI_Release_20261022/` (thư mục chứa trực tiếp `wrangler.toml`, `backend_worker.js`, `public/`, `migrations/` và `package.json`).  
**Website SCRD:** `https://scrd.skyfirst.io.vn`  
**Cổng Exam:** `https://exam.skyfirst.io.vn`  
**Hotline khôi phục tài khoản:** `0924 910 210`  
**Email hỗ trợ:** `support@skyfirst.io.vn`

## 1. Phạm vi và phương pháp

Bản làm việc được tạo từ ZIP SCRD + Exam đã cung cấp. `wed-main.zip` được dùng làm tài liệu tham khảo cho cách tổ chức giao diện quản trị/CMS; không sao chép framework hoặc thay thế kiến trúc backend hiện có. ZIP gốc chưa bị sửa trực tiếp. Các thay đổi được kiểm tra bằng syntax checks và test tự động trên dữ liệu SQLite/R2 giả lập.

## 2. Các thay đổi đã thực hiện trong mã nguồn

### Giao diện công khai và điều hướng
- Loại bỏ thanh tiện ích kỹ thuật khỏi `public/index.html`; bỏ nút Đăng ký và Bảng điều khiển/CMS khỏi header công khai, đồng thời loại bỏ logic JavaScript trước đây dựng lại các thành phần đó.
- Cập nhật tiêu đề hero VI/EN theo nội dung đã chốt; chỉnh nội dung mô tả mặc định. Migration `0004_public_hero_copy_update.sql` chỉ cập nhật giá trị mặc định cũ đã biết và không ghi đè nội dung tùy chỉnh khác.
- Giữ điều hướng tám mục, header thương hiệu, chuyển ngôn ngữ và đường dẫn riêng cho các trang nghiệp vụ.
- Thêm class route quản trị để ẩn navigation/footer công khai trong khu vực quản trị và cập nhật cache-busting cho SCRD/Exam assets.

### Biểu mẫu yêu cầu cấp tài khoản
- Bước 3 chỉ hiển thị trường tải **ảnh chân dung cá nhân**; bỏ đầu vào ảnh mặt trước/mặt sau giấy tờ khỏi giao diện. Backend chỉ chấp nhận upload `personal_photo` và `supporting_doc`, từ chối `id_front`/`id_back`. Các cột schema cũ được giữ lại vì tương thích dữ liệu.
- Bước 5 có nội dung điều khoản hiển thị, phần giải thích cam kết/riêng tư và ba xác nhận riêng biệt: tính chính xác, thông báo dữ liệu cá nhân, điều khoản.
- Bổ sung ký trực tiếp bằng chuột/ngón tay (canvas), tải ảnh chữ ký, xem trước, xóa/ký lại và yêu cầu chữ ký cùng đủ xác nhận trước khi gửi.
- Backend kiểm tra các xác nhận và chữ ký, mã hóa thông tin định danh/chữ ký bằng `ID_ENCRYPTION_KEY`, gắn ảnh chân dung với hồ sơ trong R2 riêng tư.
- Bổ sung bản dịch tiếng Anh cho nội dung wizard và trạng thái nộp hồ sơ.

### Quên mật khẩu và quy trình duyệt hồ sơ
- Trang quên mật khẩu chuyển sang hướng dẫn liên hệ quản trị viên/hotline `0924 910 210`, có nút gọi trực tiếp; không đưa luồng token/email tự đặt lại mật khẩu trở lại.
- API tự đặt lại mật khẩu qua token trả về HTTP 410 để không tiếp tục luồng đã bỏ; không xóa bảng token cũ nhằm tránh thay đổi schema/di trú phá hủy.
- Bỏ biểu mẫu Bootstrap công khai tại trang đăng nhập. Endpoint bootstrap backend chỉ còn có thể hoạt động theo điều kiện bảo vệ phía máy chủ và cấu hình secret; chưa xóa secret hoặc token cần thiết cho xác thực/Exam.
- Duyệt hồ sơ không còn tạo liên kết kích hoạt qua trang quên mật khẩu. Thêm giao diện xem hồ sơ/ảnh chân dung/chữ ký theo vai trò được phép và module super-admin quản lý trạng thái/vai trò người dùng, cấp mật khẩu tạm thời một lần và thu hồi phiên cũ. Mật khẩu tạm không được ghi vào audit log.

### Dashboard, chat và quản trị
- Sửa lỗi gọi API dashboard trùng lặp làm lệch gán dữ liệu và sửa tham số ngôn ngữ ở hàm render tab quản trị.
- Bổ sung giao diện tìm liên hệ, chat riêng 1–1, tạo nhóm riêng, xem danh sách thành viên, thêm/xóa thành viên theo quyền.
- Bổ sung/hoàn thiện endpoint backend contacts/rooms/members; danh sách tin nhắn, đọc/ghi hội thoại và tệp phải kiểm tra thành viên. Có giới hạn gửi và không trả số điện thoại/email của người dùng trong danh sách liên hệ.
- Chat hiện cung cấp bảo mật dựa trên xác thực/thành viên và quyền truy cập. **Chưa triển khai mã hóa đầu cuối E2EE hoặc realtime bằng WebSocket/Cloudflare Durable Objects**; không được coi là đã có các đặc tính này.

### SCRD + Exam, cấu hình và kiểm thử
- Sửa liên kết `connect-src` cũ của Exam từ domain legacy sang domain SCRD/Exam đã thống nhất.
- Cập nhật health check của Exam về endpoint SCRD hiện hành và cập nhật phiên bản cache-busting assets.
- Giữ nguyên cơ chế bài thi, autosave, chấm điểm và biên nhận hiện có; bộ test tích hợp được chạy lại.

## 3. Kết quả kiểm thử đã chạy

Lệnh chạy: `npm test` trong thư mục gốc của dự án.

| Nhóm | Kết quả |
|---|---:|
| Kiểm tra cú pháp JS của các module được cấu hình | Đạt |
| Nội dung Trang chủ/Giới thiệu VI/EN | 4/4 |
| Hồi quy giao diện | 17/17 |
| SCRD Worker + D1 SQLite + R2 giả lập | 16/16 |
| Tích hợp SCRD ↔ Exam | 5/5 |
| Kiểm định Exam | 31/31 |
| **Tổng kiểm tra nội dung/UI/nghiệp vụ** | **73/73 đạt** |

Các bài smoke/integration sử dụng SQLite trong bộ test và R2 giả lập. Kết quả đạt có ý nghĩa cho các trường hợp được kiểm tra, nhưng không chứng minh toàn bộ đường đi trình duyệt hoặc hệ thống production đã hoàn tất.

## 4. Cấu hình còn cần xác minh trước triển khai

Trong ZIP, tên database vẫn là placeholder ở hai file cấu hình:

- `wrangler.toml`: `REPLACE_WITH_ACTUAL_D1_DATABASE_NAME`
- `EXAM/wrangler.json`: `CONFIRM_ACTUAL_D1_DATABASE_NAME`

Không tự đoán tên D1. Người có quyền Cloudflare phải xác nhận tên thật, binding `DB`, binding/bucket R2 `FILES` / `scrd-files`, secrets, DNS, custom domain và chính sách môi trường. Cần kiểm tra `BOOTSTRAP_SECRET_TOKEN`, `ID_ENCRYPTION_KEY` và cấu hình email nếu sử dụng. Không đưa giá trị secrets thật vào ZIP.

Migration `migrations/0004_public_hero_copy_update.sql` được thêm để cập nhật nội dung hero mặc định cũ; chỉ áp dụng sau khi sao lưu, kiểm tra bảng `system_config` và đối chiếu lịch sử migration. Không chạy lại toàn bộ schema hoặc migration trên production một cách mù quáng.

## 5. Các giới hạn/chưa được xác minh

- **Chưa triển khai lên Cloudflare production** vì không có phiên truy cập/quyền triển khai trong công việc này. Website live không thay đổi chỉ vì có ZIP mới.
- **Chưa xác minh trên domain production** các binding, dữ liệu D1/R2 thật, secrets, gửi email, DNS, custom domain, migration và các luồng người dùng.
- Bộ test hiện là cú pháp/test logic/SQLite/R2 giả lập; chưa thay thế kiểm thử browser E2E thủ công toàn bộ màn hình desktop/mobile trên domain.
- Nội dung điều khoản bước 5 là nội dung dự thảo để làm rõ trước khi tích; Trung tâm cần duyệt câu chữ chính thức và đối chiếu với trang chính sách/điều khoản công khai.
- Module chat có kiểm soát thành viên nhưng chưa có E2EE/realtime streaming.
- Chưa thể xác nhận mức độ hoàn chỉnh của mọi module CMS/SEO/drag-and-drop trong môi trường production nếu không có tài khoản và dữ liệu Cloudflare thực tế.
- Đề xuất kiểm thử staging riêng cho cấp mật khẩu tạm thời, thông báo email duyệt hồ sơ và quy trình liên hệ người dùng. Nếu hệ thống email ngoài dùng mẫu cũ có chứa link activation, cần cập nhật mẫu theo quy trình hotline trước production.

## 6. Hướng dẫn đóng gói/triển khai

- Thư mục đúng để chạy Wrangler là thư mục này, nơi có trực tiếp `wrangler.toml`, `backend_worker.js`, `public/`, `migrations/` và `package.json`.
- Chạy `npm test` trước khi đóng gói.
- Sao lưu D1 và thử migration trên staging trước khi áp dụng.
- Điền tên D1 chính xác và kiểm tra quyền/binding/secrets.
- Triển khai SCRD và Exam theo quy trình Cloudflare riêng, sau đó mở website và chạy E2E thực tế.
- Sau khi phát hiện vấn đề, sửa mã nguồn rồi chạy lại đầy đủ test trên ZIP cuối đã giải nén.

## 7. Kết luận

Bản mã nguồn đã được sửa và kiểm thử cục bộ với 73/73 kiểm tra nội dung/UI/nghiệp vụ đạt cùng các kiểm tra cú pháp. Các sửa chữa nổi bật gồm loại bỏ thanh kỹ thuật khỏi header công khai, cập nhật hero, ảnh chân dung tại Bước 3, nội dung điều khoản/xác nhận/chữ ký Bước 5, hotline quên mật khẩu, xem hồ sơ duyệt, quản lý người dùng/mật khẩu tạm thời, chat 1–1/nhóm và cập nhật cấu hình Exam.

**Không tuyên bố website production đã được sửa hoặc deploy.** Cần hoàn tất cấu hình Cloudflare, áp dụng migration phù hợp và kiểm thử staging/production trước khi coi dự án đã nghiệm thu toàn diện.
