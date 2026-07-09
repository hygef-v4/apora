import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as billingService from '@/services/billing.service';

/**
 * GET /api/bills - UC15: Xem danh sách hóa đơn cá nhân hoặc quản lý hóa đơn tòa nhà
 * Roles: RESIDENT | MANAGER | LANDLORD
 */
export async function GET(req: NextRequest) {
  try {
    const auth = await requireAuth(req, ['RESIDENT', 'MANAGER', 'LANDLORD']);
    const invoices = await billingService.getResidentInvoices(auth.id, auth.roles);
    return jsonSuccess('Lấy danh sách hóa đơn thành công.', invoices);
  } catch (error) {
    return jsonError(error);
  }
}
