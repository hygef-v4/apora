/**
 * ContractRepository - Data Access Layer for contracts table
 *
 * Handles raw SQL queries for tenancy contracts. Supports transactional pg PoolClient.
 */

import { query } from '@/lib/db';
import { PoolClient } from 'pg';

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
