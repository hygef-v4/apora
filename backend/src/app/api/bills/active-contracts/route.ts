import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as billingService from '@/services/billing.service';

/**
 * GET /api/bills/active-contracts - Lấy danh sách hợp đồng hoạt động (căn hộ, tên cư dân)
 * Roles: MANAGER | LANDLORD
 */
export async function GET(req: NextRequest) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const contracts = await billingService.getActiveContracts();
    return jsonSuccess('Lấy danh sách hợp đồng hoạt động thành công.', contracts);
  } catch (error) {
    return jsonError(error);
  }
}
