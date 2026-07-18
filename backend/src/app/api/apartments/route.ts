/**
 * GET  /api/apartments - UC29: View Apartment List
 *   Query params: search=<unit_number/owner_name>, status=<EMPTY/OCCUPIED/HAS_DEBT>
 *   Roles: LANDLORD, MANAGER, SECURITY_GUARD
 *
 * POST /api/apartments - UC31: Create New Apartment
 *   Body: { floor, roomNumber, areaSize, baseRent }
 *   Roles: LANDLORD
 */

import { NextRequest } from 'next/server';
import { jsonError, jsonSuccess, requireAuth } from '@/lib/middleware';
import * as aptService from '@/services/apartment.service';

export async function GET(req: NextRequest) {
  try {
    // Authorized roles: LANDLORD, MANAGER, SECURITY_GUARD
    await requireAuth(req, ['LANDLORD', 'MANAGER', 'SECURITY_GUARD']);
    
    const { searchParams } = req.nextUrl;
    const search = searchParams.get('search') ?? undefined;
    const status = searchParams.get('status') ?? undefined;

    const apartments = await aptService.getApartmentsList(search, status);
    
    return jsonSuccess('Lấy danh sách căn hộ thành công.', apartments);
  } catch (error) {
    return jsonError(error);
  }
}

export async function POST(req: NextRequest) {
  try {
    // BR-60: Only Landlord can create new apartments
    await requireAuth(req, ['LANDLORD']);
    
    const body = await req.json();
    
    const newApartment = await aptService.createNewApartment({
      floor: body.floor,
      roomNumber: body.roomNumber,
      areaSize: Number(body.areaSize),
      baseRent: Number(body.baseRent),
    });

    return jsonSuccess('Tạo căn hộ mới thành công.', newApartment, 201);
  } catch (error) {
    return jsonError(error);
  }
}
