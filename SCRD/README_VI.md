# Sky First SCRD + Exam — Source Handover

**Tên chính thức:** Trung tâm Nghiên cứu và Phát triển Cộng đồng Sky First  
**English:** Sky First Center for Research and Development  
**SCRD:** `https://scrd.skyfirst.io.vn`  
**Exam:** `https://exam.skyfirst.io.vn`  
**Hỗ trợ:** `support@skyfirst.io.vn`  
**Hotline hướng dẫn quên mật khẩu:** `0924 910 210`

Gói này chứa mã nguồn SCRD, Cloudflare Worker backend, D1 schema/migrations, cấu hình triển khai, test local và source Exam. Đây là bản mã nguồn đã sửa; **không đồng nghĩa website production đã được triển khai**.

## 1. Tài liệu cần đọc

- `SUPER_COMPREHENSIVE_AUDIT_VI.md` — báo cáo tổng hợp mới nhất, thay đổi sâu, kiểm thử và giới hạn.
- `RELEASE_BUILD_INFO.md`, `RELEASE_MANIFEST.json`, `RELEASE_FILE_HASHES_SHA256.txt` — thông tin build và kiểm tra toàn vẹn file.
- `REQUIREMENT_TRACEABILITY_12_PARTS_VI.md` — truy vết từng yêu cầu trong 12 phần tới mã nguồn/test/giới hạn.
- `FULL_REPAIR_REPORT_VI.md` — báo cáo sửa chữa chi tiết.
- `CHANGELOG_SUPER_COMPREHENSIVE_VI.md` — lịch sử thay đổi của bản Super Comprehensive Repair.
- `SCRD_EXAM_RELEASE_CHECKLIST_12_PARTS_VI.md` — checklist 12 phần, phân biệt test local và nghiệm thu production.
- `SECURITY_AUDIT_VI.md` — các kiểm soát, giới hạn và việc cần xác minh bảo mật.
- `UI_REFINEMENT_REPORT_VI.md` — thay đổi giao diện/UX có trong source.
- `TEST_REPORT_2026-10-22_VI.md` — kết quả test mới nhất và phạm vi test.
- `TEST_LOG_FULL_REPAIR_20261022.txt` và `TEST_LOG_SUPER_COMPREHENSIVE_20261022.txt` — log chi tiết từ các lần chạy `npm test`.
- `CONTENT_WORDCOUNT_VI.md` — cách đếm nội dung dài VI/EN và giới hạn bộ đếm.

## 2. Cấu trúc chính

- `public/` — HTML, JavaScript, CSS và assets SCRD.
- `backend_worker.js` — Worker API SCRD.
- `d1_schema_migration.sql` — schema hợp nhất dùng cho kiểm thử local.
- `migrations/` — migration D1 theo thứ tự 0001–0006.
- `tests/` — migration-chain, content validation, UI regression, SCRD smoke, integration và release audit.
- `EXAM/` — Worker, giao diện, API client, storage logic, configuration và validation của Exam.
- `tools/build_longform_content.py` — script tạo nội dung dài/migration theo source có sẵn.

## 3. Yêu cầu kiểm thử cục bộ

- Node.js phiên bản hỗ trợ `node:sqlite` (Node.js 22+ được khuyến nghị).
- Python 3 cho SQLite bridge trong smoke tests.
- Wrangler 4.34.0 được dùng trong các lệnh tiện ích/deploy; test local không cần quyền Cloudflare.

Chạy bộ test:

```bash
npm test
```

Kết quả bản source hiện tại:

| Nhóm | Kết quả |
|---|---:|
| Syntax check | Đạt |
| Chuỗi migration | 6/6 |
| Nội dung VI/EN: ngưỡng + cấu trúc/không lặp | 6/6 |
| Hồi quy UI | 29/29 |
| SCRD backend + SQLite/D1 giả lập + R2 giả lập | 18/18 |
| SCRD ↔ Exam integration | 5/5 |
| Exam validation | 31/31 |
| Release audit | 19/19 |
| **Tổng nội dung/UI/nghiệp vụ** | **89/89** |
| **Tổng cộng gồm release audit** | **108/108** |

Các kiểm tra UI chủ yếu là kiểm tra hợp đồng source/static. Smoke/integration test dùng SQLite và R2 giả lập. 108 là tổng các kiểm tra tự động được đếm theo nhóm, không phải 108 bài E2E trên trình duyệt hoặc bằng chứng production.

Chạy riêng:

```bash
npm run test:migrations
npm run test:content
npm run test:ui
npm run test:scrd
npm run test:integration
npm run test:exam
npm run test:release
```

## 4. Migrations

Thứ tự migration:

1. `0001_initial_schema.sql`
2. `0002_cleanup_unverified_content.sql`
3. `0003_home_about_longform.sql`
4. `0004_public_hero_copy_update.sql`
5. `0005_temporary_password_guard.sql`
6. `0006_hero_description_split.sql`

Migration 0005 bổ sung cờ `must_change_password` cho luồng mật khẩu tạm thời. Migration 0006 tách subtitle và description hero; chỉ điều chỉnh giá trị mặc định đã biết, không cố ý ghi đè nội dung CMS tùy chỉnh. Migration-chain test đã được chạy trên schema thử nghiệm theo đúng thứ tự.

**Không chạy lại toàn bộ migration một cách mù quáng trên production.** Trước khi thực hiện, sao lưu D1, kiểm tra migration history/schema và chỉ áp dụng migration còn thiếu. Thử trên staging trước và chuẩn bị rollback.

## 5. Cấu hình Cloudflare cần xác nhận

- Trong `wrangler.toml`, thay `REPLACE_WITH_ACTUAL_D1_DATABASE_NAME` bằng tên chính xác lấy từ Cloudflare Dashboard.
- Trong `EXAM/wrangler.json`, thay `CONFIRM_ACTUAL_D1_DATABASE_NAME` bằng tên chính xác cho database/binding được dùng.
- Xác minh D1 ID `6006fe24-6278-4989-8d94-fd4734d71679` có đúng là database của dự án/môi trường đang triển khai.
- Xác minh binding `DB` và bucket R2 `scrd-files` qua binding `FILES` trong đúng account/environment.
- Xác minh các secrets như `BOOTSTRAP_SECRET_TOKEN`, `ID_ENCRYPTION_KEY` và cấu hình Exam/email. Không dùng giá trị test, không điền secrets thật vào ZIP hoặc Git.
- Xác minh `CONTROL_ORIGIN`, CORS, security headers, DNS và custom domain.

Các placeholder không được đoán hoặc thay bằng tên tùy ý.

## 6. Triển khai — chỉ thực hiện bởi người có quyền

Bản này **chưa được deploy lên production**. Trước khi triển khai:

1. Xác nhận repository/project và môi trường đích.
2. Sao lưu D1 và lưu lại migration history/schema hiện tại.
3. Kiểm tra cấu hình database name/bindings, R2, secrets, origin và domain.
4. Chạy migration còn thiếu trên staging, không chạy lại migration đã áp dụng.
5. Kiểm thử đầy đủ đăng ký, xét duyệt, mật khẩu tạm thời, media riêng tư, CMS, chat và Exam.
6. Kiểm tra desktop/mobile bằng trình duyệt, xác nhận asset release version và có kế hoạch rollback.
7. Chỉ chuyển production sau khi staging và quyền truy cập đã được xác minh.

Lệnh deploy hiện có trong package scripts:

```bash
npm run deploy:scrd
npm run deploy:exam
```

Không chạy các lệnh trên trước khi hoàn thành toàn bộ bước xác nhận. Các lệnh không tự tạo D1/R2, secrets, DNS hoặc phân quyền Cloudflare.

## 7. Các giới hạn đã biết

- Chưa deploy hoặc thay đổi website production; việc tạo ZIP không làm site live tự thay đổi.
- Chưa xác minh dữ liệu D1/R2 thật, secrets, email thật, DNS, domain và quyền Cloudflare.
- Chưa hoàn tất browser E2E trực tiếp; môi trường trình duyệt kiểm thử bị chặn/không khởi chạy thành công.
- Điều khoản/cam kết và thông báo dữ liệu trên wizard cần được đơn vị vận hành phê duyệt chính thức.
- Chat kiểm soát thành viên và tệp theo quyền nhưng chưa có E2EE hoặc realtime qua WebSocket/Durable Objects.
- CMS dùng các module/tab hiện có và có trình quản lý bố cục Trang chủ cho sắp xếp/bật tắt khối; không tuyên bố có visual drag-and-drop tự do hoàn chỉnh.
- Chưa bổ sung job tự động dọn tệp staging mồ côi; cần quyết định retention/cleanup policy trước production.
- Các báo cáo số liệu dashboard phải được đối chiếu với D1 production sau khi có quyền truy cập.

## 8. Quyền riêng tư và dữ liệu

Không đưa secrets, mật khẩu, token thật hoặc dữ liệu cá nhân thật vào mã nguồn/ZIP. Tệp đăng ký staging chưa gửi bị chặn đọc ngay cả với reviewer; sau khi hồ sơ được gửi, quyền đọc ảnh/chứng từ được giới hạn cho vai trò được phép. Các quyền này vẫn cần được kiểm tra trên môi trường thực trước production.
