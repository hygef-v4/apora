# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Toàn bộ file này viết bằng tiếng Việt theo yêu cầu của dự án. Comment code, commit message và chuỗi hiển thị cho người dùng đều dùng tiếng Việt.

## Dự án

APORA — "Super App" quản lý chung cư/căn hộ, số hóa tương tác giữa **Chủ tòa nhà (LANDLORD)**, **Ban quản lý (MANAGER)**, **Cư dân (RESIDENT)** và **Nhân viên vận hành (STAFF: Bảo vệ / Lao công / Kỹ thuật)**. Một mã nguồn Flutter duy nhất, render workspace theo role dựa trên RBAC sau khi đăng nhập.

**Tài liệu là nguồn chân lý (docs/):**
- `docs/PRM393_SoftwareRequirementSpecification_Group5.docx` — SRS: 45 use case, 65 Business Rule (BR-01…BR-65).
- `docs/PRM393_SoftwareDesign_Group5.docx` — Software Design: kiến trúc 4 tầng, thiết kế DB (15 bảng), class diagram Controller/Service/Repository và Notifier/APIService cho 9 module.
- `docs/PRM393.txt` — bản mô tả use case gốc (tiếng Việt).

⚠️ **Trạng thái code:** Phần lớn 9 module đã triển khai full-stack theo thiết kế mới — Auth & Profile (M1), Tenancy/Roommate (M2), Billing & Payment (M3), Incident & Task (M4), Communication/Chat/Notifications (M5), Apartment (M6), Operational Staff (M8), Manager (M9). **Khi triển khai/hoàn thiện, bám theo tài liệu thiết kế + `types/index.ts`, không bám theo README/CONTRIBUTING (đã cũ).** Lấy Module 1/8 làm mẫu chuẩn (đã có unit test đầy đủ): Controller→Service→Repository ở backend; Notifier→APIService→Screen ở mobile.

## Cấu trúc Monorepo

- `backend/` — Next.js App Router, **chỉ API** (không có UI). Route dưới `src/app/api/**`, mỗi thư mục map tới một use case.
- `mobile/` — Flutter cho cả 4 role. Cấu trúc **feature-first**: `lib/features/<feature>/{models,providers,repositories,screens}`; code dùng chung ở `lib/core/{constants,network,router,services,theme,utils,widgets}`. `main.dart` đã hoàn chỉnh: load `.env`, init Firebase + push notification, khôi phục phiên đăng nhập, `MaterialApp.router` theo `app_router.dart`.
- `docs/` — tài liệu SRS & Design.

## Lệnh thường dùng

Backend (chạy trong `backend/`):
- `npm install`
- `npm run dev` — server dev (API tại `http://localhost:3000/api`)
- `npm run build` / `npm run start`
- `npm run lint` — `next lint`

Mobile (chạy trong `mobile/`):
- `flutter pub get`
- `flutter run`
- `flutter test` — chạy toàn bộ test
- `flutter test test/widget_test.dart` — chạy một file test
- `flutter analyze` — phân tích tĩnh (`analysis_options.yaml`, `flutter_lints`)

## Kiến trúc 4 tầng (theo Software Design)

1. **Presentation** — Flutter Super App (Riverpod state, Dio network). Login → chọn role → khởi tạo module tương ứng (Resident / Manager / Landlord / Staff).
2. **Application & Orchestration** — Next.js backend: xác thực JWT + phân quyền role, tính hóa đơn, kiểm soát chuyển trạng thái (ticket/task), xử lý webhook PayOS, job ẩn danh dữ liệu khi checkout.
3. **Data** — Supabase **PostgreSQL** qua **pgBouncer (port 6543)** cho serverless; truy vấn SQL thô bằng `pg`; giao dịch ACID cho check-in/checkout.
4. **Integration** — PayOS (VietQR + webhook HMAC-SHA256), Cloudinary (ảnh), Pusher (WebSocket cho Live Chat), Firebase Cloud Messaging (push), Firebase Auth (SMS OTP đổi/khôi phục mật khẩu).

### Backend: mô hình phân tầng bắt buộc
Mỗi module theo **Controller → Service → Repository → DatabaseConnection**:
- `*Controller` — expose HTTP endpoint, gọi Service.
- `*Service` — business logic, ghép nhiều Repository + service ngoài (Cloudinary, PayOS, Notification), thực thi giao dịch ACID.
- `*Repository` — truy vấn SQL thô qua helper `query()` / `getClient()` trong `backend/src/lib/db.ts`, map row → entity.
- Tích hợp bên thứ ba đặt trong `backend/src/lib/` (`cloudinary.ts`, `db.ts`, `auth.ts`, `middleware.ts`).
- Alias import: `@/*` → `backend/src/*`. `pg` và `bcrypt` được khai báo external trong `next.config.js` — giữ nguyên.

### Mobile: mô hình theo module
Mỗi feature theo **Notifier (Riverpod) → APIService (Dio) → Model (fromJson/toJson) → Screen**. UI chỉ hiển thị, logic nằm ở Notifier.

## 9 Module (map use case)

1. Auth & Profile (UC01–UC05) — login, logout, quên mật khẩu qua OTP, xem/sửa profile.
2. Tenancy & Roommate (UC06–UC12) — hợp đồng thuê, gia hạn lưu trú (stay extension), đăng ký/duyệt người ở ghép.
3. Billing & Payment (UC13–UC17) — nhập chỉ số điện/nước → sinh hóa đơn, lịch sử giao dịch, thanh toán VietQR, biên lai.
4. Incident & Task (UC18–UC23) — cư dân tạo ticket → Manager phân công tạo Task cho Staff → Staff cập nhật tiến độ/ảnh nghiệm thu.
5. Communication & Notifications (UC24–UC28) — bảng tin, danh sách/nhận thông báo (FCM), Live Chat (Pusher).
6. Apartment Management (UC29–UC34) — danh mục căn hộ, tạo/sửa, check-in/checkout.
7. Statistics & Dashboard (UC35) — thống kê doanh thu & ticket cho Landlord.
8. Operational Staff Management (UC36–UC40) — CRUD tài khoản Bảo vệ/Lao công/Kỹ thuật.
9. Manager Management (UC41–UC45) — CRUD tài khoản Manager (cấu trúc kế thừa Module 8, chỉ khác role).

## Thiết kế Database (15 bảng)

`USERS`, `APARTMENTS`, `CONTRACTS`, `INVOICES`, `ROOMMATES`, `REPAIR_TICKETS`, `TASKS`, `NEWS`, `CHAT_ROOMS`, `MESSAGES`, `DEVICE_TOKENS`, `PASSWORD_RESET_OTPS`, `STAY_EXTENSIONS`, `PAYMENTS`, `NOTIFICATIONS`.

Lưu ý quan hệ dễ nhầm:
- **`INVOICES` ↔ `PAYMENTS` tách biệt**: hóa đơn và log giao dịch là hai bảng khác nhau (PayOS order/transaction ghi ở `PAYMENTS`).
- **`REPAIR_TICKETS` ↔ `TASKS` tách biệt**: ticket của cư dân sinh ra Task giao cho Staff; chúng có vòng đời riêng.
- **FCM token nằm ở bảng `DEVICE_TOKENS`** (nhiều thiết bị / user), không phải một cột trên user.
- `CONTRACTS` lưu snapshot giá thuê; `STAY_EXTENSIONS` gia hạn hợp đồng; `ROOMMATES` là dữ liệu nhân khẩu (không tạo tài khoản đăng nhập).

## Vòng đời trạng thái then chốt

**Bộ enum trạng thái đã chốt theo Software Design mục 3.4 — dùng thống nhất toàn hệ thống:**

- **Ticket:** `PENDING → ASSIGNED → PROCESSING → RESOLVED`; huỷ → `CANCELLED` (phải purge ảnh — BR-38). Chỉ chuyển trạng thái ở backend, validate transition hợp lệ (BR-40). Đây là bộ chuẩn — **bỏ** các tên cũ/khác trong tài liệu (`WAITING_RATING`/`WAITING_FOR_RATING`, `CLOSED`, `REJECTED` ở BR-46 và `types/index.ts` cũ); khi tính "ticket chưa xử lý" (BR-46) → đếm `PENDING` + `PROCESSING`, loại `RESOLVED`/`CANCELLED`.
- **Task (Staff):** `ASSIGNED / IN_PROGRESS → COMPLETED` (bắt buộc ≥1 ảnh nghiệm thu — BR-43).
- **Bill/Invoice:** chỉ chuyển sang `PAID` qua **webhook PayOS server-to-server**, không bao giờ từ mobile (BR-32).

## Business Rules quan trọng (SRS — bắt buộc tuân thủ)

- **BR-01/BR-19:** Không có đăng ký tự do. Tài khoản do Ban quản lý cấp, mật khẩu mặc định, đổi ở lần đăng nhập đầu. Người ở ghép (roommate) chỉ là dữ liệu nhân khẩu, **không** tạo user.
- **BR-03/BR-06:** Hash mật khẩu bằng **bcrypt** trước khi lưu.
- **BR-07:** Reset mật khẩu phải **vô hiệu hoá mọi JWT** đang hoạt động của user (buộc login lại).
- **BR-04/BR-49/BR-59:** Tài khoản `INACTIVE` không được login; checkout/nghỉ việc → set `INACTIVE`, **không hard-delete** (giữ lịch sử hóa đơn/ticket/audit).
- **BR-10/BR-37:** Nén ảnh phía client < 500KB trước khi upload Cloudinary; ticket tối đa 3 ảnh, mỗi ảnh ≤ 5MB, JPG/PNG.
- **BR-20/BR-38:** Khi checkout hoặc huỷ ticket → **xoá ảnh nhạy cảm (CCCD, ảnh sự cố) khỏi Cloudinary** và mask số CCCD trong DB.
- **BR-23/BR-31/BR-53:** **Cô lập dữ liệu.** Query hóa đơn/ticket/thông báo/roommate theo `user_id` (từ JWT), **không** theo `apartment_id` — tránh rò rỉ dữ liệu chủ cũ khi đổi chủ.
- **BR-32:** Trạng thái hóa đơn chỉ cập nhật qua webhook PayOS.
- **BR-44:** Lưu FCM token khi login, **xoá khi logout** (tránh gửi noti cho người dùng sau trên cùng thiết bị).
- **BR-17/BR-28/BR-65:** Duyệt gia hạn, sinh hóa đơn hàng loạt, và check-in (tạo account + contract + cập nhật căn hộ) phải chạy trong **một transaction ACID**, lỗi thì rollback toàn bộ.
- **BR-27:** `INVOICES` có ràng buộc unique `(apartment_id, month_year)` — không tạo trùng hóa đơn tháng.
- **BR-33:** Test/demo thanh toán thật qua VietQR dùng mệnh giá nhỏ (< 50.000đ).
- **BR-45:** Live Chat cô lập theo phòng; chỉ cư dân của phòng và MANAGER được subscribe kênh Pusher đó.

## Quy ước & mobile lưu ý

- Mobile: lưu JWT bằng `flutter_secure_storage`, **không** `SharedPreferences`. Bọc mọi API call trong try/catch, hiển thị lỗi thân thiện tiếng Việt (SnackBar/Dialog), không để crash.
- Commit: Conventional Commits — `<type>(<scope>): <subject>` (`feat`, `fix`, `ui`, `refactor`, `style`, `docs`, `test`, `chore`).
- State management: Riverpod (BLoC được phép). Hằng số/màu/base URL ở `lib/core/constants/`.
- PR phải test PASS mới merge.

## Hiện trạng triển khai (phần lớn module đã full-stack)

`backend/src/types/index.ts` đã refactor theo thiết kế mới: 6 role (`LANDLORD/MANAGER/RESIDENT/SECURITY_GUARD/JANITOR/TECHNICIAN`, `roles` là mảng), `TicketStatus` theo bộ đã chốt, entity Module 1/8 + `Apartment`/`RepairTicket`/`Task` đầy đủ. Entity module sau (`Contract`, `Invoice`, `StayExtension`...) bổ sung dần khi triển khai.

Điểm cần biết khi làm module tiếp theo:
- **DB schema:** `backend/db/schema.sql` (+ `seed.sql`, mật khẩu seed: `Apora@123`) — chạy tay trên Supabase SQL Editor. Bảng mới thêm vào file này. Đã có: `users`, `device_tokens`, `password_reset_otps` (⚠️ giữ theo thiết kế 15 bảng nhưng **không còn code nào truy cập** — xem OTP bên dưới), `apartments`, `repair_tickets`, `tasks`, `audit_logs`, cùng các bảng module sau.
- **Các mở rộng có chủ đích so với SRS**: cột `users.must_change_password` (BR-01), `users.token_version` (BR-07 — JWT stateless nên bump version để vô hiệu token; JWT payload là `{id, roles, tv}`), và bảng `audit_logs` (UC39/UC40 BR-04 yêu cầu "dedicated audit log table" — ghi actor/target/action/old/new/reason cho thao tác quản lý nhân sự).
- **Module 8 (`/api/staff/**`, `mobile/lib/features/management/`):** mẫu cho Module 9 (Manager Management — SD nói cấu trúc giống hệt, chỉ đổi role). BR-50 enforce ở `staff.service.ts` (đếm `tasks` ASSIGNED/IN_PROGRESS → 409). Deactivate = soft-delete: `INACTIVE` + bump `token_version` + revoke `device_tokens`.
- **Backend:** `requireAuth(req, allowedRoles?)` trong `src/lib/middleware.ts` (ném `HttpError`, route bắt bằng `jsonError`); repository ở `src/repositories/`, service ở `src/services/`.
- **Mobile:** JWT lưu qua interface `TokenStorage` (`lib/core/network/token_storage.dart`) — test override bằng bản in-memory; lỗi Dio map qua `mapDioError()`; router redirect tập trung ở `lib/core/router/app_router.dart` (ép đổi mật khẩu lần đầu, rẽ nhánh theo role).
- **OTP quên mật khẩu (UC03):** đã chuyển sang **Firebase Phone Auth** — mobile nhận SMS trực tiếp từ Firebase (`lib/core/services/phone_otp_service.dart`), backend **không sinh/lưu OTP**. Flow: `POST /forgot-password` chỉ `ensureAccountForPasswordReset()` (check tài khoản tồn tại + ACTIVE, tránh tốn SMS); `POST /reset-password` nhận `firebaseIdToken`, backend `verifyPhoneIdToken()` (firebase-admin) + đối chiếu SĐT trong token (E.164, chuẩn hóa qua `normalizeVnPhone`) với tài khoản rồi mới đổi mật khẩu (bump `token_version` — BR-07). Firebase tự lo gửi SMS/hết hạn/đếm nhập sai (BR-08). Bảng `password_reset_otps` và hàm SMS mock cũ đã bỏ.

Khi đụng vào các phần này, ưu tiên cập nhật theo tài liệu thiết kế thay vì giữ nguyên type cũ.
