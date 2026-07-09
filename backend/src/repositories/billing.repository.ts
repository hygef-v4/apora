import { query } from '@/lib/db';
import { Invoice, Payment } from '@/types';

/** Find the active contract for an apartment. */
export async function findActiveContractByApartmentId(apartmentId: number): Promise<any | null> {
  const res = await query(
    `SELECT * FROM contracts
     WHERE apartment_id = $1 AND status = 'ACTIVE'
     LIMIT 1`,
    [apartmentId],
  );
  return res.rows[0] || null;
}

/** Find the last invoice generated for a contract (to get final readings). */
export async function findLastInvoice(contractId: number): Promise<Invoice | null> {
  const res = await query(
    `SELECT * FROM invoices
     WHERE contract_id = $1
     ORDER BY created_at DESC
     LIMIT 1`,
    [contractId],
  );
  return res.rows[0] || null;
}

/** Save a newly generated monthly bill invoice. */
export async function saveInvoice(invoice: Omit<Invoice, 'id' | 'created_at'>): Promise<Invoice> {
  const res = await query(
    `INSERT INTO invoices (
      contract_id, apartment_id, month_year,
      prev_electricity_index, curr_electricity_index, electricity_consumption,
      prev_water_index, curr_water_index, water_consumption,
      room_rent_snapshot, mgmt_fee_snapshot, extra_fee, extra_fee_description,
      total_amount, status
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
    RETURNING *`,
    [
      invoice.contract_id,
      invoice.apartment_id,
      invoice.month_year,
      invoice.prev_electricity_index,
      invoice.curr_electricity_index,
      invoice.electricity_consumption,
      invoice.prev_water_index,
      invoice.curr_water_index,
      invoice.water_consumption,
      invoice.room_rent_snapshot,
      invoice.mgmt_fee_snapshot,
      invoice.extra_fee,
      invoice.extra_fee_description,
      invoice.total_amount,
      invoice.status,
    ],
  );
  return res.rows[0];
}

/** Fetch invoices belonging to a specific resident. (BR-31 data isolation) */
export async function findInvoicesByResidentId(residentId: number): Promise<Invoice[]> {
  const res = await query(
    `SELECT i.*, a.unit_number
     FROM invoices i
     JOIN contracts c ON i.contract_id = c.id
     JOIN apartments a ON i.apartment_id = a.id
     WHERE c.resident_id = $1
     ORDER BY i.created_at DESC`,
    [residentId],
  );
  return res.rows;
}

/** Fetch a specific invoice by ID. */
export async function findInvoiceById(id: number): Promise<(Invoice & { resident_id: number; unit_number: string }) | null> {
  const res = await query(
    `SELECT i.*, c.resident_id, a.unit_number
     FROM invoices i
     JOIN contracts c ON i.contract_id = c.id
     JOIN apartments a ON i.apartment_id = a.id
     WHERE i.id = $1`,
    [id],
  );
  return res.rows[0] || null;
}

/** Update the payment status of an invoice. */
export async function updateInvoiceStatus(id: number, status: 'UNPAID' | 'PAID'): Promise<Invoice> {
  const res = await query(
    `UPDATE invoices SET status = $1 WHERE id = $2 RETURNING *`,
    [status, id],
  );
  return res.rows[0];
}

/** Save a new payment transaction log. */
export async function savePaymentTransaction(payment: Omit<Payment, 'id' | 'created_at'>): Promise<Payment> {
  const res = await query(
    `INSERT INTO payments (
      invoice_id, resident_id, payos_order_id, transaction_code,
      amount, payment_method, status, paid_at
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
    RETURNING *`,
    [
      payment.invoice_id,
      payment.resident_id,
      payment.payos_order_id,
      payment.transaction_code,
      payment.amount,
      payment.payment_method,
      payment.status,
      payment.paid_at,
    ],
  );
  return res.rows[0];
}

/** Find payment log by PayOS order ID. */
export async function findPaymentByOrderId(orderId: string): Promise<Payment | null> {
  const res = await query(
    `SELECT * FROM payments WHERE payos_order_id = $1`,
    [orderId],
  );
  return res.rows[0] || null;
}

/** Update payment transaction log status. */
export async function updatePaymentStatus(
  orderId: string,
  status: 'SUCCESS' | 'FAILED' | 'CANCELLED',
  paidAt: Date | null,
  transactionCode: string | null,
): Promise<Payment> {
  const res = await query(
    `UPDATE payments
     SET status = $2, paid_at = $3, transaction_code = $4
     WHERE payos_order_id = $1
     RETURNING *`,
    [orderId, status, paidAt, transactionCode],
  );
  return res.rows[0];
}

/** Retrieve transaction list filterable by user/role. */
export async function findTransactions(userId: number, role: string): Promise<any[]> {
  const isManagement = role === 'LANDLORD' || role === 'MANAGER';
  if (isManagement) {
    const res = await query(
      `SELECT p.*, a.unit_number, i.month_year, u.full_name as resident_name
       FROM payments p
       JOIN invoices i ON p.invoice_id = i.id
       JOIN apartments a ON i.apartment_id = a.id
       JOIN users u ON p.resident_id = u.id
       ORDER BY p.created_at DESC`,
    );
    return res.rows;
  } else {
    const res = await query(
      `SELECT p.*, a.unit_number, i.month_year
       FROM payments p
       JOIN invoices i ON p.invoice_id = i.id
       JOIN apartments a ON i.apartment_id = a.id
       WHERE p.resident_id = $1
       ORDER BY p.created_at DESC`,
      [userId],
    );
    return res.rows;
  }
}

/** Find a payment transaction by ID. */
export async function findPaymentById(id: number): Promise<Payment | null> {
  const res = await query(
    `SELECT p.*, a.unit_number, i.month_year
     FROM payments p
     JOIN invoices i ON p.invoice_id = i.id
     JOIN apartments a ON i.apartment_id = a.id
     WHERE p.id = $1`,
    [id],
  );
  return res.rows[0] || null;
}

/** Get all active contracts with apartment unit numbers. */
export async function findActiveContracts(): Promise<any[]> {
  const res = await query(
    `SELECT c.id as contract_id, c.apartment_id, a.unit_number, c.base_rent_snapshot, u.full_name as resident_name
     FROM contracts c
     JOIN apartments a ON c.apartment_id = a.id
     JOIN users u ON c.resident_id = u.id
     WHERE c.status = 'ACTIVE'
     ORDER BY a.unit_number ASC`
  );
  return res.rows;
}

/** Get all invoices in the building (for managers/landlords). */
export async function findAllInvoices(): Promise<any[]> {
  const res = await query(
    `SELECT i.*, a.unit_number
     FROM invoices i
     JOIN apartments a ON i.apartment_id = a.id
     ORDER BY i.created_at DESC`
  );
  return res.rows;
}
