/**
 * DashboardService - Business Logic Layer for UC35 (Dashboard & Statistics Report)
 *
 * Coordinates data retrieval from BillingRepository and TicketRepository
 * to build the dashboard statistics DTO.
 */

import { HttpError } from '@/lib/middleware';
import * as billingRepo from '@/repositories/billing.repository';
import * as ticketRepo from '@/repositories/ticket.repository';

export interface DashboardData {
  total_revenue: number;
  collected_revenue: number;
  unpaid_bills_count: number;
  unresolved_tickets_count: number;
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

  const [revenueStats, unresolvedTicketsCount] = await Promise.all([
    billingRepo.getRevenueStats(monthYear),
    ticketRepo.countActiveUnresolvedTickets(monthYear),
  ]);

  return {
    total_revenue: revenueStats.total_revenue,
    collected_revenue: revenueStats.collected_revenue,
    unpaid_bills_count: revenueStats.unpaid_bills_count,
    unresolved_tickets_count: unresolvedTicketsCount,
  };
}
