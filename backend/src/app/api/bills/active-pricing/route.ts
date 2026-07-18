import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as billingService from '@/services/billing.service';

/**
 * GET /api/bills/active-pricing - Lấy đơn giá điện, nước, phí quản lý đang áp dụng
 * Roles: MANAGER | LANDLORD | RESIDENT
 */
export async function GET(req: NextRequest) {
  try {
    await requireAuth(req, ['MANAGER', 'LANDLORD', 'RESIDENT']);
    const pricing = await billingService.getActivePricing();
    return jsonSuccess('Lấy đơn giá hoạt động thành công.', pricing);
  } catch (error) {
    return jsonError(error);
  }
}

/**
 * POST /api/bills/active-pricing - Cập nhật/Thiết lập đơn giá mới
 * Roles: MANAGER | LANDLORD
 */
export async function POST(req: NextRequest) {
  try {
    const auth = await requireAuth(req, ['MANAGER', 'LANDLORD']);
    const body = await req.json().catch(() => ({}));
    const { electricity_rate, water_rate, mgmt_fee } = body;

    if (electricity_rate === undefined || water_rate === undefined || mgmt_fee === undefined) {
      throw new HttpError(400, 'Vui lòng cung cấp đầy đủ thông tin đơn giá.');
    }

    const elRate = Number(electricity_rate);
    const waRate = Number(water_rate);
    const mgFee = Number(mgmt_fee);

    if (isNaN(elRate) || elRate < 0 || isNaN(waRate) || waRate < 0 || isNaN(mgFee) || mgFee < 0) {
      throw new HttpError(400, 'Đơn giá không hợp lệ.');
    }

    const newSetting = await billingService.updatePricingSettings(auth.id, elRate, waRate, mgFee);
    return jsonSuccess('Cập nhật đơn giá thành công.', newSetting);
  } catch (error) {
    return jsonError(error);
  }
}
