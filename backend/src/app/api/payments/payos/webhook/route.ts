import { NextRequest, NextResponse } from 'next/server';
import { jsonError } from '@/lib/middleware';
import * as billingService from '@/services/billing.service';

/**
 * POST /api/payments/payos/webhook - BR-32: Nhận tín hiệu thanh toán từ PayOS
 * Public endpoint (Xác thực chữ ký HMAC-SHA256 trong Service Layer)
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    await billingService.processPaymentCallback(body);
    return NextResponse.json({ status: 'success', message: 'Webhook processed successfully' });
  } catch (error) {
    return jsonError(error);
  }
}
