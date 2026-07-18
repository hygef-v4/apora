/**
 * GET /api/contracts/my - UC06: Xem hợp đồng của chính mình
 *   Mọi role đăng nhập đều gọi được (actor UC06: Resident/Manager/Guard/Landlord);
 *   BR-23: chỉ trả về hợp đồng gắn với đúng user trong JWT.
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as contractService from '@/services/contract.service';

export async function GET(req: NextRequest) {
  try {
    const payload = await requireAuth(req);
    const data = await contractService.getMyContract(payload.id);
    return jsonSuccess('Lấy thông tin hợp đồng thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
