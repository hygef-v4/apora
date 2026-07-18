import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as roommateService from '@/services/roommate.service';

/**
 * PATCH /api/roommates/[id]/status - UC12: Phê duyệt hoặc từ chối đăng ký thành viên
 * Roles: MANAGER | LANDLORD
 * Body: { status: 'APPROVED' | 'REJECTED', reason?: string }
 */
export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const auth = await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const { id } = await params;
    const roommateId = Number(id);

    if (!Number.isInteger(roommateId) || roommateId <= 0) {
      throw new HttpError(400, 'Mã yêu cầu thành viên không hợp lệ.');
    }

    const body = await req.json().catch(() => ({}));
    const { status, reason = '' } = body;

    if (status !== 'APPROVED' && status !== 'REJECTED') {
      throw new HttpError(400, 'Trạng thái cập nhật phải là APPROVED hoặc REJECTED.');
    }

    let result;
    if (status === 'APPROVED') {
      result = await roommateService.approveRoommateRequest(auth.id, roommateId);
    } else {
      result = await roommateService.rejectRoommateRequest(auth.id, roommateId, reason);
    }

    const actionText = status === 'APPROVED' ? 'phê duyệt' : 'từ chối';
    return jsonSuccess(`Đã ${actionText} yêu cầu đăng ký thành viên thành công.`, result);
  } catch (error) {
    return jsonError(error);
  }
}
