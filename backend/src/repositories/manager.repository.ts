/**
 * ManagerRepository - Data Access Layer for Module 9: Manager Management
 *
 * Operates on the `users` table (role MANAGER) and `audit_logs` table
 * for management history retrieval. Structurally mirrors StaffRepository
 * (Module 8) but scoped to the MANAGER role.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 9 (ManagerRepository)
 * @see schema.sql - tables: users, audit_logs
 */

import { query } from '@/lib/db';
import { User, UserStatus } from '@/types';

/** SQL condition to identify Manager accounts in the users table. */
const MANAGER_ROLE_SQL = `'MANAGER'`;

/**
 * Retrieves a paginated list of Manager accounts with optional search and status filter.
 *
 * @param statusFilter - Optional status filter: 'ACTIVE' | 'INACTIVE'
 * @param search - Optional keyword to search by full_name or phone_number (ILIKE)
 * @returns Array of User rows matching the criteria, sorted by full_name ASC
 */
export async function findManagersByRole(
  statusFilter?: UserStatus,
  search?: string,
): Promise<User[]> {
  const conditions: string[] = [`${MANAGER_ROLE_SQL} = ANY(u.roles)`];
  const params: unknown[] = [];

  if (statusFilter) {
    params.push(statusFilter);
    conditions.push(`u.status = $${params.length}`);
  }
  if (search?.trim()) {
    // Escape LIKE wildcard characters so user-typed % / _ are treated as literals
    const escaped = search.trim().replace(/[\\%_]/g, '\\$&');
    params.push(`%${escaped}%`);
    conditions.push(
      `(u.full_name ILIKE $${params.length} OR u.phone_number ILIKE $${params.length})`,
    );
  }

  const result = await query(
    `SELECT u.*
     FROM users u
     WHERE ${conditions.join(' AND ')}
     ORDER BY u.full_name ASC`,
    params,
  );
  return result.rows;
}

/**
 * Computes aggregate statistics for Manager accounts (UC41 - Summary Cards).
 *
 * @returns Object with total, active, and inactive counts
 */
export async function getManagerStats(): Promise<{
  total: number;
  active: number;
  inactive: number;
}> {
  const result = await query(
    `SELECT
       COUNT(*)::int                                        AS total,
       COUNT(*) FILTER (WHERE u.status = 'ACTIVE')::int    AS active,
       COUNT(*) FILTER (WHERE u.status = 'INACTIVE')::int  AS inactive
     FROM users u
     WHERE ${MANAGER_ROLE_SQL} = ANY(u.roles)`,
  );
  const row = result.rows[0];
  return {
    total: row.total,
    active: row.active,
    inactive: row.inactive,
  };
}

/**
 * Finds a single Manager account by ID. Returns null if not found
 * or if the user does not hold the MANAGER role.
 *
 * @param id - The user ID to look up
 * @returns The User record or null
 */
export async function findManagerById(id: number): Promise<User | null> {
  const result = await query(
    `SELECT * FROM users WHERE id = $1 AND ${MANAGER_ROLE_SQL} = ANY(roles)`,
    [id],
  );
  return result.rows[0] ?? null;
}

/**
 * Retrieves the management history for a specific Manager (UC42 - Management History Section).
 * Queries `audit_logs` where the Manager is the actor, joined with `users`
 * to resolve target user names.
 *
 * @param managerId - The actor_id (Manager) to query history for
 * @param limit - Maximum number of history items to return (default 20)
 * @returns Array of history items with action, target user name, reason, and timestamp
 */
export async function findManagementHistory(
  managerId: number,
  limit = 20,
): Promise<
  {
    id: number;
    action: string;
    target_user_name: string | null;
    reason: string | null;
    created_at: Date;
  }[]
> {
  const result = await query(
    `SELECT
       al.id,
       al.action,
       tu.full_name AS target_user_name,
       al.reason,
       al.created_at
     FROM audit_logs al
     LEFT JOIN users tu ON tu.id = al.target_user_id
     WHERE al.actor_id = $1
     ORDER BY al.created_at DESC
     LIMIT $2`,
    [managerId, limit],
  );
  return result.rows;
}
