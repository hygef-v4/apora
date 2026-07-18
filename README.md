# APORA - Apartment Management Super App

> ⚠️ **Nguồn chân lý khi triển khai code:** tài liệu thiết kế trong `docs/`
> (SRS + Software Design), `backend/src/types/index.ts` và `CLAUDE.md`.
> README/CONTRIBUTING chỉ mang tính giới thiệu tổng quan — khi có khác biệt,
> **ưu tiên tài liệu thiết kế**, không bám theo README/CONTRIBUTING.

Dự án ứng dụng quản lý chung cư/căn hộ hỗ trợ tương tác số hóa giữa **Chủ tòa nhà (LANDLORD)**, **Ban quản lý (MANAGER)**, **Cư dân (RESIDENT)** và **Nhân viên vận hành (STAFF: Bảo vệ / Lao công / Kỹ thuật)**.

## 🚀 Tính năng nổi bật

- **Minh bạch hóa tài chính**: Tự động hóa hóa đơn, thanh toán qua cổng PayOS.
- **Tối ưu hóa vận hành**: Quy trình quản lý sự cố (Ticket) 3 bên khép kín (Resident - Admin - Staff).
- **Nâng cao trải nghiệm số**: Live Chat, Push Notifications, Quản lý Khách ra vào, Quản lý Nhân khẩu.

## 🛠 Nền tảng Công nghệ

- **Mobile App**: Flutter (Riverpod/BLoC, Dio)
- **Backend API**: Next.js (REST API, Node.js)
- **Database**: PostgreSQL (Supabase Pooler, Raw Queries via `pg`)
- **Realtime**: Pusher (Live Chat)
- **Notifications**: Firebase Cloud Messaging (FCM)
- **Lưu trữ ảnh**: Cloudinary

## 📁 Cấu trúc Monorepo

```
apora/
├── mobile/       # Flutter App
├── backend/      # Next.js API Server
├── docs/         # Tài liệu dự án (PRM393)
├── .gitignore
├── CONTRIBUTING.md
└── README.md
```

## ⚙️ Cài đặt Môi trường (Development)

### 1. Backend (Next.js)

```bash
cd backend
npm install
# Copy .env.example thành .env và điền các API Keys cần thiết
cp .env.example .env
# Chạy Server
npm run dev
```

### 2. Mobile App (Flutter)

```bash
cd mobile
flutter pub get
# Chạy ứng dụng trên Emulator/Device
flutter run
```

## 👥 Nhóm Phát triển

Hệ thống được phát triển bởi nhóm 5 thành viên. Vui lòng tham khảo file `CONTRIBUTING.md` để xem phân công công việc chi tiết và các quy định khắt khe về kỹ thuật trước khi code.
