import * as roommateRepo from '@/repositories/roommate.repository';
import { insertAuditLog } from '@/repositories/audit.repository';
import { HttpError } from '@/lib/middleware';
import { query } from '@/lib/db';

/** UC10: Cư dân xem danh sách thành viên phòng */
export async function getRoommatesForResident(userId: number): Promise<any[]> {
  const contract = await roommateRepo.findActiveContractByResidentId(userId);
  if (!contract) {
    throw new HttpError(404, 'Bạn hiện không có hợp đồng thuê hoạt động nào để xem thành viên.');
  }
  return roommateRepo.findRoommatesByApartmentId(contract.apartment_id);
}

/** UC11: Cư dân đăng ký thành viên mới */
export async function registerRoommate(
  userId: number,
  data: {
    fullName: string;
    phoneNumber: string | null;
    cccdNumber: string;
    cccdFrontUrl: string | null;
    cccdBackUrl: string | null;
  }
): Promise<any> {
  const contract = await roommateRepo.findActiveContractByResidentId(userId);
  if (!contract) {
    throw new HttpError(404, 'Bạn hiện không có hợp đồng thuê hoạt động nào để đăng ký thành viên.');
  }

  // Kiểm tra trùng số CCCD toàn hệ thống
  const existing = await query('SELECT id FROM roommates WHERE cccd_number = $1', [data.cccdNumber]);
  if (existing.rows.length > 0) {
    throw new HttpError(400, 'Số CCCD này đã được đăng ký trong hệ thống.');
  }

  return roommateRepo.createRoommate({
    apartment_id: contract.apartment_id,
    full_name: data.fullName,
    phone_number: data.phoneNumber,
    cccd_number: data.cccdNumber,
    cccd_front_url: data.cccdFrontUrl,
    cccd_back_url: data.cccdBackUrl,
  });
}

/** UC12: Quản lý lấy danh sách yêu cầu chờ duyệt */
export async function getPendingRequests(): Promise<any[]> {
  return roommateRepo.findPendingRoommates();
}

/** UC12: Quản lý phê duyệt yêu cầu */
export async function approveRoommateRequest(managerId: number, id: number): Promise<any> {
  const roommate = await roommateRepo.findRoommateById(id);
  if (!roommate) {
    throw new HttpError(404, 'Không tìm thấy yêu cầu đăng ký thành viên này.');
  }

  if (roommate.status !== 'PENDING') {
    throw new HttpError(400, 'Yêu cầu đăng ký thành viên này đã được xử lý trước đó.');
  }

  const updated = await roommateRepo.updateRoommateStatus(id, 'APPROVED');

  // Ghi Audit Log hành động phê duyệt
  await insertAuditLog(
    managerId,
    null,
    'ROOMMATE_APPROVE',
    { id: roommate.id, status: roommate.status, full_name: roommate.full_name, apartment_id: roommate.apartment_id },
    { id: updated.id, status: updated.status }
  );

  return updated;
}

/** UC12: Quản lý từ chối yêu cầu */
export async function rejectRoommateRequest(managerId: number, id: number): Promise<any> {
  const roommate = await roommateRepo.findRoommateById(id);
  if (!roommate) {
    throw new HttpError(404, 'Không tìm thấy yêu cầu đăng ký thành viên này.');
  }

  if (roommate.status !== 'PENDING') {
    throw new HttpError(400, 'Yêu cầu đăng ký thành viên này đã được xử lý trước đó.');
  }

  const updated = await roommateRepo.updateRoommateStatus(id, 'REJECTED');

  // Ghi Audit Log hành động từ chối
  await insertAuditLog(
    managerId,
    null,
    'ROOMMATE_REJECT',
    { id: roommate.id, status: roommate.status, full_name: roommate.full_name, apartment_id: roommate.apartment_id },
    { id: updated.id, status: updated.status }
  );

  return updated;
}
