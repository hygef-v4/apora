/**
 * DashboardService - Business Logic Layer for UC35 (Dashboard & Statistics Report)
 *
 * Coordinates data retrieval from BillingRepository and TicketRepository
 * to build the dashboard statistics DTO.
 */

import { HttpError } from '@/lib/middleware';
import { query } from '@/lib/db';
import * as billingRepo from '@/repositories/billing.repository';
import * as ticketRepo from '@/repositories/ticket.repository';

export interface RecentActivityItem {
  id: string;
  type: 'TICKET' | 'PAYMENT';
  title: string;
  subtitle: string;
  created_at: string;
}

export interface TicketStatusCounts {
  pending: number;
  processing: number;
  waiting_rating: number;
  closed: number;
}

export interface DashboardData {
  total_revenue: number;
  collected_revenue: number;
  unpaid_bills_count: number;
  unresolved_tickets_count: number;
  ticket_status_counts: TicketStatusCounts;
  recent_activities: RecentActivityItem[];
}

/**
 * Calculates aggregates for dashboard statistics for a given month (BR-02, BR-03, BR-04, BR-05, BR-07, BR-09).
 * Read-Only operation as per BR-02.
 *
 * @param monthYear Month filter in format 'MM/YYYY'
 * @returns Combined dashboard metrics DTO
 */
export async function calculateDashboardStats(monthYear: string): Promise<DashboardData> {
  // Validate month format (MM/YYYY)
  if (!monthYear || !/^\d{2}\/\d{4}$/.test(monthYear)) {
    throw new HttpError(400, 'Định dạng tháng lọc không hợp lệ. Vui lòng nhập đúng định dạng MM/YYYY.');
  }

  const [revenueStats, unresolvedTicketsCount, statusCountsRes, recentTicketsRes, recentPaymentsRes] = await Promise.all([
    billingRepo.getRevenueStats(monthYear),
    ticketRepo.countActiveUnresolvedTickets(monthYear),
    query(
      `SELECT status, COUNT(*)::int AS count 
       FROM repair_tickets 
       WHERE TO_CHAR(created_at, 'MM/YYYY') = $1
       GROUP BY status`,
      [monthYear],
    ),
    query(
      `SELECT rt.id, rt.category, rt.status, rt.created_at, a.unit_number, u.full_name AS resident_name, asg.full_name AS assignee_name
       FROM repair_tickets rt
       JOIN apartments a ON a.id = rt.apartment_id
       JOIN users u ON u.id = rt.resident_id
       LEFT JOIN LATERAL (
         SELECT t.assigned_to FROM tasks t WHERE t.ticket_id = rt.id ORDER BY t.assigned_at DESC LIMIT 1
       ) lt ON TRUE
       LEFT JOIN users asg ON asg.id = lt.assigned_to
       ORDER BY rt.created_at DESC LIMIT 5`,
    ),
    query(
      `SELECT p.id, p.amount, p.paid_at, p.created_at, a.unit_number, u.full_name AS resident_name
       FROM payments p
       JOIN invoices i ON i.id = p.invoice_id
       JOIN apartments a ON a.id = i.apartment_id
       JOIN users u ON u.id = p.resident_id
       ORDER BY p.created_at DESC LIMIT 5`,
    ),
  ]);

  const rawStatusMap: Record<string, number> = {};
  for (const row of statusCountsRes.rows) {
    rawStatusMap[row.status] = row.count;
  }

  const ticketStatusCounts: TicketStatusCounts = {
    pending: rawStatusMap['PENDING'] ?? 0,
    processing: (rawStatusMap['ASSIGNED'] ?? 0) + (rawStatusMap['PROCESSING'] ?? 0),
    waiting_rating: rawStatusMap['RESOLVED'] ?? 0,
    closed: rawStatusMap['CANCELLED'] ?? 0,
  };

  const activities: RecentActivityItem[] = [];

  for (const row of recentTicketsRes.rows) {
    const dateObj = new Date(row.created_at);
    const timeStr = dateObj.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const assigneeStr = row.assignee_name ? `Assigned to Staff: ${row.assignee_name}` : `Reported by ${row.resident_name}`;
    activities.push({
      id: `ticket_${row.id}`,
      type: 'TICKET',
      title: `Ticket #${row.id} assigned — ${assigneeStr}`,
      subtitle: `Room ${row.unit_number} · ${timeStr}`,
      created_at: dateObj.toISOString(),
    });
  }

  for (const row of recentPaymentsRes.rows) {
    const dateObj = new Date(row.created_at);
    const timeStr = dateObj.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    activities.push({
      id: `payment_${row.id}`,
      type: 'PAYMENT',
      title: `Bill payment received — Room ${row.unit_number}`,
      subtitle: `Resident: ${row.resident_name} · ${timeStr}`,
      created_at: dateObj.toISOString(),
    });
  }

  activities.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

  return {
    total_revenue: revenueStats.total_revenue,
    collected_revenue: revenueStats.collected_revenue,
    unpaid_bills_count: revenueStats.unpaid_bills_count,
    unresolved_tickets_count: unresolvedTicketsCount,
    ticket_status_counts: ticketStatusCounts,
    recent_activities: activities.slice(0, 5),
  };
}

