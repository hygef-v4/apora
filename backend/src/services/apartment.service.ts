/**
 * ApartmentService - Business Logic Layer for Apartment Management
 *
 * Implements validation rules, role-based visibility, data masking (BR-08, BR-60),
 * and coordinates data retrieval from repositories.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 6 (ApartmentService)
 */

import { HttpError } from '@/lib/middleware';
import * as aptRepo from '@/repositories/apartment.repository';
import { Apartment, ApartmentDetailResponse, ApartmentListItem, UserRole } from '@/types';

/**
 * Get the list of apartments with operational stats.
 *
 * @param search Search keyword (unit number or owner name)
 * @param status Status filter (ALL, EMPTY, OCCUPIED, HAS_DEBT)
 * @returns List of apartments
 */
export async function getApartmentsList(
  search?: string,
  status?: string,
): Promise<ApartmentListItem[]> {
  return aptRepo.findApartmentsWithStats(search, status);
}

/**
 * Helper to mask sensitive CCCD numbers (BR-08).
 * Replaces all but the last 4 digits with asterisks.
 *
 * @param cccd Raw CCCD number string
 * @returns Masked CCCD number string
 */
function maskCccd(cccd: string): string {
  if (!cccd) return '';
  if (cccd.length <= 4) return '*'.repeat(cccd.length);
  return '*'.repeat(cccd.length - 4) + cccd.slice(-4);
}

/**
 * Fetch detailed information for a specific apartment based on the viewing user's roles.
 * Implements data masking (BR-08) and visibility limits (BR-60).
 *
 * @param id Apartment ID
 * @param userRoles Array of roles held by the requesting user
 * @returns Detailed apartment info response
 */
export async function getApartmentDetailById(
  id: number,
  userRoles: UserRole[],
): Promise<ApartmentDetailResponse> {
  const apartment = await aptRepo.findByIdWithOwner(id);
  if (!apartment) {
    throw new HttpError(404, 'Không tìm thấy căn hộ này trong hệ thống.');
  }

  const isManagement = userRoles.includes('LANDLORD') || userRoles.includes('MANAGER');

  // Fetch approved roommates
  const roommates = await aptRepo.findApprovedRoommates(id);

  // Apply BR-08: Mask CCCD number and hide images for Security Guard/others
  const processedRoommates = roommates.map(r => {
    if (isManagement) {
      return r;
    } else {
      return {
        ...r,
        cccd_number: maskCccd(r.cccd_number),
        cccd_front_url: null, // Hide sensitive document images from Security Guard
        cccd_back_url: null,
      };
    }
  });

  // Fetch recent bills and tickets
  const recentTickets = await aptRepo.findRecentTickets(id);

  // Apply BR-60: Hide recent bills from Security Guards
  let recentBills = null;
  if (isManagement) {
    recentBills = await aptRepo.findRecentInvoices(id);
  }

  return {
    id: apartment.id,
    unit_number: apartment.unit_number,
    floor: apartment.floor,
    status: apartment.status,
    area_size: apartment.area_size,
    base_rent: apartment.base_rent,
    owner_id: apartment.owner_id,
    owner_name: apartment.owner_name,
    owner_phone: apartment.owner_phone,
    roommates: processedRoommates,
    recent_bills: recentBills,
    recent_tickets: recentTickets,
  };
}

/**
 * Create a new physical apartment.
 * Implements BR-47 (EMPTY default status) and BR-63 (Validations).
 *
 * @param data Request body data
 * @returns Created Apartment object
 */
export async function createNewApartment(data: {
  floor: string;
  roomNumber: string;
  areaSize: number;
  baseRent: number;
}): Promise<Apartment> {
  const { floor, roomNumber, areaSize, baseRent } = data;

  // BR-63: Form data validation
  if (!floor || floor.trim() === '') {
    throw new HttpError(400, 'Vui lòng điền số tầng.');
  }
  if (!roomNumber || roomNumber.trim() === '') {
    throw new HttpError(400, 'Vui lòng điền số phòng.');
  }
  if (areaSize === undefined || areaSize <= 0) {
    throw new HttpError(400, 'Diện tích căn hộ phải là số dương lớn hơn 0.');
  }
  if (baseRent === undefined || baseRent <= 0) {
    throw new HttpError(400, 'Giá thuê căn hộ phải là số dương lớn hơn 0.');
  }

  // Room number uniqueness constraint (BR-63)
  const roomExists = await aptRepo.checkUnitNumberExists(roomNumber.trim());
  if (roomExists) {
    throw new HttpError(409, `Số căn hộ "${roomNumber.trim()}" đã tồn tại. Vui lòng chọn số khác.`);
  }

  return aptRepo.createApartment(floor.trim(), roomNumber.trim(), areaSize, baseRent);
}

/**
 * Modify physical details of an existing apartment.
 * Implements BR-63 (Validations) and BR-64 (Status/Owner changes prohibited).
 *
 * @param id Apartment ID
 * @param data Request body data
 * @returns Updated Apartment object
 */
export async function modifyApartment(
  id: number,
  data: {
    floor: string;
    roomNumber: string;
    areaSize: number;
    baseRent: number;
  },
): Promise<Apartment> {
  const { floor, roomNumber, areaSize, baseRent } = data;

  // Verify apartment exists
  const existingApt = await aptRepo.findById(id);
  if (!existingApt) {
    throw new HttpError(404, 'Không tìm thấy thông tin căn hộ cần cập nhật.');
  }

  // BR-63: Form data validation
  if (!floor || floor.trim() === '') {
    throw new HttpError(400, 'Vui lòng điền số tầng.');
  }
  if (!roomNumber || roomNumber.trim() === '') {
    throw new HttpError(400, 'Vui lòng điền số phòng.');
  }
  if (areaSize === undefined || areaSize <= 0) {
    throw new HttpError(400, 'Diện tích căn hộ phải là số dương lớn hơn 0.');
  }
  if (baseRent === undefined || baseRent <= 0) {
    throw new HttpError(400, 'Giá thuê căn hộ phải là số dương lớn hơn 0.');
  }

  // Room number uniqueness (BR-63)
  const roomExists = await aptRepo.checkUnitNumberExists(roomNumber.trim(), id);
  if (roomExists) {
    throw new HttpError(409, `Số căn hộ "${roomNumber.trim()}" đã được sử dụng bởi căn hộ khác.`);
  }

  // BR-64: update only physical fields (floor, unit_number, area_size, base_rent).
  // Status, owner_id are kept unchanged.
  return aptRepo.updateApartment(id, floor.trim(), roomNumber.trim(), areaSize, baseRent);
}
