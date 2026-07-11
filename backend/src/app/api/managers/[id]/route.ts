/**
 * GET /api/managers/:id - UC42: View Manager Detail
 *
 * Returns the detailed profile, contact information, account status,
 * and management history of a specific Manager account.
 *
 * Access: LANDLORD only (BR-60).
 * BR-08: password_hash is never included in the response.
 * BR-62: Strictly read-only — no data modifications occur.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 9 (ManagerController.getManagerDetail)
 */

import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as managerService from '@/services/manager.service';

/**
 * Parses and validates the Manager ID path parameter.
 *
 * @param raw - The raw string from the URL path parameter
 * @returns The parsed integer ID
 * @throws HttpError 400 if the ID is not a positive integer
 */
function parseId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'Mã quản lý không hợp lệ.');
  }
  return id;
}

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    await requireAuth(req, ['LANDLORD']);
    const { id } = await params;
    const data = await managerService.getManagerProfile(parseId(id));
    return jsonSuccess('Lấy thông tin quản lý thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
