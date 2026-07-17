/**
 * POST /api/apartments/:id/checkout - UC34: Checkout Apartment
 *   Body: none
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
    // Authenticate: LANDLORD, MANAGER (UC34)
    const auth = await requireAuth(req, ['LANDLORD', 'MANAGER']);
    const { id: rawId } = await params;
    const apartmentId = parseId(rawId);

    await aptService.processCheckout(auth.id, apartmentId);

    return jsonSuccess('Checkout căn hộ thành công.');
  } catch (error) {
    return jsonError(error);
  }
}
