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
  // BR-02: hai request đồng thời cùng SĐT có thể lọt qua bước check trước
  // và vướng UNIQUE constraint của Postgres -> map sang 409 thay vì 500.
  const pgError = error as { code?: string; constraint?: string };
  if (pgError?.code === '23505') {
    if (pgError.constraint === 'users_phone_number_key') {
      return NextResponse.json(
        { status: 'error', message: 'This phone number already exists. Please use another one.' },
        { status: 409 },
      );
    }
    if (pgError.constraint === 'invoices_apartment_id_month_year_key') {
      return NextResponse.json(
        { status: 'error', message: 'An invoice for this apartment and billing period already exists.' },
        { status: 409 },
      );
    }
  }
  console.error('[API] Lỗi không xác định:', error);
  return NextResponse.json(
    { status: 'error', message: 'Something went wrong. Please try again later.' },
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
 * @param options.allowPendingPasswordChange BR-01: mặc định user đang dùng mật khẩu
 *   mặc định (must_change_password) bị chặn 403 ở mọi endpoint; chỉ change-password
 *   và logout truyền true để user thoát được trạng thái này.
 */
export async function requireAuth(
  req: NextRequest,
  allowedRoles?: UserRole[],
  options?: { allowPendingPasswordChange?: boolean },
): Promise<JwtPayload> {
  const header = req.headers.get('authorization');
  if (!header || !header.startsWith('Bearer ')) {
    throw new HttpError(401, 'Please log in to continue.');
  }

  let payload: JwtPayload;
  try {
    payload = verifyToken(header.slice('Bearer '.length));
  } catch {
    throw new HttpError(401, 'Your session is invalid or has expired.');
  }

  // 1 query duy nhất: check tồn tại + ACTIVE (BR-04) + token_version (BR-07)
  // + must_change_password (BR-01)
  const result = await query(
    'SELECT status, token_version, roles, must_change_password FROM users WHERE id = $1',
    [payload.id],
  );
  const user = result.rows[0];
  if (!user || user.status !== 'ACTIVE') {
    throw new HttpError(401, 'Your account has been deactivated. Please contact the building management.');
  }
  if (user.token_version !== payload.tv) {
    throw new HttpError(401, 'Your session has expired. Please log in again.');
  }

  // BR-01: đang dùng mật khẩu mặc định -> chặn mọi API khác cho tới khi đổi
  if (user.must_change_password && !options?.allowPendingPasswordChange) {
    throw new HttpError(403, 'You must change your default password before continuing.');
  }

  // Luôn dùng roles mới nhất từ DB (role có thể đổi sau khi ký token - UC39),
  // kể cả với endpoint không truyền allowedRoles nhưng có rẽ nhánh theo role.
  payload.roles = user.roles as UserRole[];

  if (allowedRoles && allowedRoles.length > 0) {
    const permitted = payload.roles.some((r) => allowedRoles.includes(r));
    if (!permitted) {
      throw new HttpError(403, 'You do not have permission to perform this action.');
    }
  }

  return payload;
}
