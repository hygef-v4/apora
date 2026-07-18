/**
 * Unit test BillingService (Module 3: UC13-UC17) - mock repository, không cần DB.
 * Tập trung các bất biến bảo mật/nghiệp vụ dễ hồi quy:
 * - BR-23/31/53: cô lập dữ liệu khi thanh toán/giả lập (chỉ chủ hóa đơn).
 * - BR-32: chỉ webhook mới set PAID; chế độ mock/giả lập bị khóa trên production.
 * - Webhook idempotent: nhận lại cùng 1 giao dịch đã SUCCESS không xử lý lại.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest';

import { HttpError } from '@/lib/middleware';
import * as billingRepo from '@/repositories/billing.repository';
import * as billingService from '@/services/billing.service';

vi.mock('@/repositories/billing.repository');
vi.mock('@/repositories/pricing.repository');

// withTransaction chỉ cần gọi callback với 1 client giả (repo đã được mock hết).
vi.mock('@/lib/db', () => ({
  withTransaction: (fn: (client: unknown) => unknown) => fn({ query: vi.fn() }),
  query: vi.fn(),
}));

// Không khởi tạo PayOS SDK thật khi import service.
vi.mock('@payos/node', () => ({
  PayOS: class {
    paymentRequests = { create: vi.fn() };
    webhooks = { verify: vi.fn() };
  },
}));

function makeInvoice(overrides: Record<string, unknown> = {}) {
  return {
    id: 10,
    resident_id: 1,
    unit_number: 'P.101',
    status: 'UNPAID',
    total_amount: 30000,
    month_year: '07/2026',
    ...overrides,
  } as any;
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.unstubAllEnvs();
  // Mặc định test chạy ngoài production -> cho phép chế độ giả lập.
  vi.stubEnv('NODE_ENV', 'test');
});

describe('simulateSuccessPayment (BR-32/BR-33)', () => {
  it('từ chối khi hóa đơn không thuộc về người gọi (cô lập dữ liệu)', async () => {
    vi.mocked(billingRepo.findInvoiceById).mockResolvedValue(
      makeInvoice({ resident_id: 999 }),
    );

    await expect(billingService.simulateSuccessPayment(10, 1)).rejects.toMatchObject({
      status: 403,
    });
    // Không được đụng vào trạng thái hóa đơn của người khác
    expect(billingRepo.updateInvoiceStatus).not.toHaveBeenCalled();
  });

  it('bị khóa trên môi trường production (không có đường tắt set PAID)', async () => {
    vi.stubEnv('NODE_ENV', 'production');

    await expect(billingService.simulateSuccessPayment(10, 1)).rejects.toBeInstanceOf(HttpError);
    // Chặn ngay từ đầu, không truy vấn hóa đơn
    expect(billingRepo.findInvoiceById).not.toHaveBeenCalled();
  });

  it('từ chối khi hóa đơn đã thanh toán', async () => {
    vi.mocked(billingRepo.findInvoiceById).mockResolvedValue(
      makeInvoice({ status: 'PAID' }),
    );

    await expect(billingService.simulateSuccessPayment(10, 1)).rejects.toMatchObject({
      status: 400,
    });
  });

  it('chủ hóa đơn giả lập thành công -> cập nhật giao dịch PENDING và Invoice sang PAID', async () => {
    vi.mocked(billingRepo.findInvoiceById).mockResolvedValue(makeInvoice());
    vi.mocked(billingRepo.findLatestPendingPaymentByInvoiceId).mockResolvedValue({
      payos_order_id: 'MOCK_ORDER_10',
    } as any);
    vi.mocked(billingRepo.updatePaymentStatus).mockResolvedValue({
      status: 'SUCCESS',
    } as any);
    vi.mocked(billingRepo.updateInvoiceStatus).mockResolvedValue(makeInvoice({ status: 'PAID' }));

    const payment = await billingService.simulateSuccessPayment(10, 1);

    expect(payment.status).toBe('SUCCESS');
    expect(billingRepo.updatePaymentStatus).toHaveBeenCalledWith(
      'MOCK_ORDER_10',
      'SUCCESS',
      expect.any(Date),
      expect.any(String),
      expect.anything(),
    );
    expect(billingRepo.updateInvoiceStatus).toHaveBeenCalledWith(10, 'PAID', expect.anything());
  });
});

describe('processPaymentCallback (BR-32)', () => {
  it('không xử lý lại giao dịch đã SUCCESS (idempotent)', async () => {
    vi.mocked(billingRepo.findPaymentByOrderId).mockResolvedValue({
      invoice_id: 10,
      status: 'SUCCESS',
    } as any);

    await billingService.processPaymentCallback({ orderCode: 'MOCK_ORDER_10', success: true });

    expect(billingRepo.updatePaymentStatus).not.toHaveBeenCalled();
    expect(billingRepo.updateInvoiceStatus).not.toHaveBeenCalled();
  });

  it('từ chối webhook mock không chữ ký trên production', async () => {
    vi.stubEnv('NODE_ENV', 'production');

    await expect(
      billingService.processPaymentCallback({ orderCode: 'X', success: true }),
    ).rejects.toBeInstanceOf(HttpError);
    expect(billingRepo.findPaymentByOrderId).not.toHaveBeenCalled();
  });

  it('thanh toán thành công -> cập nhật Payment SUCCESS + Invoice PAID', async () => {
    vi.mocked(billingRepo.findPaymentByOrderId).mockResolvedValue({
      invoice_id: 10,
      status: 'PENDING',
    } as any);

    await billingService.processPaymentCallback({ orderCode: 'MOCK_ORDER_10', success: true });

    expect(billingRepo.updatePaymentStatus).toHaveBeenCalledWith(
      'MOCK_ORDER_10',
      'SUCCESS',
      expect.any(Date),
      expect.any(String),
      expect.anything(),
    );
    expect(billingRepo.updateInvoiceStatus).toHaveBeenCalledWith(10, 'PAID', expect.anything());
  });
});

describe('initializePayment (BR-23/31/53)', () => {
  it('từ chối khi hóa đơn không thuộc về người gọi', async () => {
    vi.mocked(billingRepo.findInvoiceById).mockResolvedValue(
      makeInvoice({ resident_id: 999 }),
    );

    await expect(billingService.initializePayment(10, 1)).rejects.toMatchObject({ status: 403 });
  });

  it('từ chối khi hóa đơn đã thanh toán', async () => {
    vi.mocked(billingRepo.findInvoiceById).mockResolvedValue(
      makeInvoice({ status: 'PAID' }),
    );

    await expect(billingService.initializePayment(10, 1)).rejects.toMatchObject({ status: 400 });
  });
});
