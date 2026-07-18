/**
 * ApartmentRepository - Data Access Layer for apartments table
 *
 * Contains raw SQL queries via pg client. No business logic.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 6 (ApartmentRepository)
 */

import { query } from '@/lib/db';
import { Apartment, ApartmentListItem } from '@/types';

/**
 * Fetch list of apartments with owner info and operational indicators.
 * Supported filters: EMPTY, OCCUPIED, HAS_DEBT.
 * Supported search: unit_number or owner's full name.
 *
 * @param search Search keyword
 * @param filterStatus Status filter (EMPTY, OCCUPIED, HAS_DEBT, or ALL)
 * @returns List of apartments with stats
 */
export async function findApartmentsWithStats(
  search?: string,
  filterStatus?: string,
): Promise<ApartmentListItem[]> {
  let sql = `
    SELECT 
      a.id,
      a.unit_number,
      a.floor,
      a.status,
      a.area_size,
      a.base_rent,
      COALESCE(c.resident_id, a.owner_id) as owner_id,
      u.full_name as owner_name,
      u.phone_number as owner_phone,
      COALESCE(inv_stats.unpaid_count, 0)::int as unpaid_invoice_count,
      COALESCE(tkt_stats.unresolved_count, 0)::int as unresolved_ticket_count
    FROM apartments a
    LEFT JOIN contracts c ON c.apartment_id = a.id AND c.status = 'ACTIVE'
    LEFT JOIN users u ON u.id = COALESCE(c.resident_id, a.owner_id)
    LEFT JOIN LATERAL (
      SELECT COUNT(*)::int as unpaid_count
      FROM invoices
      WHERE apartment_id = a.id AND status = 'UNPAID'
    ) inv_stats ON TRUE
    LEFT JOIN LATERAL (
      SELECT COUNT(*)::int as unresolved_count
      FROM repair_tickets
      WHERE apartment_id = a.id AND status NOT IN ('RESOLVED', 'CANCELLED')
    ) tkt_stats ON TRUE
    WHERE 1=1
  `;

  const params: any[] = [];
  let paramIndex = 1;

  if (search && search.trim() !== '') {
    const searchPattern = `%${search.trim()}%`;
    sql += ` AND (a.unit_number ILIKE $${paramIndex} OR u.full_name ILIKE $${paramIndex})`;
    params.push(searchPattern);
    paramIndex++;
  }

  if (filterStatus) {
    const status = filterStatus.toUpperCase();
    if (status === 'EMPTY' || status === 'OCCUPIED' || status === 'INACTIVE') {
      sql += ` AND a.status = $${paramIndex}`;
      params.push(status);
      paramIndex++;
    } else if (status === 'HAS_DEBT') {
      sql += ` AND COALESCE(inv_stats.unpaid_count, 0) > 0`;
    }
  }

  sql += ` ORDER BY a.unit_number ASC`;

  const result = await query(sql, params);

  return result.rows.map(row => ({
    id: row.id,
    unit_number: row.unit_number,
    floor: row.floor,
    owner_id: row.owner_id,
    status: row.status,
    area_size: parseFloat(row.area_size),
    base_rent: parseFloat(row.base_rent),
    owner_name: row.owner_name,
    owner_phone: row.owner_phone,
    unpaid_invoice_count: row.unpaid_invoice_count,
    unresolved_ticket_count: row.unresolved_ticket_count,
  }));
}

/**
 * Fetch a single apartment by ID.
 *
 * @param id Apartment ID
 * @returns Apartment entity or null
 */
export async function findById(id: number): Promise<Apartment | null> {
  const result = await query('SELECT * FROM apartments WHERE id = $1', [id]);
  if (result.rows.length === 0) return null;
  const row = result.rows[0];
  return {
    id: row.id,
    unit_number: row.unit_number,
    floor: row.floor,
    owner_id: row.owner_id,
    status: row.status,
    area_size: parseFloat(row.area_size),
    base_rent: parseFloat(row.base_rent),
  };
}

/**
 * Fetch a single apartment with owner details.
 *
 * @param id Apartment ID
 * @returns Apartment with owner name/phone or null
 */
export async function findByIdWithOwner(id: number): Promise<any | null> {
  const sql = `
    SELECT 
      a.id,
      a.unit_number,
      a.floor,
      a.status,
      a.area_size,
      a.base_rent,
      COALESCE(c.resident_id, a.owner_id) as owner_id,
      u.full_name as owner_name,
      u.phone_number as owner_phone
    FROM apartments a
    LEFT JOIN contracts c ON c.apartment_id = a.id AND c.status = 'ACTIVE'
    LEFT JOIN users u ON u.id = COALESCE(c.resident_id, a.owner_id)
    WHERE a.id = $1
  `;
  const result = await query(sql, [id]);
  if (result.rows.length === 0) return null;
  const row = result.rows[0];
  return {
    ...row,
    area_size: parseFloat(row.area_size),
    base_rent: parseFloat(row.base_rent),
  };
}

/**
 * Fetch approved roommates of an apartment.
 *
 * @param apartmentId Apartment ID
 * @returns Roommates list
 */
export async function findApprovedRoommates(apartmentId: number): Promise<any[]> {
  const sql = `
    SELECT id, full_name, phone_number, cccd_number, cccd_front_url, cccd_back_url, status, created_at
    FROM roommates
    WHERE apartment_id = $1 AND status = 'APPROVED'
    ORDER BY created_at ASC
  `;
  const result = await query(sql, [apartmentId]);
  return result.rows;
}

/**
 * Fetch recent bills (invoices) linked to an apartment.
 *
 * @param apartmentId Apartment ID
 * @param limit Max number of bills to retrieve
 * @returns Invoices list
 */
export async function findRecentInvoices(apartmentId: number, limit = 5): Promise<any[]> {
  const sql = `
    SELECT id, month_year, total_amount, status, created_at
    FROM invoices
    WHERE apartment_id = $1
    ORDER BY created_at DESC
    LIMIT $2
  `;
  const result = await query(sql, [apartmentId, limit]);
  return result.rows.map(row => ({
    ...row,
    total_amount: parseFloat(row.total_amount),
  }));
}

/**
 * Fetch recent repair tickets for an apartment.
 *
 * @param apartmentId Apartment ID
 * @param limit Max number of tickets to retrieve
 * @returns Tickets list
 */
export async function findRecentTickets(apartmentId: number, limit = 5): Promise<any[]> {
  const sql = `
    SELECT id, category, description, status, created_at
    FROM repair_tickets
    WHERE apartment_id = $1
    ORDER BY created_at DESC
    LIMIT $2
  `;
  const result = await query(sql, [apartmentId, limit]);
  return result.rows;
}

/**
 * Insert a new apartment record. Default status is EMPTY.
 *
 * @param floor Floor string
 * @param unitNumber Unit number/Room number
 * @param areaSize Area size in sqm
 * @param baseRent Base rent in currency
 * @returns Created Apartment entity
 */
export async function createApartment(
  floor: string,
  unitNumber: string,
  areaSize: number,
  baseRent: number,
): Promise<Apartment> {
  const sql = `
    INSERT INTO apartments (unit_number, floor, status, area_size, base_rent)
    VALUES ($1, $2, 'EMPTY', $3, $4)
    RETURNING *
  `;
  const result = await query(sql, [unitNumber, floor, areaSize, baseRent]);
  const row = result.rows[0];
  return {
    id: row.id,
    unit_number: row.unit_number,
    floor: row.floor,
    owner_id: row.owner_id,
    status: row.status,
    area_size: parseFloat(row.area_size),
    base_rent: parseFloat(row.base_rent),
  };
}

/**
 * Update physical information of an apartment.
 * Leaves status, owner_id, and existing contracts untouched.
 *
 * @param id Apartment ID
 * @param floor Floor string
 * @param unitNumber Unit number/Room number
 * @param areaSize Area size in sqm
 * @param baseRent Base rent in currency
 * @returns Updated Apartment entity
 */
export async function updateApartment(
  id: number,
  floor: string,
  unitNumber: string,
  areaSize: number,
  baseRent: number,
): Promise<Apartment> {
  const sql = `
    UPDATE apartments
    SET floor = $2, unit_number = $3, area_size = $4, base_rent = $5
    WHERE id = $1
    RETURNING *
  `;
  const result = await query(sql, [id, floor, unitNumber, areaSize, baseRent]);
  const row = result.rows[0];
  return {
    id: row.id,
    unit_number: row.unit_number,
    floor: row.floor,
    owner_id: row.owner_id,
    status: row.status,
    area_size: parseFloat(row.area_size),
    base_rent: parseFloat(row.base_rent),
  };
}

/**
 * Check if a unit number already exists in the system.
 * Useful for validating room number uniqueness (BR-63).
 *
 * @param unitNumber Unit number/Room number to check
 * @param excludeId Optional ID of apartment to exclude (for update checks)
 * @returns boolean
 */
export async function checkUnitNumberExists(unitNumber: string, excludeId?: number): Promise<boolean> {
  let sql = 'SELECT id FROM apartments WHERE unit_number = $1';
  const params: any[] = [unitNumber];

  if (excludeId !== undefined) {
    sql += ' AND id != $2';
    params.push(excludeId);
  }

  const result = await query(sql, params);
  return result.rows.length > 0;
}
