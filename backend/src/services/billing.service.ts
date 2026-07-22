import { PayOS } from '@payos/node';
import * as billingRepo from '@/repositories/billing.repository';
import * as pricingRepo from '@/repositories/pricing.repository';
import { HttpError } from '@/lib/middleware';
import { withTransaction } from '@/lib/db';
import { Invoice, Payment } from '@/types';

// Khởi tạo SDK PayOS với các biến môi trường
const payos = new PayOS({
  clientId: process.env.PAYOS_CLIENT_ID || 'dummy_client_id',
  apiKey: process.env.PAYOS_API_KEY || 'dummy_api_key',
  checksumKey: process.env.PAYOS_CHECKSUM_KEY || 'dummy_checksum_key',
});

/** Có đang chạy môi trường production không (khóa mọi chế độ giả lập thanh toán). */
function isProduction(): boolean {
  return process.env.NODE_ENV === 'production';
}

/**
 * BR-32/BR-33: chế độ giả lập thanh toán (mock/simulate) chỉ được phép NGOÀI
 * production. Trên production bắt buộc dùng webhook PayOS thật có chữ ký, không
 * bao giờ cho set PAID bằng đường tắt.
 */
function assertSandboxAllowed(): void {
  if (isProduction()) {
    throw new HttpError(403, 'Chức năng giả lập thanh toán không khả dụng trên môi trường thật.');
  }
}

/**
  * UC13: Nhập chỉ số điện nước & tự động sinh hóa đơn hàng tháng cho căn hộ.
  */
export async function createMonthlyBill(
  apartmentId: number,
  monthYear: string,
  currElectricityIndex: number,
  currWaterIndex: number,
  extraFee: number,
  extraFeeDescription: string | null,
): Promise<Invoice> {
  // 1. Kiểm tra căn hộ có hợp đồng đang hoạt động không
  const contract = await billingRepo.findActiveContractByApartmentId(apartmentId);
  if (!contract) {
    throw new HttpError(404, 'Căn hộ hiện không có hợp đồng thuê hoạt động nào để sinh hóa đơn.');
  }

  // 2. Tìm hóa đơn gần nhất của hợp đồng để đối chiếu chỉ số cũ
  const lastInvoice = await billingRepo.findLastInvoice(contract.id);
  const prevElectricityIndex = lastInvoice ? lastInvoice.curr_electricity_index : 0;
  const prevWaterIndex = lastInvoice ? lastInvoice.curr_water_index : 0;

  // 3. Nghiệp vụ BR-25: Chỉ số mới phải lớn hơn hoặc bằng chỉ số cũ
  if (currElectricityIndex < prevElectricityIndex) {
    throw new HttpError(400, `Chỉ số điện mới (${currElectricityIndex} kWh) không được nhỏ hơn chỉ số điện cũ (${prevElectricityIndex} kWh).`);
  }
  if (currWaterIndex < prevWaterIndex) {
    throw new HttpError(400, `Chỉ số nước mới (${currWaterIndex} m³) không được nhỏ hơn chỉ số nước cũ (${prevWaterIndex} m³).`);
  }

  // 4. Tính toán lượng tiêu thụ
  const electricityConsumption = currElectricityIndex - prevElectricityIndex;
  const waterConsumption = currWaterIndex - prevWaterIndex;

  // 5. Tính toán các khoản phí lấy đơn giá động từ CSDL
  const activePricing = await pricingRepo.findActivePricing();
  if (!activePricing) {
    throw new HttpError(404, 'Không tìm thấy đơn giá điện nước hoạt động trong hệ thống. Vui lòng thiết lập đơn giá.');
  }
  const roomRentSnapshot = Number(contract.base_rent_snapshot);
  const mgmtFeeSnapshot = activePricing.mgmt_fee;
  const electricityCost = electricityConsumption * activePricing.electricity_rate;
  const waterCost = waterConsumption * activePricing.water_rate;
  const totalAmount = roomRentSnapshot + mgmtFeeSnapshot + electricityCost + waterCost + extraFee;

  // 6. Lưu hóa đơn mới (Nếu trùng lặp apartment_id + month_year -> ném lỗi UNIQUE constraint 409 ở middleware)
  return billingRepo.saveInvoice({
    contract_id: contract.id,
    apartment_id: apartmentId,
    month_year: monthYear,
    prev_electricity_index: prevElectricityIndex,
    curr_electricity_index: currElectricityIndex,
    electricity_consumption: electricityConsumption,
    prev_water_index: prevWaterIndex,
    curr_water_index: currWaterIndex,
    water_consumption: waterConsumption,
    room_rent_snapshot: roomRentSnapshot,
    mgmt_fee_snapshot: mgmtFeeSnapshot,
    electricity_rate_snapshot: activePricing.electricity_rate,
    water_rate_snapshot: activePricing.water_rate,
    extra_fee: extraFee,
    extra_fee_description: extraFeeDescription || null,
    total_amount: totalAmount,
    status: 'UNPAID',
  });
}

export async function getResidentInvoices(userId: number, roles: string[] = []): Promise<Invoice[]> {
  const isManagement = roles.includes('LANDLORD') || roles.includes('MANAGER');
  if (isManagement) {
    return billingRepo.findAllInvoices();
  }
  return billingRepo.findInvoicesByResidentId(userId);
}

/**
 * UC16: Khởi tạo thanh toán hóa đơn trực tuyến qua PayOS VietQR.
 */
export async function initializePayment(invoiceId: number, userId: number): Promise<string> {
  const invoice = await billingRepo.findInvoiceById(invoiceId);
  if (!invoice) {
    throw new HttpError(404, 'Không tìm thấy thông tin hóa đơn.');
  }

  // BR-23/BR-31/BR-53: Đảm bảo cô lập dữ liệu. Chỉ cư dân sở hữu hóa đơn mới được thanh toán
  if (invoice.resident_id !== userId) {
    throw new HttpError(403, 'Bạn không có quyền thanh toán cho hóa đơn này.');
  }

  if (invoice.status === 'PAID') {
    throw new HttpError(400, 'Hóa đơn này đã được thanh toán rồi.');
  }

  // Tạo orderCode ngẫu nhiên duy nhất (số nguyên) cho PayOS
  const orderCode = Number(invoiceId.toString() + (Date.now() % 100000).toString());

  // Kiểm tra cấu hình PayOS xem có hợp lệ để chạy chế độ thật hay không
  const isPayosConfigured =
    process.env.PAYOS_CLIENT_ID &&
    process.env.PAYOS_CLIENT_ID !== 'your_client_id' &&
    process.env.PAYOS_API_KEY &&
    process.env.PAYOS_API_KEY !== 'your_api_key';

  if (isPayosConfigured) {
    try {
      const paymentLinkData = {
        orderCode: orderCode,
        amount: Math.round(Number(invoice.total_amount)),
        description: `APORA BILL ${invoice.month_year}`,
        // Success và Cancel URL trỏ về màn API trung gian của NextJS
        returnUrl: `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/api/payments/payos/success?invoiceId=${invoiceId}`,
        cancelUrl: `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/api/payments/payos/cancel?invoiceId=${invoiceId}`,
      };

      // 1. Lưu log giao dịch thanh toán tạm thời ở trạng thái PENDING
      await billingRepo.savePaymentTransaction({
        invoice_id: invoiceId,
        resident_id: userId,
        payos_order_id: orderCode.toString(),
        transaction_code: null,
        amount: Number(invoice.total_amount),
        payment_method: 'VietQR / PayOS',
        status: 'PENDING',
        paid_at: null,
      });

      // 2. Gọi API PayOS sinh link thanh toán với timeout 4s
      const createPromise = payos.paymentRequests.create(paymentLinkData);
      const timeoutPromise = new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('PayOS gateway response timeout')), 4000)
      );
      const response = await Promise.race([createPromise, timeoutPromise]);
      return response.checkoutUrl;
    } catch (err) {
      console.error('[PayOS] Thao tác tạo link thanh toán thất bại:', err);
      throw new HttpError(500, 'Không thể khởi tạo cổng thanh toán PayOS. Vui lòng liên hệ hỗ trợ.');
    }
  }

  // Chế độ GIẢ LẬP (MOCK SANDBOX) - Chạy khi chưa điền API Keys.
  // BR-33: không cho phép chạy trên production (tránh "thanh toán" mà không qua PayOS thật).
  assertSandboxAllowed();
  const mockOrderId = `MOCK_ORDER_${orderCode}`;
  await billingRepo.savePaymentTransaction({
    invoice_id: invoiceId,
    resident_id: userId,
    payos_order_id: mockOrderId,
    transaction_code: null,
    amount: Number(invoice.total_amount),
    payment_method: 'VietQR / PayOS',
    status: 'PENDING',
    paid_at: null,
  });

  // Link mock sẽ được client di động nhận biết để gọi API giả lập thành công
  return `https://pay.payos.vn/web/checkout/${mockOrderId}?amount=${invoice.total_amount}&invoiceId=${invoiceId}`;
}

/**
 * Webhook callback nhận kết quả thanh toán từ cổng PayOS.
 */
export async function processPaymentCallback(body: any): Promise<void> {
  const isPayosConfigured =
    process.env.PAYOS_CHECKSUM_KEY &&
    process.env.PAYOS_CHECKSUM_KEY !== 'your_checksum_key';

  let orderCode: string;
  let success = false;
  let transactionCode = '';
  let paidAt = new Date();

  if (isPayosConfigured) {
    try {
      // Xác thực chữ ký webhook thật từ dữ liệu PayOS truyền sang
      const verifiedData = await payos.webhooks.verify(body);
      orderCode = verifiedData.orderCode.toString();
      success = verifiedData.desc === 'success';
      transactionCode = verifiedData.reference || '';
      paidAt = verifiedData.transactionDateTime ? new Date(verifiedData.transactionDateTime) : new Date();
    } catch (err) {
      console.error('[Webhook] Xác thực chữ ký Webhook từ PayOS lỗi:', err);
      throw new HttpError(400, 'Xác thực chữ ký Webhook từ PayOS thất bại.');
    }
  } else {
    // Chế độ Mock (không có chữ ký) - BR-32: tuyệt đối không chấp nhận trên
    // production để tránh bị giả mạo webhook đánh dấu hóa đơn đã thanh toán.
    if (isProduction()) {
      throw new HttpError(400, 'Webhook thanh toán không hợp lệ.');
    }
    orderCode = body.orderCode || '';
    success = body.success === true || body.desc === 'success';
    transactionCode = body.reference || `FT_${Date.now()}`;
    paidAt = new Date();
  }

  const payment = await billingRepo.findPaymentByOrderId(orderCode);
  if (!payment) {
    throw new HttpError(404, 'Không tìm thấy bản ghi lịch sử thanh toán tương ứng.');
  }

  if (payment.status === 'SUCCESS') {
    return; // Đã xử lý thành công rồi, không làm lại
  }

  if (success) {
    // Cập nhật Payment -> SUCCESS và Invoice -> PAID trong CÙNG 1 transaction
    // để không rơi vào trạng thái lệch (payment SUCCESS nhưng invoice vẫn UNPAID).
    await withTransaction(async (client) => {
      await billingRepo.updatePaymentStatus(orderCode, 'SUCCESS', paidAt, transactionCode, client);
      await billingRepo.updateInvoiceStatus(payment.invoice_id, 'PAID', client);
    });
    console.log(`[Webhook] Hóa đơn ID ${payment.invoice_id} đã thanh toán thành công thông qua webhook.`);
  } else {
    // Ghi nhận thanh toán thất bại/bị hủy
    await billingRepo.updatePaymentStatus(orderCode, 'CANCELLED', null, null);
  }
}

/**
 * API dành riêng cho Sandbox để giả lập thanh toán thành công (dành cho app mobile test).
 *
 * - BR-33: chỉ hoạt động ngoài production (assertSandboxAllowed).
 * - BR-23/31/53: cư dân chỉ được giả lập thanh toán hóa đơn của CHÍNH MÌNH,
 *   đối chiếu invoice.resident_id với userId từ JWT (chống trả tiền hóa đơn người khác).
 *
 * @param invoiceId ID hóa đơn cần giả lập thanh toán
 * @param userId    ID người dùng gọi API (lấy từ JWT) - để kiểm tra sở hữu
 */
export async function simulateSuccessPayment(invoiceId: number, userId: number): Promise<Payment> {
  assertSandboxAllowed();

  const invoice = await billingRepo.findInvoiceById(invoiceId);
  if (!invoice) {
    throw new HttpError(404, 'Không tìm thấy hóa đơn cần giả lập.');
  }

  // Cô lập dữ liệu: chỉ chủ hóa đơn mới được thanh toán (kể cả ở chế độ giả lập)
  if (invoice.resident_id !== userId) {
    throw new HttpError(403, 'Bạn không có quyền thanh toán cho hóa đơn này.');
  }

  if (invoice.status === 'PAID') {
    throw new HttpError(400, 'Hóa đơn đã được thanh toán rồi.');
  }

  // Tìm giao dịch PENDING gần nhất của hóa đơn này để cập nhật
  const pendingPayment = await billingRepo.findLatestPendingPaymentByInvoiceId(invoiceId);

  // Cập nhật/tạo Payment SUCCESS và chuyển Invoice -> PAID trong cùng 1 transaction
  return withTransaction(async (client) => {
    let payment: Payment;
    if (pendingPayment) {
      payment = await billingRepo.updatePaymentStatus(
        pendingPayment.payos_order_id,
        'SUCCESS',
        new Date(),
        `FT_SUCCESS_${invoiceId}`,
        client,
      );
    } else {
      const orderCode = `MOCK_ORDER_${invoiceId}${Date.now() % 1000}`;
      payment = await billingRepo.savePaymentTransaction(
        {
          invoice_id: invoiceId,
          resident_id: invoice.resident_id,
          payos_order_id: orderCode,
          transaction_code: `FT_SUCCESS_${invoiceId}`,
          amount: Number(invoice.total_amount),
          payment_method: 'VietQR / PayOS',
          status: 'SUCCESS',
          paid_at: new Date(),
        },
        client,
      );
    }

    await billingRepo.updateInvoiceStatus(invoiceId, 'PAID', client);
    return payment;
  });
}

/**
 * UC14: Xem lịch sử giao dịch.
 */
export async function getTransactionHistory(userId: number, role: string): Promise<any[]> {
  return billingRepo.findTransactions(userId, role);
}

/**
 * Xem chi tiết biên lai (UC17).
 */
export async function getTransactionReceipt(paymentId: number, userId: number): Promise<Payment> {
  const payment = await billingRepo.findPaymentById(paymentId);
  if (!payment) {
    throw new HttpError(404, 'Không tìm thấy biên lai thanh toán.');
  }
  // data isolation
  if (payment.resident_id !== userId) {
    throw new HttpError(403, 'Bạn không có quyền truy cập biên lai này.');
  }
  return payment;
}

/** Get all active contracts for manager/landlord. */
export async function getActiveContracts(): Promise<any[]> {
  return billingRepo.findActiveContracts();
}

/** Get currently active pricing settings. */
export async function getActivePricing(): Promise<any> {
  const pricing = await pricingRepo.findActivePricing();
  if (!pricing) {
    throw new HttpError(404, 'Không tìm thấy đơn giá điện nước trong hệ thống.');
  }
  return pricing;
}

/** Update pricing settings. */
export async function updatePricingSettings(
  userId: number,
  electricityRate: number,
  waterRate: number,
  mgmtFee: number
): Promise<any> {
  return pricingRepo.insertPricingSetting(electricityRate, waterRate, mgmtFee, userId);
}
