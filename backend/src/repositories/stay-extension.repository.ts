/**
 * StayExtensionRepository - Data Access cho Module 2: Stay Extension (UC07-UC09)
 *
 * Thao tác trên bảng stay_extensions, join users + apartments + contracts
 * để phục vụ danh sách (UC08) và màn duyệt (UC09).
 */

import { query } from '@/lib/db';
import { PoolClient } from 'pg';
import { ContractStatus, StayExtensionStatus } from '@/types';

/** Dòng stay_extensions kèm cư dân + căn hộ (cho danh sách UC08). */
export interface StayExtensionRow {
  id: number;
  contract_id: number;
  resident_id: number;
  current_end_date: Date;
  requested_end_date: Date;
  reason: string | null;
  status: StayExtensionStatus;
  reviewed_by: number | null;
  reviewed_at: Date | null;
  reject_reason: string | null;
  created_at: Date;
  resident_name: string;
  unit_number: string;
  floor: string;
}

/** Dòng chi tiết (UC09) - thêm SĐT cư dân, hợp đồng và tên người duyệt. */
export interface StayExtensionDetailRow extends StayExtensionRow {
  resident_phone: string;
  contract_start_date: Date;
  contract_end_date: Date;
  contract_status: ContractStatus;
  base_rent_snapshot: string;
  reviewed_by_name: string | null;
}

const LIST_SELECT = `
  SELECT se.*, u.full_name AS resident_name, a.unit_number, a.floor
  FROM stay_extensions se
  JOIN users u ON u.id = se.resident_id
  JOIN contracts c ON c.id = se.contract_id
  JOIN apartments a ON a.id = c.apartment_id`;

/** UC07: tạo yêu cầu gia hạn mới (status mặc định PENDING). */
export async function insertExtension(input: {
  contractId: number;
  residentId: number;
  currentEndDate: Date;
  requestedEndDate: string;
  reason: string;
}): Promise<StayExtensionRow> {
  const result = await query<StayExtensionRow>(
    `WITH ins AS (
       INSERT INTO stay_extensions
         (contract_id, resident_id, current_end_date, requested_end_date, reason)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *
     )
     SELECT ins.*, u.full_name AS resident_name, a.unit_number, a.floor
     FROM ins
     JOIN users u ON u.id = ins.resident_id
     JOIN contracts c ON c.id = ins.contract_id
     JOIN apartments a ON a.id = c.apartment_id`,
    [
      input.contractId,
      input.residentId,
      input.currentEndDate,
      input.requestedEndDate,
      input.reason,
    ],
  );
  return result.rows[0];
}

/**
 * UC07: yêu cầu PENDING đang chờ của một hợp đồng (chặn gửi trùng khi
 * yêu cầu trước chưa được duyệt; cũng dùng cho UC06 hiển thị "đang chờ duyệt").
 */
export async function findPendingByContract(
  contractId: number,
): Promise<{ id: number } | null> {
  const result = await query<{ id: number }>(
    `SELECT id FROM stay_extensions
     WHERE contract_id = $1 AND status = 'PENDING'
     ORDER BY id DESC LIMIT 1`,
    [contractId],
  );
  return result.rows[0] ?? null;
}

/** UC08: danh sách yêu cầu (mới gửi trước), lọc theo status nếu có. */
export async function findExtensions(
  status?: StayExtensionStatus,
): Promise<StayExtensionRow[]> {
  const statusClause = status ? ' WHERE se.status = $1' : '';
  const result = await query<StayExtensionRow>(
    `${LIST_SELECT}${statusClause} ORDER BY se.created_at DESC`,
    status ? [status] : [],
  );
  return result.rows;
}

/** UC09: chi tiết yêu cầu kèm hợp đồng + người duyệt. */
export async function findExtensionDetailById(
  id: number,
): Promise<StayExtensionDetailRow | null> {
  const result = await query<StayExtensionDetailRow>(
    `SELECT se.*, u.full_name AS resident_name, u.phone_number AS resident_phone,
            a.unit_number, a.floor,
            c.start_date AS contract_start_date, c.end_date AS contract_end_date,
            c.status AS contract_status, c.base_rent_snapshot,
            rv.full_name AS reviewed_by_name
     FROM stay_extensions se
     JOIN users u ON u.id = se.resident_id
     JOIN contracts c ON c.id = se.contract_id
     JOIN apartments a ON a.id = c.apartment_id
     LEFT JOIN users rv ON rv.id = se.reviewed_by
     WHERE se.id = $1`,
    [id],
  );
  return result.rows[0] ?? null;
}

/**
 * UC09 (BR-17): chốt kết quả duyệt - chạy TRONG transaction.
 * WHERE status = 'PENDING' chống 2 Manager duyệt cùng lúc (double-review):
 * người thứ hai nhận false -> service trả 409.
 */
export async function markReviewed(
  client: PoolClient,
  id: number,
  status: 'APPROVED' | 'REJECTED',
  reviewerId: number,
  rejectReason: string | null,
): Promise<boolean> {
  const result = await client.query(
    `UPDATE stay_extensions
     SET status = $2::varchar, reviewed_by = $3, reviewed_at = NOW(),
         reject_reason = $4
     WHERE id = $1 AND status = 'PENDING'
     RETURNING id`,
    [id, status, reviewerId, rejectReason],
  );
  return (result.rowCount ?? 0) > 0;
}
