/**
 * TypeScript Type Definitions
 *
 * Định nghĩa interface cho các entities trong hệ thống.
 * Khớp với Data Dictionary trong SRS + Software Design (docs/).
 *
 * Module 1 (Auth & Profile) đã refactor theo thiết kế mới.
 * Các entity module sau (Contract, Invoice, ...) bổ sung dần khi triển khai.
 */

// ==========================================
// Enums (Giá trị cố định trong Database)
// ==========================================

/** 6 role theo SRS. Một user có thể giữ nhiều role (roles: text[]). */
export type UserRole =
  | 'LANDLORD'
  | 'MANAGER'
  | 'RESIDENT'
  | 'SECURITY_GUARD'
  | 'JANITOR'
  | 'TECHNICIAN';

/** 3 role nhân viên vận hành (Module 8). */
export type StaffRole = 'SECURITY_GUARD' | 'JANITOR' | 'TECHNICIAN';

export const STAFF_ROLES: StaffRole[] = ['SECURITY_GUARD', 'JANITOR', 'TECHNICIAN'];

export type UserStatus = 'ACTIVE' | 'INACTIVE';
export type ApartmentStatus = 'EMPTY' | 'OCCUPIED' | 'INACTIVE';
export type RoommateStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'INACTIVE';
export type InvoiceStatus = 'UNPAID' | 'PAID';
export type PaymentMethod = 'PAYOS' | 'CASH';

/** Bộ trạng thái đã chốt theo Software Design mục 3.4 (xem CLAUDE.md). */
export type TicketStatus =
  | 'PENDING'
  | 'ASSIGNED'
  | 'PROCESSING'
  | 'RESOLVED'
  | 'CANCELLED';

export type TaskStatus = 'ASSIGNED' | 'IN_PROGRESS' | 'COMPLETED';

// ==========================================
// Entity Interfaces (Khớp với bảng DB - Module 1)
// ==========================================

export interface User {
  id: number;
  phone_number: string;
  password_hash: string;
  full_name: string;
  avatar_url: string | null;
  roles: UserRole[];
  status: UserStatus;
  /** BR-01: bắt buộc đổi mật khẩu ở lần đăng nhập đầu (mật khẩu mặc định do BQL cấp). */
  must_change_password: boolean;
  /** BR-07: tăng khi reset/đổi mật khẩu để vô hiệu hóa mọi JWT cũ. */
  token_version: number;
  created_at: Date;
}

/** User trả về cho client - không bao giờ chứa password_hash / token_version. */
export interface PublicUser {
  id: number;
  phoneNumber: string;
  fullName: string;
  avatarUrl: string | null;
  roles: UserRole[];
}

/** BR-44: FCM token lưu bảng riêng, revoke khi logout. */
export interface DeviceToken {
  id: number;
  user_id: number;
  token: string;
  created_at: Date;
  revoked_at: Date | null;
}

/** BR-08: OTP hết hạn 5 phút; attempt_count tối đa 3 lần sai. */
export interface PasswordResetOtp {
  id: number;
  phone_number: string;
  otp_code: string;
  expired_at: Date;
  is_used: boolean;
  attempt_count: number;
  created_at: Date;
}

/** Bảng APARTMENTS (theo SRS "Apartment"). */
export interface Apartment {
  id: number;
  unit_number: string;
  floor: string;
  owner_id: number | null;
  status: ApartmentStatus;
}

/** Bảng REPAIR_TICKETS (theo SD Module 4 - RepairTicket entity). */
export interface RepairTicket {
  id: number;
  apartment_id: number;
  resident_id: number;
  category: string;
  description: string;
  before_images: string[];
  status: TicketStatus;
  internal_notes: string | null;
  created_at: Date;
  updated_at: Date;
}

/** Bảng TASKS (theo SD Module 4 - Task entity). */
export interface Task {
  id: number;
  ticket_id: number;
  assigned_to: number;
  assigned_by: number;
  title: string;
  description: string | null;
  progress_notes: string | null;
  completion_images: string[];
  status: TaskStatus;
  assigned_at: Date;
  completed_at: Date | null;
}

/** Bảng AUDIT_LOGS (UC39/UC40 BR-04 - mở rộng có chủ đích, xem CLAUDE.md). */
export interface AuditLog {
  id: number;
  actor_id: number;
  target_user_id: number | null;
  action: string;
  old_value: Record<string, unknown> | null;
  new_value: Record<string, unknown> | null;
  reason: string | null;
  created_at: Date;
}

/** Bảng INVOICES (theo SD Module 3 - Invoice entity). */
export interface Invoice {
  id: number;
  contract_id: number;
  apartment_id: number;
  month_year: string;
  prev_electricity_index: number;
  curr_electricity_index: number;
  electricity_consumption: number;
  prev_water_index: number;
  curr_water_index: number;
  water_consumption: number;
  room_rent_snapshot: number;
  mgmt_fee_snapshot: number;
  extra_fee: number;
  extra_fee_description: string | null;
  total_amount: number;
  status: 'UNPAID' | 'PAID';
  created_at: Date;
  unit_number?: string; // Dùng kèm khi query join apartment
}

/** Bảng PAYMENTS (theo SD Module 3 - Payment entity). */
export interface Payment {
  id: number;
  invoice_id: number;
  resident_id: number;
  payos_order_id: string;
  transaction_code: string | null;
  amount: number;
  payment_method: string;
  status: 'PENDING' | 'SUCCESS' | 'FAILED' | 'CANCELLED';
  paid_at: Date | null;
  created_at: Date;
  unit_number?: string;
  month_year?: string;
  resident_name?: string;
}

// ==========================================
// Module 8: Staff Management DTOs
// ==========================================

/** 1 dòng trong danh sách nhân viên (UC36) - kèm số task đang mở (BR-41). */
export interface StaffListItem extends PublicUser {
  status: UserStatus;
  openTaskCount: number;
  createdAt: Date;
}

/** Thống kê tổng quan nhân sự (UC36 - Staff Statistics Summary). */
export interface StaffStats {
  total: number;
  active: number;
  inactive: number;
  openTasks: number;
}

// ==========================================
// API Request/Response Types
// ==========================================

export interface ApiResponse<T = unknown> {
  status: 'success' | 'error';
  message: string;
  data?: T;
}

export interface LoginRequest {
  phone: string;
  password: string;
  /** Optional - mobile gửi khi đã setup Firebase Messaging (Module 5). */
  fcmToken?: string;
}

export interface LoginResponseData {
  token: string;
  mustChangePassword: boolean;
  user: PublicUser;
}

/**
 * JWT Payload
 * tv = token_version tại thời điểm ký; middleware so với DB (BR-07).
 */
export interface JwtPayload {
  id: number;
  roles: UserRole[];
  tv: number;
  iat?: number;
  exp?: number;
}
