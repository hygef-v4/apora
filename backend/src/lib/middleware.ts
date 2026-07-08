/**
 * Auth Middleware - Role-based Access Control (RBAC)
 *
 * Kiểm tra JWT Token và phân quyền API:
 * - Giải mã JWT từ Header: Authorization: Bearer <token>
 * - Query user 1 lần để kiểm tra: tồn tại, status ACTIVE (BR-04),
 *   token_version khớp (BR-07)
 * - Kiểm tra role có đủ quyền truy cập endpoint (403 nếu thiếu)
 *
 * Roles: LANDLORD | MANAGER | RESIDENT | SECURITY_GUARD | JANITOR | TECHNICIAN
 *
 * Cách dùng trong route.ts:
 *   const auth = await requireAuth(req);                    // chỉ cần đăng nhập
 *   const auth = await requireAuth(req, ['MANAGER']);       // cần đúng role
 *   // auth ném HttpError -> bắt ở route và trả jsonError(err)
 */

import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { verifyToken } from '@/lib/auth';
import { ApiResponse, JwtPayload, UserRole } from '@/types';

/** Lỗi có kèm HTTP status code để route map thẳng sang response. */
export class HttpError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

/** Response lỗi chuẩn { status: 'error', message }. */
export function jsonError(error: unknown): NextResponse<ApiResponse> {
  if (error instanceof HttpError) {
    return NextResponse.json(
      { status: 'error', message: error.message },
      { status: error.status },
    );
  }
  console.error('[API] Lỗi không xác định:', error);
  return NextResponse.json(
    { status: 'error', message: 'Đã có lỗi xảy ra. Vui lòng thử lại sau.' },
    { status: 500 },
  );
}

/** Response thành công chuẩn { status: 'success', message, data }. */
export function jsonSuccess<T>(message: string, data?: T, status = 200): NextResponse<ApiResponse<T>> {
  return NextResponse.json({ status: 'success', message, data }, { status });
}

/**
 * Xác thực request. Ném HttpError 401/403 nếu không hợp lệ.
 * @param allowedRoles Nếu truyền, user phải có ít nhất 1 role trong danh sách.
 */
export async function requireAuth(
  req: NextRequest,
  allowedRoles?: UserRole[],
): Promise<JwtPayload> {
  const header = req.headers.get('authorization');
  if (!header || !header.startsWith('Bearer ')) {
    throw new HttpError(401, 'Vui lòng đăng nhập để tiếp tục.');
  }

  let payload: JwtPayload;
  try {
    payload = verifyToken(header.slice('Bearer '.length));
  } catch {
    throw new HttpError(401, 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.');
  }

  // 1 query duy nhất: check tồn tại + ACTIVE (BR-04) + token_version (BR-07)
  const result = await query(
    'SELECT status, token_version, roles FROM users WHERE id = $1',
    [payload.id],
  );
  const user = result.rows[0];
  if (!user || user.status !== 'ACTIVE') {
    throw new HttpError(401, 'Tài khoản của bạn đã bị vô hiệu hóa. Vui lòng liên hệ Ban quản lý.');
  }
  if (user.token_version !== payload.tv) {
    throw new HttpError(401, 'Phiên đăng nhập đã hết hiệu lực. Vui lòng đăng nhập lại.');
  }

  if (allowedRoles && allowedRoles.length > 0) {
    const roles: UserRole[] = user.roles;
    const permitted = roles.some((r) => allowedRoles.includes(r));
    if (!permitted) {
      throw new HttpError(403, 'Bạn không có quyền thực hiện thao tác này.');
    }
    // Dùng roles mới nhất từ DB (phòng trường hợp role đổi sau khi ký token)
    payload.roles = roles;
  }

  return payload;
}
