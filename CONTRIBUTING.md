# Hướng dẫn Đóng góp (Contributing Guidelines)

> ⚠️ **File này đã cũ và chỉ giữ để tham khảo lịch sử.** Nguồn chân lý khi
> triển khai là `docs/` (SRS + Software Design), `backend/src/types/index.ts`
> và `CLAUDE.md`. Phần "Phân công Công việc / WBS" bên dưới **không còn phản ánh
> đúng phạm vi 9 module hiện tại** (đã map lại theo UC01–UC45). Khi có khác biệt,
> ưu tiên tài liệu thiết kế.

Cảm ơn bạn đã quan tâm đóng góp cho dự án **APORA - Apartment Management**. Vui lòng tuân theo các quy tắc dưới đây để đảm bảo code quality và consistency.

## 🏗 Kiến trúc Dự án (Monorepo)

Dự án được chia thành 2 thư mục chính:
- `mobile/`: Ứng dụng Flutter cho 3 Role (Resident, Admin, Staff).
- `backend/`: API Server sử dụng Next.js (REST API, JWT Auth, Webhooks).

## 🧑‍💻 Phân công Công việc (WBS)

- **Thành viên 1 (Core & Auth)**: Setup Flutter base, Router, xử lý JWT Auth (UC01-UC04).
- **Thành viên 2 (Billing & Payment)**: Xử lý API PayOS, Webhook và giao diện hóa đơn (UC05-UC08).
- **Thành viên 3 (Ticket System)**: Xử lý quy trình báo cáo sự cố 3 bên, nén/upload hình ảnh (UC09-UC12).
- **Thành viên 4 (Realtime & Utils)**: Xử lý Chat qua Pusher, Push Notification (FCM), bảng tin chung (UC13-UC17).
- **Thành viên 5 (Admin & Data)**: Màn hình quản lý Admin, Dashboard thống kê, luồng Check-in/Checkout (UC18-UC20).

## ⚠️ CÁC LƯU Ý KỸ THUẬT QUAN TRỌNG (MUST READ)

1. **KHÔNG có nút Đăng ký (Register)**: Tài khoản phải được cấp phát bởi Admin (UC18 & UC20).
2. **Lưu trữ JWT Token an toàn**: Phải sử dụng `flutter_secure_storage`, TUYỆT ĐỐI KHÔNG dùng `SharedPreferences`.
3. **Nén hình ảnh**: Phải nén ảnh (ví dụ: dùng `flutter_image_compress`) xuống dưới 500KB trước khi upload lên Cloudinary.
4. **Cập nhật Hóa đơn PayOS**: Trạng thái hóa đơn chỉ được cập nhật thông qua **Webhook** từ PayOS gọi về Backend, KHÔNG ĐƯỢC cập nhật trực tiếp từ Mobile App (đề phòng rớt mạng).
5. **Quản lý FCM Token**: Lưu FCM Token vào Database khi Login, **XÓA FCM Token** khi Logout (nếu không chủ mới vào sẽ nhận noti của chủ cũ).
6. **Data Isolation (Cô lập dữ liệu)**: Các API GET hóa đơn/ticket cho Resident phải query theo `user_id`, KHÔNG query theo `apartment_id` (để tránh rò rỉ dữ liệu khi đổi chủ).
7. **Xử lý Ngoại lệ (Error Handling)**: Bọc tất cả API call trong `try...catch` và hiển thị thông báo lỗi thân thiện (tiếng Việt) bằng SnackBar/Dialog. Không để app crash.

## 📋 Quy tắc Commit Message (Conventional Commits)

```
<type>(<scope>): <subject>
<blank line>
<body>
```

**Các Type Commit chuẩn:**
- `feat`: Thêm tính năng mới
- `fix`: Sửa bug
- `ui`: Chỉnh giao diện
- `refactor`: Tối ưu code không đổi chức năng
- `style`: Format code
- `docs`: Tài liệu
- `test`: Thêm/sửa test
- `chore`: Config/package/build

Ví dụ: `feat(billing): add PayOS integration for invoice payment`

## 🌿 Quy trình Git (Git Workflow)

1. Checkout nhánh mới: `git checkout -b feature/uc05-billing`
2. Commit thường xuyên theo chuẩn.
3. Chạy test trước khi PR: `flutter test`
4. Tạo Pull Request (PR) và đợi code review. Bắt buộc test PASS mới được merge.

## 🎨 Lập trình Flutter

- Thư mục tổ chức theo Feature-First (`lib/features/...`).
- Sử dụng Riverpod hoặc BLoC để quản lý trạng thái. UI chỉ làm nhiệm vụ hiển thị.
- Các hằng số, màu sắc, base URL lưu tại `lib/core/constants/`.

## ⚙️ Lập trình Next.js Backend

- Sử dụng `pg` (Raw query) để tương tác PostgreSQL.
- API route chuẩn REST: `src/app/api/...`
- Middleware xác thực RBAC tại `src/lib/middleware.ts`.
- Mật khẩu phải hash bằng `bcrypt` trước khi lưu.

## ✅ Kiểm thử (Testing)

- **Flutter**: Bắt buộc viết ít nhất 1 Unit Test (Logic) và 1 Widget Test (Giao diện) để đạt yêu cầu qua môn.
- Lệnh chạy test: `flutter test`

---
*Dự án APORA - PRM393*
