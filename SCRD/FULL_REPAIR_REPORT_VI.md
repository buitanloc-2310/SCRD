# BÁO CÁO SỬA CHỮA CHUYÊN SÂU — SCRD + EXAM

**Bản nguồn:** `SkyFirst_SCRD_EXAM_UI_ACTUAL_FIX_20261022.zip`  
**Bản phát hành được chuẩn bị:** `SkyFirst_SCRD_EXAM_SUPER_COMPREHENSIVE_REPAIR_20261022.zip`  
**Ngày ghi nhận:** 22/10/2026  
**Phạm vi:** sửa mã nguồn và kiểm thử cục bộ; không triển khai production.

## 1. Kết luận điều hành

Bản sửa tập trung vào các điểm người dùng đã xác nhận và các lỗi/thiếu sót có thể kiểm tra trong mã nguồn SCRD + Exam. Mã nguồn được sửa trong thư mục làm việc riêng; gói ZIP gốc không bị ghi đè. Toàn bộ test tự động được chạy lại sau các thay đổi mới nhất.

**Giới hạn quan trọng:** đây không phải nghiệm thu toàn diện trên website production. Chưa deploy lên Cloudflare, chưa áp dụng migration vào D1 thật, chưa xác minh binding/secrets thật và không có bằng chứng hoàn tất browser E2E trên domain thật. Các bài test D1/R2 sử dụng SQLite và R2 giả lập.

## 2. Các thay đổi đã thực hiện trong mã nguồn

### 2.1 Website công khai và giao diện

- Loại thanh tiện ích kỹ thuật khỏi header công khai, gồm trạng thái D1/R2 và các đường dẫn nghiệp vụ/Bootstrap/CMS đặt sai vị trí.
- Loại các CTA đăng ký tài khoản và dashboard/CMS khỏi header công khai, giữ lại route nghiệp vụ độc lập.
- Cập nhật nội dung hero mặc định theo bản tiếng Việt và tiếng Anh đã chốt; phân tách tiêu đề, phụ đề và mô tả thành trường có thể quản trị.
- Giữ hệ menu 8 mục và xử lý route `/admin/settings` để chuyển tới tab cài đặt CMS hiện có, với kiểm tra phiên/vai trò.
- Cập nhật cache-busting cho CSS/JavaScript SCRD và asset Exam để giảm nguy cơ dùng cache asset cũ sau khi tự triển khai.
- Giữ logo/asset đã có trong source; không yêu cầu tạo ảnh AI giả danh nhân sự.

### 2.2 Đăng ký tài khoản năm bước

- Bước 3 chỉ nhận ảnh chân dung cá nhân và tài liệu minh chứng bổ sung; endpoint upload từ chối mục đích `id_front`/`id_back`.
- Bổ sung xem trước ảnh chân dung trong bước 3 và bản rà soát bước 5. Dữ liệu xem trước dạng data URL chỉ dùng ở giao diện; payload gửi backend dùng allowlist rõ ràng, không gửi preview hoặc các khóa ảnh giấy tờ cũ.
- Kiểm tra ngày cấp không nằm trong tương lai; hạn sử dụng, nếu có, phải đúng định dạng và không trước ngày cấp ở cả frontend lẫn backend.
- Bước 5 yêu cầu xác nhận riêng về tính chính xác, điều khoản và thông báo dữ liệu cá nhân; nội dung điều khoản/cam kết hiển thị trước khi người dùng tích.
- Hỗ trợ ký trực tiếp hoặc tải ảnh chữ ký, xem trước, xóa/ký lại và yêu cầu chữ ký trước khi gửi.
- Bản xem trước hồ sơ hiển thị thông tin định danh thích hợp, ảnh chân dung và phần xác nhận; API lưu ảnh/chữ ký theo luồng hồ sơ hiện có.
- Nút bắt đầu hồ sơ mới xóa trạng thái biểu mẫu, chữ ký và dữ liệu xem trước của người trước.
- Nội dung liên quan tới wizard/điều khoản/chữ ký có các cặp dịch VI/EN được kiểm tra tĩnh.

**Lưu ý:** nội dung điều khoản và cam kết trong source vẫn là dự thảo cần đơn vị vận hành phê duyệt trước khi dùng production. Chữ ký vẽ/tải ảnh không tự động đồng nghĩa chữ ký số được chứng thực.

### 2.3 Tra cứu, đăng nhập, mật khẩu và quản trị người dùng

- Trang quên mật khẩu hướng người dùng liên hệ quản trị viên hoặc hotline `0924 910 210`.
- API legacy `forgot-password` và `reset-password` trả HTTP 410 và không phát hành/chấp nhận token reset. Bảng token cũ vẫn được giữ để tránh thay đổi schema phá hủy.
- Có cờ `must_change_password` và luồng buộc đổi mật khẩu sau khi quản trị viên cấp mật khẩu tạm thời; thay đổi mật khẩu thu hồi các phiên khác.
- Làm rõ thông báo quản trị: cấp mật khẩu tạm thời không tự động kích hoạt tài khoản.
- Bổ sung/hoàn thiện màn hình xem chi tiết hồ sơ, ảnh chân dung và chữ ký trong khu vực được phân quyền.
- Sửa gán dữ liệu dashboard để không gọi API overview dư và gây lệch đối tượng dữ liệu.
- Bổ sung kiểm thử luồng duyệt, kích hoạt tài khoản và trạng thái người dùng liên quan.

### 2.4 Bảo vệ tệp hồ sơ

- Tệp upload ẩn danh được gắn `account_request_staging` trong thời gian chờ hoàn tất hồ sơ.
- Endpoint đọc tệp từ chối đọc các object staging chưa được gắn với một hồ sơ đã gửi, kể cả người xét duyệt có đoán được ID.
- Sau khi gửi hồ sơ, metadata được liên kết với `account_request`; người có quyền xem hồ sơ mới có thể đọc ảnh/chứng từ theo chính sách `identity_private`.
- Có test xác nhận tệp staging bị chặn với reviewer nhưng ảnh chân dung của hồ sơ đã gửi truy cập được cho reviewer có quyền.
- Vẫn cần chính sách dọn dẹp/retention cho tệp staging mồ côi ở cấp vận hành; bản này không tuyên bố đã bổ sung job dọn dẹp tự động.

### 2.5 Chat riêng và nhóm

- Có API/giao diện cho chat 1–1, tạo nhóm và quản lý thành viên.
- Các truy vấn phòng, tin nhắn và tệp chat áp dụng kiểm tra thành viên ở backend.
- Upload đính kèm chat được gắn metadata phạm vi chat và kiểm tra membership khi đọc.
- **Chưa có** mã hóa đầu cuối E2EE hoặc realtime qua WebSocket/Cloudflare Durable Objects. Không được quảng bá hai đặc tính này như đã có.

### 2.6 SCRD ↔ Exam

- Giữ các luồng token khởi chạy, lượt thi, autosave theo revision, chấm điểm máy chủ và receipt đã có.
- Cập nhật cache-busting asset Exam và rà soát origin kết nối được chấp nhận trong source.
- Thêm kiểm thử hồi quy cho các luồng đã mô tả.
- Cấu hình D1 thật của cả SCRD/Exam vẫn yêu cầu xác nhận tên database trước triển khai.

## 2.7 Bổ sung ở bản Super Comprehensive

- Tái biên tập nội dung long-form VI/EN để loại bỏ các đoạn hướng dẫn chung lặp nguyên văn; kiểm thử xác nhận 380 đoạn không trùng nguyên văn.
- Trang chủ có các khối dữ liệu từ backend cho kỳ khảo thí, công bố/tài liệu và đối tác đã xác minh; không tạo dữ liệu giả khi danh sách trống.
- CMS Home Layout Manager cho phép sắp xếp và bật/tắt 9 khối; lưu cấu hình qua API/D1; backend kiểm tra đủ khối, không trùng và giữ Hero đầu tiên.
- Module nghiên cứu/dự án/nhiệm vụ có danh sách và thao tác sửa/xóa; chặn xóa chương trình còn nhiệm vụ liên kết; kiểm tra task parent, giới hạn trọng số và tính lại tiến độ sau cập nhật/xóa.
- Không tiếp tục lưu unsalted SHA-256 của số định danh ít entropy vào trường `id_number_hash` không dùng trong luồng hiện tại; số định danh vẫn được mã hóa. Hash cũ trong database thật không tự động bị xóa.
- Thêm release audit 19 kiểm tra và tích hợp vào `npm test`.

## 3. Migration

Thư mục `migrations/` hiện gồm:

1. `0001_initial_schema.sql`
2. `0002_cleanup_unverified_content.sql`
3. `0003_home_about_longform.sql`
4. `0004_public_hero_copy_update.sql`
5. `0005_temporary_password_guard.sql`
6. `0006_hero_description_split.sql`

Migration 0005 thêm `must_change_password`. Migration 0006 tách phụ đề và mô tả hero, chỉ chuẩn hóa các giá trị bundle mặc định đã biết và không ghi đè nội dung CMS tùy chỉnh. Chuỗi migration đã được chạy trên schema thử nghiệm theo đúng thứ tự.

**Không chạy mù toàn bộ migrations trên production.** Sao lưu D1, kiểm tra lịch sử migration và schema hiện tại, chỉ áp dụng migrations còn thiếu, thử staging trước và có phương án rollback.

## 4. Kết quả kiểm thử tự động mới nhất

| Nhóm | Kết quả |
|---|---:|
| Kiểm tra nội dung song ngữ + cấu trúc/không lặp | 6/6 |
| Hồi quy giao diện (static/source contracts) | 29/29 |
| SCRD Worker + SQLite/D1 giả lập + R2 giả lập | 18/18 |
| Tích hợp SCRD ↔ Exam | 5/5 |
| Exam validation | 31/31 |
| Release audit | 19/19 |
| **Tổng các kiểm tra nội dung/UI/nghiệp vụ** | **89/89** |
| **Tổng gồm release audit** | **108/108** |
| Chuỗi migration | 6/6 migrations theo thứ tự |
| Syntax check | Đạt |

Các mục trên là hỗn hợp kiểm tra tĩnh và test cục bộ, không phải 108 bài browser E2E. Bài kiểm tra nội dung dùng bộ đếm Unicode/space-token; tiếng Việt không nên xem số đếm này như một đánh giá ngữ nghĩa hoàn hảo. Kết quả chỉ có ý nghĩa với các tình huống được test.

## 5. Hạng mục chưa thể xác nhận hoặc còn giới hạn

- Chưa deploy lên Cloudflare Pages/Workers; website đang chạy không tự thay đổi chỉ vì có ZIP mới.
- Chưa xác minh D1/R2 thật, secrets, DNS, custom domain, email thật và quyền tài khoản Cloudflare.
- `wrangler.toml` còn `REPLACE_WITH_ACTUAL_D1_DATABASE_NAME`; `EXAM/wrangler.json` còn `CONFIRM_ACTUAL_D1_DATABASE_NAME`. Không tự đoán hai giá trị này.
- Chưa áp dụng migration vào D1 production.
- Chưa hoàn thành kiểm thử browser E2E trực tiếp. Môi trường kiểm thử trình duyệt bị chặn/không khởi chạy thành công.
- Nội dung pháp lý của điều khoản và thông báo dữ liệu cần được đơn vị vận hành phê duyệt.
- Chat chưa có E2EE/realtime; CMS vẫn dùng các module/tab hiện có; bản Super Comprehensive bổ sung trình quản lý bố cục Trang chủ với sắp xếp/bật tắt khối, nhưng chưa phải visual drag-and-drop tự do hoàn chỉnh.
- Không có quyền xác minh số liệu dashboard trong D1 production; các số liệu hiển thị cần được kiểm tra sau triển khai.

## 6. Khuyến nghị trước khi dùng production

1. Xác minh chính xác tên D1 cho SCRD và Exam trong Cloudflare.
2. Kiểm tra bucket R2 `scrd-files` và các binding trong đúng environment.
3. Sao lưu D1, so sánh schema/migration history, chạy thử staging và lập rollback plan.
4. Cấu hình secrets an toàn; không đưa secrets thật vào ZIP hoặc commit.
5. Kiểm thử trình duyệt cả desktop/mobile và toàn bộ các hành trình đăng ký, duyệt tài khoản, đăng nhập, CMS, chat và Exam.
6. Phê duyệt nội dung điều khoản/chính sách dữ liệu trước khi công bố.
7. Xác nhận dashboard truy vấn đúng dữ liệu và kiểm tra lại các quyền API trên môi trường thật.

## 7. Tuyên bố bàn giao

Đây là bản mã nguồn được chỉnh sửa và test cục bộ. **Không tuyên bố website production đã được sửa, triển khai hoặc nghiệm thu.** Gói phát hành phải được giải nén và chạy lại test trước khi bàn giao; dữ liệu và ZIP nguồn ban đầu được giữ nguyên.
