/**
 * Auth Middleware - Role-based Access Control (RBAC)
 *
 * Middleware kiểm tra JWT Token và phân quyền API:
 * - Giải mã JWT từ Header: Authorization: Bearer <token>
 * - Kiểm tra role có đủ quyền truy cập API endpoint không
 * - Trả về 401 nếu token không hợp lệ
 * - Trả về 403 nếu không đủ quyền
 *
 * Roles: 'ADMIN' | 'RESIDENT' | 'STAFF'
 *
 * @see PRM393 - Mục "Kiểm tra quyền"
 */

// TODO: Implement RBAC middleware

export {};
