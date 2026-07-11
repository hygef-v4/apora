/**
 * GET /api/managers - UC41: View Manager List
 *   Query params: ?status=ACTIVE|INACTIVE & search=<name/phone>
 *
 * Access: LANDLORD only (BR-60).
 * Returns the filtered list of Manager accounts along with aggregate statistics.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 9 (ManagerController.getManagerList)
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as managerService from '@/services/manager.service';

export async function GET(req: NextRequest) {
  try {
    await requireAuth(req, ['LANDLORD']);
    const { searchParams } = req.nextUrl;
    const data = await managerService.getManagerAccounts({
      status: searchParams.get('status') ?? undefined,
      search: searchParams.get('search') ?? undefined,
    });
    return jsonSuccess('Lấy danh sách quản lý thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
