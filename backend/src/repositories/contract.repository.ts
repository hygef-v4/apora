/**
 * ContractRepository - Data Access Layer for contracts table
 *
 * Handles raw SQL queries for tenancy contracts. Supports transactional pg PoolClient.
 */

import { query } from '@/lib/db';
import { PoolClient } from 'pg';
import { ApartmentStatus, ContractStatus } from '@/types';

/**
 * Insert a new contract record.
 *
 * @param apartmentId Apartment ID
 * @param residentId Resident user ID
 * @param startDate Contract start date (YYYY-MM-DD)
 * @param endDate Contract end date (YYYY-MM-DD)
 * @param rentSnapshot Room rent amount snapshot at check-in
 * @param client Optional PoolClient for transactional queries
 * @returns The created contract row
 */
export async function createContract(
  apartmentId: number,
  residentId: number,
  startDate: string,
  endDate: string,
  rentSnapshot: number,
  client?: PoolClient,
): Promise<any> {
  const sql = `
    INSERT INTO contracts (apartment_id, resident_id, start_date, end_date, base_rent_snapshot, status)
    VALUES ($1, $2, $3, $4, $5, 'ACTIVE')
    RETURNING *
  `;
  const params = [apartmentId, residentId, startDate, endDate, rentSnapshot];

  const result = client
    ? await client.query(sql, params)
    : await query(sql, params);

  return result.rows[0];
}

/**
 * Terminate the active contract for an apartment by changing status to 'EXPIRED'.
 *
 * @param apartmentId Apartment ID
 * @param client Optional PoolClient for transactional queries
 */
export async function terminateActiveContract(
  apartmentId: number,
  client?: PoolClient,
): Promise<void> {
  const sql = `
    UPDATE contracts
    SET status = 'EXPIRED'
    WHERE apartment_id = $1 AND status = 'ACTIVE'
  `;
  const params = [apartmentId];

  if (client) {
    await client.query(sql, params);
  } else {
    await query(sql, params);
  }
}

// ==========================================
// Module 2: UC06-UC09 (Tenancy & Stay Extension)
// ==========================================

/** Dòng contracts kèm thông tin căn hộ (join apartments) cho UC06/UC09. */
export interface ContractWithApartmentRow {
  id: number;
  apartment_id: number;
  resident_id: number;
  start_date: Date;
  end_date: Date;
  base_rent_snapshot: string; // NUMERIC trả về string từ pg
  status: ContractStatus;
  created_at: Date;
  unit_number: string;
  floor: string;
  apartment_status: ApartmentStatus;
}

/**
 * UC06: hợp đồng của cư dân - ưu tiên ACTIVE, không có thì lấy bản mới nhất
 * (để AT1 hiển thị hợp đồng EXPIRED). BR-23: chỉ query theo resident_id.
 */
export async function findLatestContractByResident(
  residentId: number,
): Promise<ContractWithApartmentRow | null> {
  const result = await query<ContractWithApartmentRow>(
    `SELECT c.*, a.unit_number, a.floor, a.status AS apartment_status
     FROM contracts c
     JOIN apartments a ON a.id = c.apartment_id
     WHERE c.resident_id = $1
     ORDER BY (c.status = 'ACTIVE') DESC, c.created_at DESC
     LIMIT 1`,
    [residentId],
  );
  return result.rows[0] ?? null;
}

/** Dòng apartments tối giản cho UC06 AT2 (cư dân có phòng nhưng chưa có hợp đồng). */
export interface ResidentApartmentRow {
  id: number;
  unit_number: string;
  floor: string;
  status: ApartmentStatus;
}

/** UC06 AT2: căn hộ mà cư dân đứng tên (owner_id) khi chưa có hợp đồng nào. */
export async function findApartmentByOwner(
  residentId: number,
): Promise<ResidentApartmentRow | null> {
  const result = await query<ResidentApartmentRow>(
    `SELECT id, unit_number, floor, status
     FROM apartments WHERE owner_id = $1
     ORDER BY id LIMIT 1`,
    [residentId],
  );
  return result.rows[0] ?? null;
}

/** UC09: hợp đồng theo id (kèm căn hộ) để hiển thị màn duyệt. */
export async function findContractById(
  contractId: number,
): Promise<ContractWithApartmentRow | null> {
  const result = await query<ContractWithApartmentRow>(
    `SELECT c.*, a.unit_number, a.floor, a.status AS apartment_status
     FROM contracts c
     JOIN apartments a ON a.id = c.apartment_id
     WHERE c.id = $1`,
    [contractId],
  );
  return result.rows[0] ?? null;
}

/**
 * UC09 (BR-17): dời end_date khi duyệt gia hạn - chạy TRONG transaction.
 * Chỉ áp dụng cho hợp đồng còn ACTIVE (AT3: hợp đồng đã bị kết thúc
 * bởi Manager khác thì trả false để service báo lỗi 409).
 */
export async function extendContractEndDate(
  client: PoolClient,
  contractId: number,
  newEndDate: string,
): Promise<boolean> {
  const result = await client.query(
    `UPDATE contracts SET end_date = $2
     WHERE id = $1 AND status = 'ACTIVE'
     RETURNING id`,
    [contractId, newEndDate],
  );
  return (result.rowCount ?? 0) > 0;
}
