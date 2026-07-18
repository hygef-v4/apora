/**
 * GET /api/contracts - Danh sách TẤT CẢ hợp đồng (màn Hợp đồng của Manager).
 *   Chỉ MANAGER / LANDLORD được xem toàn bộ hợp đồng trong tòa.
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as contractService from '@/services/contract.service';

export async function GET(req: NextRequest) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const data = await contractService.getAllContracts();
    return jsonSuccess('Lấy danh sách hợp đồng thành công.', data);
  } catch (error) {
    return jsonError(error);
  }
}
