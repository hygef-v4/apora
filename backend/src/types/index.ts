/**
 * TypeScript Type Definitions
 *
 * Định nghĩa interface cho toàn bộ entities trong hệ thống.
 * Khớp với ERD trong tài liệu PRM393.
 */

// ==========================================
// Enums (Giá trị cố định trong Database)
// ==========================================

export type UserRole = 'ADMIN' | 'RESIDENT' | 'STAFF';
export type UserStatus = 'ACTIVE' | 'INACTIVE';
export type ApartmentStatus = 'EMPTY' | 'OCCUPIED';
export type RoomMemberStatus = 'PENDING' | 'APPROVED' | 'REJECTED' | 'INACTIVE';
export type BillStatus = 'UNPAID' | 'PAID';
export type PaymentMethod = 'PAYOS' | 'CASH';
export type TicketStatus = 'PENDING' | 'PROCESSING' | 'WAITING_RATING' | 'CLOSED';
export type VisitorStatus = 'EXPECTED' | 'ARRIVED' | 'CANCELLED';

// ==========================================
// Entity Interfaces (Khớp với bảng DB)
// ==========================================

export interface User {
  id: string;
  phone: string;
  password_hash: string;
  full_name: string;
  role: UserRole;
  status: UserStatus;
  avatar_url: string | null;
  fcm_token: string | null;
  created_at: Date;
}

export interface Apartment {
  id: string;
  room_number: string;
  owner_id: string | null;
  status: ApartmentStatus;
}

export interface RoomMember {
  id: string;
  apartment_id: string;
  full_name: string;
  cccd_number: string | null;
  cccd_image_url: string | null;
  status: RoomMemberStatus;
}

export interface Bill {
  id: string;
  apartment_id: string;
  user_id: string;
  month_year: string;
  total_amount: number;
  payment_method: PaymentMethod;
  status: BillStatus;
  paid_at: Date | null;
  payos_order_code: number | null;
  created_at: Date;
}

export interface Ticket {
  id: string;
  apartment_id: string;
  resident_id: string;
  assigned_staff_id: string | null;
  category: string;
  description: string;
  issue_images: string[];
  result_images: string[];
  status: TicketStatus;
  rating: number | null;
  feedback: string | null;
  created_at: Date;
}

export interface Visitor {
  id: string;
  apartment_id: string;
  resident_id: string;
  visitor_name: string;
  guest_count: number;
  expected_date: Date;
  arrived_at: Date | null;
  status: VisitorStatus;
  created_at: Date;
}

export interface News {
  id: string;
  title: string;
  content: string;
  image_url: string | null;
  author_id: string;
  created_at: Date;
}

export interface ChatRoom {
  id: string;
  resident_id: string;
  last_message: string | null;
  updated_at: Date;
}

export interface Message {
  id: string;
  room_id: string;
  sender_id: string;
  text: string;
  created_at: Date;
}

// ==========================================
// API Request/Response Types
// ==========================================

export interface LoginRequest {
  phone: string;
  password: string;
}

export interface LoginResponse {
  status: 'success' | 'error';
  message: string;
  data?: {
    token: string;
    user: {
      id: string;
      fullName: string;
      role: UserRole;
      apartmentId: string | null;
    };
  };
}

export interface ApiResponse<T = unknown> {
  status: 'success' | 'error';
  message: string;
  data?: T;
}

/**
 * JWT Payload structure
 * Được encode vào JWT Token khi đăng nhập thành công
 */
export interface JwtPayload {
  id: string;
  role: UserRole;
  iat?: number;
  exp?: number;
}
