/**
 * POST /api/apartments/:id/checkin - UC33: Check-in Apartment
 *   Body: { fullName, phone, startDate, endDate, depositValue }
 *   Roles: LANDLORD, MANAGER
 */

import { NextRequest } from 'next/server';
import { HttpError, jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as aptService from '@/services/apartment.service';

function parseId(raw: string): number {
  const id = Number(raw);
  if (!Number.isInteger(id) || id <= 0) {
    throw new HttpError(400, 'Mã căn hộ không hợp lệ.');
  }
  return id;
}

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    // Authenticate: LANDLORD, MANAGER (UC33)
    const auth = await requireAuth(req, ['LANDLORD', 'MANAGER']);
    const { id: rawId } = await params;
    const apartmentId = parseId(rawId);

    const body = await req.json();

    const contract = await aptService.processCheckin(auth.id, apartmentId, {
      fullName: body.fullName,
      phone: body.phone,
      startDate: body.startDate,
      endDate: body.endDate,
      depositValue: body.depositValue !== undefined ? Number(body.depositValue) : undefined,
    });

    return jsonSuccess('Check-in căn hộ thành công.', contract);
  } catch (error) {
    return jsonError(error);
  }
}
