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
import { jsonError, jsonSuccess, requireAuth, HttpError } from '@/lib/middleware';
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

/**
 * POST /api/managers - UC43: Create Manager Account
 * 
 * Payload: { fullName: string, phoneNumber: string }
 * Access: LANDLORD only (BR-57)
 */
export async function POST(req: NextRequest) {
  try {
    const auth = await requireAuth(req, ['LANDLORD']);
    const body = await req.json();

    if (!body.fullName || !body.phoneNumber) {
      return jsonError(new HttpError(400, 'Họ tên và số điện thoại là bắt buộc.'));
    }

    const data = await managerService.createManagerAccount(auth.id, {
      fullName: body.fullName,
      phone: body.phoneNumber,
    });

    return jsonSuccess('Tạo tài khoản quản lý thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
