import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as roommateService from '@/services/roommate.service';

/**
 * GET /api/roommates/pending - UC12: Quản lý lấy danh sách yêu cầu chờ duyệt
 * Roles: MANAGER | LANDLORD
 */
export async function GET(req: NextRequest) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const pending = await roommateService.getPendingRequests();
    return jsonSuccess('Lấy danh sách yêu cầu chờ duyệt thành công.', pending);
  } catch (error) {
    return jsonError(error);
  }
}
