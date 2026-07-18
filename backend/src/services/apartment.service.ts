/**
 * ApartmentService - Business Logic Layer for Apartment Management
 *
 * Implements validation rules, role-based visibility, data masking (BR-08, BR-60),
 * and coordinates data retrieval from repositories.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 6 (ApartmentService)
 */

import { HttpError } from '@/lib/middleware';
import { withTransaction } from '@/lib/db';
import { hashPassword, validatePhoneNumber } from '@/lib/auth';
import { deleteImagesBatch } from '@/lib/cloudinary';
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

/**
 * Process check-in for an empty apartment (UC33).
 * Creates a new Resident user, contract record, updates apartment status,
 * inserts notifications and audit log. Done as a single ACID transaction (BR-65).
 *
 * @param actorId ID of the Landlord/Manager executing the action
 * @param apartmentId Apartment ID
 * @param data Check-in form parameters
 * @returns The created contract record
 */
export async function processCheckin(
  actorId: number,
  apartmentId: number,
  data: {
    fullName: string;
    phone: string;
    startDate: string;
    endDate: string;
    depositValue?: number;
  },
): Promise<any> {
  const { fullName, phone, startDate, endDate, depositValue } = data;

  // Basic validations
  if (!fullName || fullName.trim() === '') {
    throw new HttpError(400, 'Vui lòng nhập họ và tên cư dân.');
  }
  if (!phone || phone.trim() === '') {
    throw new HttpError(400, 'Vui lòng nhập số điện thoại.');
  }
  const phoneError = validatePhoneNumber(phone.trim());
  if (phoneError) {
    throw new HttpError(400, phoneError);
  }
  if (!startDate || !endDate) {
    throw new HttpError(400, 'Vui lòng nhập ngày bắt đầu và kết thúc hợp đồng.');
  }

  const start = new Date(startDate);
  const end = new Date(endDate);
  if (isNaN(start.getTime()) || isNaN(end.getTime())) {
    throw new HttpError(400, 'Ngày hợp đồng không đúng định dạng.');
  }
  if (start >= end) {
    throw new HttpError(400, 'Ngày bắt đầu hợp đồng phải trước ngày kết thúc.');
  }
  if (depositValue !== undefined && (isNaN(depositValue) || depositValue < 0)) {
    throw new HttpError(400, 'Tiền đặt cọc phải là số không âm.');
  }

  // Execute check-in inside a transaction (BR-65)
  return withTransaction(async (client) => {
    // 1. Lock and verify apartment status is EMPTY (BR-47)
    const aptRes = await client.query(
      'SELECT id, unit_number, base_rent, status FROM apartments WHERE id = $1 FOR UPDATE',
      [apartmentId],
    );
    const apartment = aptRes.rows[0];
    if (!apartment) {
      throw new HttpError(404, 'Không tìm thấy căn hộ trong hệ thống.');
    }
    if (apartment.status !== 'EMPTY') {
      throw new HttpError(400, 'Căn hộ phải ở trạng thái EMPTY để thực hiện check-in.');
    }

    // 2. Verify unique phone number across the system (BR-02)
    const userRes = await client.query(
      'SELECT id, status, full_name FROM users WHERE phone_number = $1 FOR UPDATE',
      [phone.trim()],
    );

    let residentId: number;

    if (userRes.rows.length > 0) {
      const existingUser = userRes.rows[0];
      const nameMatches = existingUser.full_name.toLowerCase() === fullName.trim().toLowerCase();
      if (!nameMatches) {
        throw new HttpError(409, 'Số điện thoại này đã được đăng ký với họ tên khác. Vui lòng kiểm tra lại.');
      }

      if (existingUser.status === 'ACTIVE') {
        // Tenant is renting another room, reuse the same active account
        residentId = existingUser.id;
      } else {
        // If user exists but is INACTIVE (previously checked out), reactivate them without changing name
        residentId = existingUser.id;
        const defaultPasswordHash = await hashPassword('Apora@123');
        await client.query(
          `UPDATE users
           SET status = 'ACTIVE',
               password_hash = $2,
               must_change_password = TRUE,
               roles = ARRAY['RESIDENT']::text[],
               token_version = token_version + 1
           WHERE id = $1`,
          [residentId, defaultPasswordHash],
        );
      }
    } else {
      // 3. Create RESIDENT user with default password (BR-01)
      const defaultPasswordHash = await hashPassword('Apora@123');
      const newUserRes = await client.query(
        `INSERT INTO users (phone_number, password_hash, full_name, roles, status, must_change_password)
         VALUES ($1, $2, $3, ARRAY['RESIDENT']::text[], 'ACTIVE', TRUE)
         RETURNING id, phone_number, full_name`,
        [phone.trim(), defaultPasswordHash, fullName.trim()],
      );
      residentId = newUserRes.rows[0].id;
    }

    // 4. Create Contract with snapshot rent amount
    const contractRes = await client.query(
      `INSERT INTO contracts (apartment_id, resident_id, start_date, end_date, base_rent_snapshot, status)
       VALUES ($1, $2, $3, $4, $5, 'ACTIVE')
       RETURNING *`,
      [apartmentId, residentId, startDate, endDate, apartment.base_rent],
    );
    const contract = contractRes.rows[0];

    // 5. Update apartment status to OCCUPIED and assign owner (BR-47)
    await client.query(
      `UPDATE apartments
       SET status = 'OCCUPIED', owner_id = $2
       WHERE id = $1`,
      [apartmentId, residentId],
    );

    // 6. Log the action to audit_logs (BR-04)
    await client.query(
      `INSERT INTO audit_logs (actor_id, target_user_id, action, old_value, new_value, reason)
       VALUES ($1, $2, 'APARTMENT_CHECKIN', NULL, $3, $4)`,
      [
        actorId,
        residentId,
        {
          apartmentId,
          unitNumber: apartment.unit_number,
          contractId: contract.id,
          startDate,
          endDate,
        },
        `Nhận phòng căn hộ ${apartment.unit_number}`,
      ],
    );

    // 7. Send a notification to the new resident
    await client.query(
      `INSERT INTO notifications (user_id, title, body, type, reference_id)
       VALUES ($1, $2, $3, 'SYSTEM', $4)`,
      [
        residentId,
        'Nhận phòng thành công',
        // Không nhúng mật khẩu mặc định vào nội dung lưu DB (tránh lộ khi rò rỉ
        // bảng notifications). Ban quản lý cấp mật khẩu mặc định trực tiếp; cư dân
        // buộc phải đổi ở lần đăng nhập đầu (BR-01/must_change_password).
        `Chào mừng bạn đến với căn hộ ${apartment.unit_number}! Vui lòng đăng nhập bằng mật khẩu mặc định do Ban quản lý cung cấp và đổi mật khẩu ngay ở lần đăng nhập đầu tiên.`,
        apartmentId,
      ],
    );

    return contract;
  });
}

/**
 * Process check-out for an occupied apartment (UC34).
 * Terminates active contract, soft-deletes the resident, anonymizes roommates,
 * revokes FCM tokens, updates apartment status to EMPTY. Done as a single ACID transaction (BR-65).
 * Batch deletes roommate images from Cloudinary (BR-20).
 *
 * @param actorId ID of the Landlord/Manager executing the action
 * @param apartmentId Apartment ID
 */
export async function processCheckout(
  actorId: number,
  apartmentId: number,
): Promise<void> {
  const roommatesToPurge: any[] = await withTransaction(async (client) => {
    // 1. Lock and verify apartment is OCCUPIED (BR-47)
    const aptRes = await client.query(
      'SELECT id, unit_number, owner_id, status FROM apartments WHERE id = $1 FOR UPDATE',
      [apartmentId],
    );
    const apartment = aptRes.rows[0];
    if (!apartment) {
      throw new HttpError(404, 'Không tìm thấy căn hộ trong hệ thống.');
    }
    if (apartment.status !== 'OCCUPIED' || !apartment.owner_id) {
      throw new HttpError(400, 'Căn hộ phải ở trạng thái OCCUPIED để thực hiện check-out.');
    }
    const residentId = apartment.owner_id;

    // 2. Terminate the active contract
    await client.query(
      `UPDATE contracts
       SET status = 'EXPIRED'
       WHERE apartment_id = $1 AND status = 'ACTIVE'`,
      [apartmentId],
    );

    // 3. Chỉ vô hiệu hóa tài khoản khi cư dân KHÔNG còn hợp đồng ACTIVE nào khác.
    // Một cư dân có thể thuê nhiều phòng dùng chung 1 tài khoản (xem processCheckin);
    // trả 1 phòng không được đá văng phiên đăng nhập / khóa tài khoản ở phòng còn lại.
    const remainingRes = await client.query(
      `SELECT 1 FROM contracts
       WHERE resident_id = $1 AND status = 'ACTIVE'
       LIMIT 1`,
      [residentId],
    );
    const stillRenting = remainingRes.rows.length > 0;

    if (!stillRenting) {
      // 3a. Soft-delete resident: status to INACTIVE, bump token_version (BR-49, BR-07)
      await client.query(
        `UPDATE users
         SET status = 'INACTIVE', token_version = token_version + 1
         WHERE id = $1`,
        [residentId],
      );

      // 3b. Revoke active device FCM tokens
      await client.query(
        `UPDATE device_tokens
         SET status = 'REVOKED', revoked_at = NOW()
         WHERE user_id = $1 AND status = 'ACTIVE'`,
        [residentId],
      );
    }

    // 5. Query and collect roommate images for Cloudinary deletion (BR-20)
    const roommatesRes = await client.query(
      `SELECT id, cccd_front_url, cccd_back_url 
       FROM roommates 
       WHERE apartment_id = $1`,
      [apartmentId],
    );
    const roommates = roommatesRes.rows;

    // 6. Anonymize roommates: nullify photo URLs and mask CCCD (BR-20)
    await client.query(
      `UPDATE roommates
       SET cccd_front_url = NULL,
           cccd_back_url = NULL,
           cccd_number = 'MASK_' || id
       WHERE apartment_id = $1`,
      [apartmentId],
    );

    // 7. Update apartment status to EMPTY and clear owner (BR-47)
    await client.query(
      `UPDATE apartments
       SET status = 'EMPTY', owner_id = NULL
       WHERE id = $1`,
      [apartmentId],
    );

    // 8. Log the action to audit_logs (BR-04)
    await client.query(
      `INSERT INTO audit_logs (actor_id, target_user_id, action, old_value, new_value, reason)
       VALUES ($1, $2, 'APARTMENT_CHECKOUT', $3, NULL, $4)`,
      [
        actorId,
        residentId,
        {
          apartmentId,
          unitNumber: apartment.unit_number,
        },
        `Trả phòng căn hộ ${apartment.unit_number}`,
      ],
    );

    return roommates;
  });

  // Batch delete Cloudinary files asynchronously outside the SQL transaction block
  const urlsToPurge: string[] = [];
  for (const rm of roommatesToPurge) {
    if (rm.cccd_front_url) urlsToPurge.push(rm.cccd_front_url);
    if (rm.cccd_back_url) urlsToPurge.push(rm.cccd_back_url);
  }

  if (urlsToPurge.length > 0) {
    deleteImagesBatch(urlsToPurge).catch((error) => {
      console.error(
        `[ApartmentService] Xóa ảnh CCCD roommates trên Cloudinary thất bại cho căn hộ ${apartmentId}:`,
        error,
      );
    });
  }
}

