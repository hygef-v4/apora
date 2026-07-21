# 🏙️ APORA - Apartment Operations & Resident Assistant

[![Flutter](https://img.shields.io/badge/Flutter-v3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Next.js](https://img.shields.io/badge/Next.js-v14-000000?style=for-the-badge&logo=next.js&logoColor=white)](https://nextjs.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-v15-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Riverpod](https://img.shields.io/badge/State_Management-Riverpod-blueviolet?style=for-the-badge)](https://riverpod.dev)
[![PayOS](https://img.shields.io/badge/Payment-PayOS_VietQR-green?style=for-the-badge)](https://payos.vn)
[![Firebase](https://img.shields.io/badge/Notifications-Firebase_FCM-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)

> **APORA** is a comprehensive Smart Apartment Management System connecting 4 distinct user roles: **Building Owners (LANDLORD)**, **Building Management (MANAGER)**, **Residents (RESIDENT)**, and **Operational Staff (STAFF: Security, Maintenance, Housekeeping)**.

---

## 🌟 Key Features

- **Authentication & Role-Based Access Control**: Secure JWT authentication, SMS OTP verification, and strict role authorization between Residents, Management, and Staff.
- **Apartments & Lease Contracts**: Real-time apartment status tracking, digital check-in handover, and automated data anonymization upon checkout.
- **Tenancy & Roommates Management**: Online residence registration, document approval workflow, and ID card photo verification.
- **Billing & VietQR Payments**: Real-time utility consumption calculation, automated invoice generation, and instant online payment reconciliation via PayOS VietQR in under 1 second.
- **Issue Tickets & Work Orders**: End-to-end 3-way issue reporting workflow (Resident - Management - Maintenance Staff) with image attachments.
- **Push Notifications & Realtime Chat**: Instant push notifications via Firebase Cloud Messaging (FCM) and real-time live chat powered by Pusher.

---

## 🛠️ Technology Stack

| Layer | Technology / Library | Description |
| :--- | :--- | :--- |
| **Mobile App** | **Flutter v3.x** | Dart language, Cross-platform (Android & iOS) |
| **State Management** | **Flutter Riverpod** | Immutable & reactive state management |
| **Mobile Navigation** | **GoRouter** | Declarative routing with role-based route guards |
| **HTTP Client** | **Dio** | REST API client with automatic 401 token refresh interceptors |
| **Secure Storage** | **FlutterSecureStorage** | Encrypted JWT token storage on local devices |
| **Backend API** | **Next.js (App Router)** | TypeScript, RESTful API Endpoints |
| **Database** | **PostgreSQL** | Connection via `pg.Pool` with SQL Transactions support |
| **Unit Testing** | **Vitest & Flutter Test** | 100% automated test coverage (187 test cases) |
| **Third-party Services** | **PayOS SDK** | VietQR banking payment gateway |
| | **Firebase Admin & FCM** | SMS OTP verification & Push Notifications |
| | **Cloudinary** | Secure image storage and data masking |
| | **Pusher** | Real-time WebSocket Live Chat |

---

## 📁 Monorepo Structure

```text
apora/
├── mobile/                      # [FLUTTER MOBILE APPLICATION]
│   ├── lib/
│   │   ├── core/                # Theme, Network (Dio), Shared Widgets, Router
│   │   └── features/            # Feature-First Architecture
│   │       ├── auth_profile/    # Login, Password Reset, Profile
│   │       ├── billing/         # Invoices, PayOS Payments, Receipts
│   │       ├── roommate/        # Roommates, Residence Registration
│   │       ├── ticket/          # Issue Reporting & Maintenance
│   │       └── task/            # Staff Task Assignment
│   └── test/                    # 187 Unit & Widget Test Cases
│
├── backend/                     # [NEXT.JS REST API SERVER]
│   ├── src/
│   │   ├── app/api/             # Presentation Layer: REST API Routes
│   │   ├── services/            # Business Logic Layer: Core Domain Rules
│   │   ├── repositories/        # Data Access Layer: PostgreSQL Queries
│   │   ├── lib/                 # Auth JWT, DB Connection, Cloudinary
│   │   └── types/               # TypeScript Interfaces & Data Models
│   └── db/                      # Schema SQL & Seed data
│
└── docs/                        # System Architecture & Documentation
```

---

## ⚡ Development Setup Guide

### 1. Backend Setup (Next.js API Server)

```bash
# 1. Navigate to backend directory
cd backend

# 2. Install dependencies
npm install

# 3. Copy environment variables template
cp .env.example .env

# 4. Run automated backend unit tests
npm test

# 5. Start development server
npm run dev
# Server running at: http://localhost:3000
```

### 2. Mobile App Setup (Flutter)

```bash
# 1. Navigate to mobile directory
cd mobile

# 2. Fetch Flutter packages
flutter pub get

# 3. Run automated test suite (187 test cases)
flutter test

# 4. Launch app on Emulator or Physical Device
flutter run
```

---

## 🧪 Quality Assurance & Testing

The APORA system has been rigorously tested, achieving a **100% Pass Rate**:
- **Backend**: Automated unit testing suite powered by **Vitest** (`npm test`).
- **Mobile**: 187 test cases using the **Flutter Test Framework** (`flutter test`).

---

© 2026 **APORA Development Team**. All rights reserved.
