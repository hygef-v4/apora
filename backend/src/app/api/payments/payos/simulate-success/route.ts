import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as billingService from '@/services/billing.service';

/**
 * POST /api/payments/payos/simulate-success - Giả lập thanh toán thành công (Sandbox)
 * Roles: RESIDENT
 * Body: { invoiceId }
 */
export async function POST(req: NextRequest) {
  try {
    const auth = await requireAuth(req, ['RESIDENT']);
    const body = await req.json();
    const { invoiceId } = body;

    if (!invoiceId) {
      return jsonError({ status: 400, message: 'Thiếu mã hóa đơn invoiceId.' });
    }

    const payment = await billingService.simulateSuccessPayment(Number(invoiceId), auth.id);
    return jsonSuccess('Giả lập thanh toán hóa đơn thành công.', payment);
  } catch (error) {
    return jsonError(error);
  }
}
