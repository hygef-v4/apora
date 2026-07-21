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
export type ContractStatus = 'ACTIVE' | 'EXPIRED';
export type StayExtensionStatus = 'PENDING' | 'APPROVED' | 'REJECTED';
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

/** Khớp CHECK của bảng tasks (CANCELLED dùng khi ticket bị hủy sau phân công). */
export type TaskStatus = 'ASSIGNED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';

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

// LƯU Ý: entity PasswordResetOtp đã bị gỡ (OTP quên mật khẩu chuyển sang
// Firebase Phone Auth - backend chỉ verify Firebase ID token, không đọc/ghi
// bảng password_reset_otps). Bảng vẫn còn trong schema.sql theo thiết kế DB
// 15 bảng, nhưng không có code nào truy cập nên không cần entity.

/** Bảng APARTMENTS (theo SRS "Apartment"). */
export interface Apartment {
  id: number;
  unit_number: string;
  floor: string;
  owner_id: number | null;
  status: ApartmentStatus;
  area_size: number;
  base_rent: number;
}

/** Bảng CONTRACTS (theo SD Module 2 - Contract entity). */
export interface Contract {
  id: number;
  apartment_id: number;
  resident_id: number;
  start_date: Date;
  end_date: Date;
  base_rent_snapshot: number;
  status: ContractStatus;
  created_at: Date;
}

/** Bảng STAY_EXTENSIONS (theo SD Module 2 - StayExtension entity). */
export interface StayExtension {
  id: number;
  contract_id: number;
  resident_id: number;
  current_end_date: Date;
  requested_end_date: Date;
  reason: string | null;
  status: StayExtensionStatus;
  reviewed_by: number | null;
  reviewed_at: Date | null;
  reject_reason: string | null;
  created_at: Date;
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
  electricity_rate_snapshot: number;
  water_rate_snapshot: number;
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
// Module 9: Manager Management DTOs (UC41-UC45)
// ==========================================

/** 1 dòng trong danh sách Manager (UC41) — profile card trên màn Manager Management. */
export interface ManagerListItem extends PublicUser {
  status: UserStatus;
  createdAt: Date;
}

/** Thống kê tổng quan Manager (UC41 - Manager Statistics Summary). */
export interface ManagerStats {
  total: number;
  active: number;
  inactive: number;
}

/**
 * 1 mục lịch sử quản lý (UC42 - Management History section).
 * Nguồn: bảng audit_logs WHERE actor_id = managerId.
 */
export interface ManagementHistoryItem {
  id: number;
  action: string;
  targetUserName: string | null;
  reason: string | null;
  createdAt: Date;
}

// ==========================================
// Module 4: Incident & Task DTOs (UC18-UC23)
// ==========================================

/**
 * 1 dòng trong danh sách sự cố (UC18 - Resident xem của mình / Manager xem tất cả).
 * camelCase, KHÔNG lộ internal_notes cho Resident.
 */
export interface TicketListItem {
  id: number;
  category: string;
  description: string;
  beforeImages: string[];
  status: TicketStatus;
  unitNumber: string;
  /** FID-18 field 8: tên cư dân báo sự cố. */
  residentName: string;
  /** FID-18 field 9: nhân viên đang được giao; null khi chưa phân công. */
  assigneeName: string | null;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Chi tiết một sự cố (UC20 - Manager). Kèm thông tin người báo + task đã phân công
 * (nếu có) + ghi chú nội bộ (chỉ Manager/staff thấy).
 */
export interface TicketDetail extends TicketListItem {
  residentId: number;
  residentName: string;
  residentPhone: string;
  internalNotes: string | null;
  /** Task được sinh khi Manager phân công (UC21). Null khi ticket còn PENDING. */
  assignedTask: TaskSummary | null;
}

/** Tóm tắt task gắn với ticket (nhúng trong TicketDetail). */
export interface TaskSummary {
  id: number;
  assignedTo: number;
  assigneeName: string;
  assigneePhone: string | null;
  title: string;
  status: TaskStatus;
  assignedAt: Date;
  completedAt: Date | null;
}

/**
 * 1 dòng trong danh sách công việc của nhân viên (UC22).
 * category lấy từ ticket cha để staff biết loại sự cố;
 * assignedByName là tên Manager/Landlord đã giao (FID-22 field 7).
 */
export interface TaskListItem {
  id: number;
  ticketId: number;
  title: string;
  description: string | null;
  status: TaskStatus;
  category: string;
  unitNumber: string;
  assignedByName: string;
  assignedAt: Date;
  completedAt: Date | null;
}

/** Chi tiết công việc (UC23) - kèm ngữ cảnh sự cố gốc + ảnh hoàn thành. */
export interface TaskDetail extends TaskListItem {
  ticketDescription: string;
  ticketBeforeImages: string[];
  /** Người báo sự cố (FID-23 field 7 - Reported By trong thẻ tham chiếu). */
  residentName: string;
  progressNotes: string | null;
  completionImages: string[];
}

/**
 * 1 nhân viên trong bảng phân công (UC21 - Manager chọn người xử lý).
 * BR: gồm CẢ 3 role vận hành SECURITY_GUARD / JANITOR / TECHNICIAN.
 */
export interface StaffWorkloadItem {
  id: number;
  fullName: string;
  roles: StaffRole[];
  openTaskCount: number;
}

// ==========================================
// Module 2: Tenancy & Stay Extension DTOs (UC06-UC09)
// ==========================================

/**
 * UC06 - Xem hợp đồng của chính mình (FID-09).
 * contract = null khi căn hộ chưa có hợp đồng (AT2); remainingDays chỉ
 * tính khi ACTIVE (BR-12/BR-13 - tính động, không lưu DB).
 */
export interface MyContractResponse {
  apartment: {
    id: number;
    unitNumber: string;
    floor: string;
    status: ApartmentStatus;
  } | null;
  contract: {
    id: number;
    startDate: Date;
    endDate: Date;
    baseRent: number;
    status: ContractStatus;
    remainingDays: number | null;
    /** Yêu cầu gia hạn PENDING đang chờ duyệt của hợp đồng này (nếu có). */
    pendingExtensionId: number | null;
  } | null;
}

/** 1 dòng trong danh sách TẤT CẢ hợp đồng cho Manager/Landlord (màn Hợp đồng). */
export interface ContractListItem {
  id: number;
  unitNumber: string;
  floor: string;
  residentName: string;
  startDate: Date;
  endDate: Date;
  baseRent: number;
  status: ContractStatus;
  /** BR-13: số ngày còn lại tính động; null khi hợp đồng EXPIRED (BR-12). */
  remainingDays: number | null;
  /** Yêu cầu gia hạn PENDING đang chờ duyệt (nếu có) -> nút "Duyệt gia hạn". */
  pendingExtensionId: number | null;
}

/** 1 dòng trong danh sách yêu cầu gia hạn (UC08 - FID-11). */
export interface StayExtensionListItem {
  id: number;
  residentName: string;
  unitNumber: string;
  floor: string;
  currentEndDate: Date;
  requestedEndDate: Date;
  status: StayExtensionStatus;
  createdAt: Date;
  reviewedAt: Date | null;
}

/** Chi tiết yêu cầu gia hạn (UC09 - FID-12) - kèm cư dân + hợp đồng. */
export interface StayExtensionDetail extends StayExtensionListItem {
  contractId: number;
  residentPhone: string;
  contractStartDate: Date;
  contractEndDate: Date;
  contractStatus: ContractStatus;
  baseRent: number;
  reason: string | null;
  rejectReason: string | null;
  reviewedByName: string | null;
}

/** Body gửi yêu cầu gia hạn lưu trú (UC07). */
export interface CreateStayExtensionRequest {
  requestedEndDate: string; // YYYY-MM-DD
  reason: string;
}

/** Body duyệt/từ chối yêu cầu gia hạn (UC09). */
export interface ReviewStayExtensionRequest {
  action: 'APPROVE' | 'REJECT';
  rejectReason?: string;
}

/** Body tạo sự cố (UC19) - ảnh gửi qua multipart, xử lý riêng ở route. */
export interface CreateTicketRequest {
  category: string;
  description: string;
}

/** Body đổi trạng thái sự cố (UC20). */
export interface UpdateTicketStatusRequest {
  status: TicketStatus;
  internalNotes?: string;
}

/** Body phân công sự cố cho nhân viên (UC21). */
export interface AssignTicketRequest {
  assignedTo: number;
  title: string;
  description?: string;
}

/** Body cập nhật tiến độ công việc (UC23) - ảnh hoàn thành gửi qua multipart. */
export interface UpdateTaskProgressRequest {
  status: TaskStatus;
  progressNotes?: string;
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

// ==========================================
// Module 6: Apartment Management DTOs
// ==========================================

export interface ApartmentListItem extends Apartment {
  owner_name: string | null;
  owner_phone: string | null;
  unpaid_invoice_count: number;
  unresolved_ticket_count: number;
}

export interface ApartmentDetailResponse {
  id: number;
  unit_number: string;
  floor: string;
  status: ApartmentStatus;
  area_size: number;
  base_rent: number;
  owner_id: number | null;
  owner_name: string | null;
  owner_phone: string | null;
  roommates: {
    id: number;
    full_name: string;
    phone_number: string | null;
    cccd_number: string;
    cccd_front_url: string | null;
    cccd_back_url: string | null;
    status: string;
    created_at: Date;
  }[];
  recent_bills: {
    id: number;
    month_year: string;
    total_amount: number;
    status: string;
    created_at: Date;
  }[] | null;
  recent_tickets: {
    id: number;
    category: string;
    description: string;
    status: string;
    created_at: Date;
  }[];
}

export interface CreateApartmentRequest {
  floor: string;
  roomNumber: string;
  areaSize: number;
  baseRent: number;
}

export interface UpdateApartmentRequest {
  floor: string;
  roomNumber: string;
  areaSize: number;
  baseRent: number;
}

