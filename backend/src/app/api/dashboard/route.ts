/**
 * GET /api/dashboard - UC35: View Dashboard & Statistics Report
 *   Query params: monthYear=<MM/YYYY>
 *   Roles: LANDLORD, MANAGER
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as dashboardService from '@/services/dashboard.service';

export async function GET(req: NextRequest) {
  try {
    // Authenticate: LANDLORD or MANAGER (UC35)
    await requireAuth(req, ['LANDLORD', 'MANAGER']);

    const { searchParams } = req.nextUrl;
    let monthYear = searchParams.get('monthYear');

    // Default to the current month if monthYear query parameter is missing
    if (!monthYear || monthYear.trim() === '') {
      const now = new Date();
      const month = String(now.getMonth() + 1).padStart(2, '0');
      const year = now.getFullYear();
      monthYear = `${month}/${year}`;
    }

    const stats = await dashboardService.calculateDashboardStats(monthYear.trim());

    return jsonSuccess('Lấy số liệu thống kê dashboard thành công.', stats);
  } catch (error) {
    return jsonError(error);
  }
}
