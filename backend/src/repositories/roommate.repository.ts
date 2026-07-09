import { query } from '@/lib/db';

export interface RoommateData {
  apartment_id: number;
  full_name: string;
  phone_number: string | null;
  cccd_number: string;
  cccd_front_url: string | null;
  cccd_back_url: string | null;
}

/** Lấy danh sách thành viên của 1 căn hộ */
export async function findRoommatesByApartmentId(apartmentId: number): Promise<any[]> {
  const res = await query(
    `SELECT * FROM roommates 
     WHERE apartment_id = $1 
     ORDER BY created_at DESC`,
    [apartmentId]
  );
  return res.rows;
}

/** Lấy tất cả yêu cầu duyệt thành viên đang chờ (PENDING) kèm số căn hộ của quản lý */
export async function findPendingRoommates(): Promise<any[]> {
  const res = await query(
    `SELECT r.*, a.unit_number 
     FROM roommates r
     JOIN apartments a ON r.apartment_id = a.id
     WHERE r.status = 'PENDING'
     ORDER BY r.created_at ASC`
  );
  return res.rows;
}

/** Lấy chi tiết thông tin thành viên theo ID */
export async function findRoommateById(id: number): Promise<any | null> {
  const res = await query(
    `SELECT r.*, a.unit_number 
     FROM roommates r
     JOIN apartments a ON r.apartment_id = a.id
     WHERE r.id = $1`,
    [id]
  );
  return res.rows[0] || null;
}

/** Tạo bản ghi thành viên mới */
export async function createRoommate(data: RoommateData): Promise<any> {
  const res = await query(
    `INSERT INTO roommates (
      apartment_id, full_name, phone_number, cccd_number, cccd_front_url, cccd_back_url, status
     ) VALUES ($1, $2, $3, $4, $5, $6, 'PENDING')
     RETURNING *`,
    [
      data.apartment_id,
      data.full_name,
      data.phone_number,
      data.cccd_number,
      data.cccd_front_url,
      data.cccd_back_url,
    ]
  );
  return res.rows[0];
}

/** Cập nhật trạng thái duyệt thành viên */
export async function updateRoommateStatus(id: number, status: 'APPROVED' | 'REJECTED'): Promise<any> {
  const res = await query(
    `UPDATE roommates 
     SET status = $1 
     WHERE id = $2 
     RETURNING *`,
    [status, id]
  );
  return res.rows[0];
}

/** Tìm hợp đồng hoạt động của 1 cư dân */
export async function findActiveContractByResidentId(residentId: number): Promise<any | null> {
  const res = await query(
    `SELECT c.*, a.unit_number 
     FROM contracts c
     JOIN apartments a ON c.apartment_id = a.id
     WHERE c.resident_id = $1 AND c.status = 'ACTIVE'
     LIMIT 1`,
    [residentId]
  );
  return res.rows[0] || null;
}
