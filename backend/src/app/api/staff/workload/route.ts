/**
 * GET /api/staff/workload - UC21 (BR-41): Bảng tải việc nhân viên
 *   Danh sách nhân viên vận hành ACTIVE (cả 3 role SECURITY_GUARD /
 *   JANITOR / TECHNICIAN) kèm số task đang hoạt động (ASSIGNED +
 *   IN_PROGRESS) để Manager chọn người phân công.
 *   Chỉ MANAGER / LANDLORD.
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as ticketService from '@/services/ticket.service';

export async function GET(req: NextRequest) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const data = await ticketService.getStaffWorkload();
    return jsonSuccess('Lấy bảng tải việc nhân viên thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
