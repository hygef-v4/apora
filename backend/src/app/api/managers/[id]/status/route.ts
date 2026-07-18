import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import { updateManagerStatus } from '@/services/manager.service';

/**
 * Parses and validates the Manager ID path parameter.
 */
function parseId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'Mã quản lý không hợp lệ.');
  }
  return id;
}

/**
 * PATCH /api/managers/:id/status
 * Deactivates or Reactivates a Manager account (UC45).
 * BR-57: Access requires LANDLORD role.
 */
export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    // 1. Authorize: LANDLORD only (BR-57)
    const auth = await requireAuth(req, ['LANDLORD']);
    const { id } = await params;
    const targetId = parseId(id);

    // 2. Validate request body
    const body = await req.json();
    const { status } = body;

    if (status !== 'ACTIVE' && status !== 'INACTIVE') {
      throw new HttpError(400, 'Trạng thái không hợp lệ.');
    }

    // 3. Process via Service
    const updatedManager = await updateManagerStatus(auth.id, targetId, status);

    return jsonSuccess(
      status === 'ACTIVE' 
        ? 'Khôi phục tài khoản thành công' 
        : 'Vô hiệu hóa tài khoản thành công',
      updatedManager
    );
  } catch (error) {
    return jsonError(error);
  }
}

