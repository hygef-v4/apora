import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as billingService from '@/services/billing.service';

/**
 * GET /api/payments - UC14: Xem lịch sử giao dịch thanh toán
 * Roles: ALL (Resident sees their own, Manager/Landlord sees all)
 */
export async function GET(req: NextRequest) {
  try {
    const auth = await requireAuth(req);
    const isManagement = auth.roles.includes('MANAGER') || auth.roles.includes('LANDLORD');
    const role = isManagement ? 'MANAGER' : 'RESIDENT';
    
    const transactions = await billingService.getTransactionHistory(auth.id, role);
    return jsonSuccess('Lấy lịch sử giao dịch thành công.', transactions);
  } catch (error) {
    return jsonError(error);
  }
}
