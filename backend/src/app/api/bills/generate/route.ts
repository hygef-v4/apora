import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as billingService from '@/services/billing.service';

/**
 * POST /api/bills/generate - UC13: Nhập chỉ số và tự động sinh hóa đơn hàng tháng
 * Roles: MANAGER | LANDLORD
 * Body: { apartmentId, monthYear, currElectricityIndex, currWaterIndex, extraFee?, extraFeeDescription? }
 */
export async function POST(req: NextRequest) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD']);

    const body = await req.json();
    const {
      apartmentId,
      monthYear,
      currElectricityIndex,
      currWaterIndex,
      extraFee = 0,
      extraFeeDescription = null,
    } = body;

    if (!apartmentId || !monthYear || currElectricityIndex === undefined || currWaterIndex === undefined) {
      return jsonError({ status: 400, message: 'Thiếu các tham số bắt buộc để sinh hóa đơn.' });
    }

    const invoice = await billingService.createMonthlyBill(
      Number(apartmentId),
      String(monthYear),
      Number(currElectricityIndex),
      Number(currWaterIndex),
      Number(extraFee),
      extraFeeDescription ? String(extraFeeDescription) : null,
    );

    return jsonSuccess('Sinh hóa đơn căn hộ thành công.', invoice, 201);
  } catch (error) {
    return jsonError(error);
  }
}
