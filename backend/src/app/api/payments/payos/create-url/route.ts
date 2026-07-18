import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as billingService from '@/services/billing.service';

/**
 * POST /api/payments/payos/create-url - UC16: Khởi tạo link thanh toán PayOS VietQR
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

    const checkoutUrl = await billingService.initializePayment(Number(invoiceId), auth.id);
    return jsonSuccess('Khởi tạo giao dịch thanh toán thành công.', { checkoutUrl });
  } catch (error) {
    return jsonError(error);
  }
}
