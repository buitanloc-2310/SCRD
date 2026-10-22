# Sky First SCRD + EXAM — Source handover

**Tên chính thức:** Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First  
**English:** Sky First Center for Research and Development  
**SCRD:** https://scrd.skyfirst.io.vn  
**Exam:** https://exam.skyfirst.io.vn  
**Hỗ trợ:** support@skyfirst.io.vn

Gói này chứa frontend SCRD, Cloudflare Worker backend, schema/migrations D1, cấu hình triển khai, tests và source Exam. Các bài test cục bộ sử dụng SQLite tạm thời và R2 giả lập; chúng không truy cập hoặc thay đổi production Cloudflare.

## Cấu trúc

- `public/` — giao diện SCRD và assets.
- `backend_worker.js` — API Worker SCRD.
- `d1_schema_migration.sql` — schema hợp nhất D1 dùng cho test/local.
- `migrations/` — migration theo phiên bản: `0001_initial_schema.sql`, `0002_cleanup_unverified_content.sql`, `0003_home_about_longform.sql`.
- `EXAM/` — Worker, giao diện và tests của Exam.
- `tests/content-validation.mjs` — kiểm tra nội dung dài song ngữ của Trang chủ và Giới thiệu.
- `tests/ui-regression.mjs` — kiểm tra các hợp đồng giao diện quan trọng: menu mobile, route, responsive CSS, link an toàn, trạng thái lỗi và giao diện Exam.
- `UI_REFINEMENT_REPORT_VI.md` — ghi chú các thay đổi giao diện tổng thể và giới hạn kiểm chứng.
- `tools/build_longform_content.py` — nguồn tạo nội dung/migration dài song ngữ có thể tái lập.
- `CONTENT_WORDCOUNT_VI.md` — báo cáo đếm nội dung theo bộ đếm Unicode.
- `TEST_REPORT_2026-10-22_VI.md` — kết quả kiểm thử và các giới hạn cần xác minh trước production.
- `tests/smoke.mjs` — kiểm thử backend SCRD với SQLite/R2 giả lập.
- `tests/integration.mjs` — kiểm thử SCRD ↔ Exam với cùng D1 giả lập.
- `tests/d1_r2_runtime_server.mjs` — runtime adapter cho kiểm thử local.
- `SECURITY_AUDIT_VI.md` — giới hạn, kiểm soát bảo mật và các bước cần xác minh trước production.

## Yêu cầu môi trường local

- Node.js 22+ khuyến nghị (có hỗ trợ `node:sqlite` cho test Exam).
- Python 3 để chạy SQLite bridge trong smoke tests.
- Wrangler 4.34.0 được gọi qua `npx` trong các lệnh tiện ích.

## Kiểm thử

```bash
npm run test
```

Lệnh chạy kiểm tra cú pháp, 4 kiểm tra ngưỡng nội dung, 9 kiểm tra hồi quy giao diện, 14 kiểm thử SCRD, 5 kiểm thử tích hợp SCRD ↔ Exam và 31 kiểm thử Exam. Trong lần kiểm tra ngày 22/10/2026, tổng cộng 63 kiểm thử nội dung/giao diện/nghiệp vụ đạt. Đây là kiểm thử cục bộ, không thay thế kiểm thử trên Cloudflare production hay kiểm thử trình duyệt end-to-end đầy đủ.

Có thể chạy riêng:

```bash
npm run test:ui
npm run test:scrd
npm run test:integration
npm run test:exam
```

## Chuẩn bị Cloudflare

1. Mở Cloudflare Dashboard → Workers & Pages → D1 và xác minh database có ID `6006fe24-6278-4989-8d94-fd4734d71679`.
2. Thay `REPLACE_WITH_ACTUAL_D1_DATABASE_NAME` trong `wrangler.toml` bằng **tên chính xác** từ Dashboard. Không đoán tên database.
3. Xác nhận binding `DB` và bucket R2 `scrd-files` (binding `FILES`) tồn tại trong đúng account/environment.
4. Sao lưu production D1 trước khi chạy migration. Đối chiếu các migration hiện có; không chạy lại schema tùy tiện trên production.
5. Xác nhận thư mục migration theo thứ tự. Với D1 đã tồn tại, xem lịch sử migration và chỉ áp dụng migration chưa chạy. Không chạy lại `0001_initial_schema.sql` một cách mù quáng trên production. `0003_home_about_longform.sql` bổ sung nội dung dài song ngữ cho trang chủ và Giới thiệu. Thử trên staging và đối chiếu schema trước khi áp dụng lên production.
6. Cấu hình secrets cho Worker SCRD:

```bash
npx wrangler@4.34.0 secret put BOOTSTRAP_SECRET_TOKEN --config wrangler.toml
npx wrangler@4.34.0 secret put ID_ENCRYPTION_KEY --config wrangler.toml
```

`BOOTSTRAP_SECRET_TOKEN` phải là giá trị ngẫu nhiên mạnh dùng một lần cho bootstrap đầu tiên. `ID_ENCRYPTION_KEY` phải là khóa bí mật mạnh và được bảo quản an toàn; mất khóa có thể khiến dữ liệu định danh đã mã hóa không giải mã được. Không dùng giá trị test trong production.

7. Kiểm tra cấu hình D1 của Exam trong `EXAM/wrangler.json`: `database_id` được khai báo theo yêu cầu nhưng `database_name` cũng cần khớp tên thực tế. Cấu hình `CONTROL_ORIGIN` phải là domain SCRD đúng.
8. Cấu hình secrets cần thiết cho Exam/email nếu có, kiểm tra DNS/custom domain và CORS trước khi triển khai.
9. Triển khai staging trước; chạy `/api/health` của SCRD và `/health` của Exam, rồi kiểm tra đăng ký, tra cứu, CMS, upload riêng tư và một lượt thi thử bằng tài khoản thử nghiệm.
10. Chỉ chuyển production sau khi xác nhận backup/rollback, domain, secrets, migration và phân quyền trên Cloudflare thật.

## Triển khai

Sau khi đã sửa tên database và cấu hình secrets/bindings thật:

```bash
npm run deploy:scrd
npm run deploy:exam
```

Không chạy deploy trước khi hoàn tất các bước xác minh. Các lệnh deploy không tự tạo database, bucket, secrets, DNS hay quyền Cloudflare.

## Lưu ý dữ liệu và quyền riêng tư

- Không commit secrets hoặc dữ liệu người dùng thật.
- Không dùng dữ liệu giả để đại diện cho đối tác, bài viết, dự án hoặc thành tích đã được xác nhận.
- Tệp giấy tờ riêng tư phải được phục vụ qua backend có kiểm tra quyền; không công khai URL R2.
- Mọi thông báo tiếp nhận hồ sơ chỉ xác nhận đã nhận, không đồng nghĩa hồ sơ đã được duyệt.


## Lưu ý quan trọng khi cập nhật website đang chạy

- Thư mục triển khai đúng là thư mục chứa trực tiếp `wrangler.toml`, `backend_worker.js`, `public/`, `migrations/` và `package.json` (`SCRD_UI_Release_20261022/` trong ZIP). Không deploy thư mục cha chứa thư mục này.
- Trang HTML đã gắn cache-busting cho CSS/JS. Sau khi deploy, mở DevTools/Network hoặc tải cứng (Ctrl+F5) để xác nhận `app.js?v=20261022-ui-fix1` và `styles.css?v=20261022-ui-fix1` được tải.
- Nếu website live vẫn hiện thẻ trạng thái D1/R2, liên kết Bootstrap trên header công khai, form đăng ký cũ chỉ có vài trường, hoặc số liệu dashboard không khớp dữ liệu thật, thì deployment đang phục vụ build/asset cũ hoặc cấu hình khác; ZIP này không thể tự thay đổi website live nếu chưa được deploy.
