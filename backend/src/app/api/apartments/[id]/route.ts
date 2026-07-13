/**
 * GET /api/apartments/:id - UC30: View Apartment Detail
 *   Roles: LANDLORD, MANAGER, SECURITY_GUARD
 *
 * PUT /api/apartments/:id - UC32: Update Apartment Information
 *   Body: { floor, roomNumber, areaSize, baseRent }
 *   Roles: LANDLORD
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

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const auth = await requireAuth(req, ['LANDLORD', 'MANAGER', 'SECURITY_GUARD']);
    const { id } = await params;

    const details = await aptService.getApartmentDetailById(parseId(id), auth.roles);
    
    return jsonSuccess('Lấy chi tiết căn hộ thành công.', details);
  } catch (error) {
    return jsonError(error);
  }
}

export async function PUT(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    // BR-60: Only Landlord can update apartment information
    await requireAuth(req, ['LANDLORD']);
    const { id } = await params;
    
    const body = await req.json();

    const updatedApt = await aptService.modifyApartment(parseId(id), {
      floor: body.floor,
      roomNumber: body.roomNumber,
      areaSize: Number(body.areaSize),
      baseRent: Number(body.baseRent),
    });

    return jsonSuccess('Cập nhật thông tin căn hộ thành công.', updatedApt);
  } catch (error) {
    return jsonError(error);
  }
}
