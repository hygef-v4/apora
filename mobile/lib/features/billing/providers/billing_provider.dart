import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
import '../models/payment.dart';

class BillingState {
  final List<Invoice> invoices;
  final List<Payment> payments;
  final bool isLoading;
  final String? errorMessage;
  final String? activePaymentUrl;

  BillingState({
    required this.invoices,
    required this.payments,
    this.isLoading = false,
    this.errorMessage,
    this.activePaymentUrl,
  });

  BillingState copyWith({
    List<Invoice>? invoices,
    List<Payment>? payments,
    bool? isLoading,
    String? errorMessage,
    String? activePaymentUrl,
  }) {
    return BillingState(
      invoices: invoices ?? this.invoices,
      payments: payments ?? this.payments,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activePaymentUrl: activePaymentUrl ?? this.activePaymentUrl,
    );
  }
}

class BillingNotifier extends Notifier<BillingState> {
  @override
  BillingState build() {
    // Khởi tạo một số hóa đơn mẫu theo đúng nghiệp vụ
    final mockInvoices = [
      Invoice(
        id: 101,
        contractId: 10,
        apartmentId: 5,
        monthYear: '06/2026',
        prevElectricityIndex: 1200,
        currElectricityIndex: 1340,
        electricityConsumption: 140,
        prevWaterIndex: 350,
        currWaterIndex: 362,
        waterConsumption: 12,
        roomRentSnapshot: 4500000,
        mgmtFeeSnapshot: 150000,
        extraFee: 0,
        extraFeeDescription: null,
        totalAmount: 5190000, // 4.5M + 150k + 140*2000 (280k) + 12*2166 (260k)
        status: 'UNPAID',
        dueDate: DateTime(2026, 6, 30),
      ),
      Invoice(
        id: 100,
        contractId: 10,
        apartmentId: 5,
        monthYear: '05/2026',
        prevElectricityIndex: 1060,
        currElectricityIndex: 1200,
        electricityConsumption: 140,
        prevWaterIndex: 338,
        currWaterIndex: 350,
        waterConsumption: 12,
        roomRentSnapshot: 4500000,
        mgmtFeeSnapshot: 150000,
        extraFee: 100000,
        extraFeeDescription: 'Thay bóng đèn phòng khách',
        totalAmount: 5280000,
        status: 'PAID',
        dueDate: DateTime(2026, 5, 31),
      ),
      Invoice(
        id: 99,
        contractId: 10,
        apartmentId: 5,
        monthYear: '04/2026',
        prevElectricityIndex: 930,
        currElectricityIndex: 1060,
        electricityConsumption: 130,
        prevWaterIndex: 328,
        currWaterIndex: 338,
        waterConsumption: 10,
        roomRentSnapshot: 4500000,
        mgmtFeeSnapshot: 150000,
        extraFee: 0,
        extraFeeDescription: null,
        totalAmount: 5150000,
        status: 'PAID',
        dueDate: DateTime(2026, 4, 30),
      ),
    ];

    final mockPayments = [
      Payment(
        id: 501,
        invoiceId: 100,
        residentId: 3,
        payosOrderId: 'ORDER_17835708443',
        transactionCode: 'FT261559981294',
        amount: 5280000,
        paymentMethod: 'VietQR / PayOS',
        status: 'SUCCESS',
        paidAt: DateTime(2026, 5, 28, 14, 30),
        createdAt: DateTime(2026, 5, 28, 14, 25),
      ),
      Payment(
        id: 500,
        invoiceId: 99,
        residentId: 3,
        payosOrderId: 'ORDER_17835708422',
        transactionCode: 'FT261228831924',
        amount: 5150000,
        paymentMethod: 'VietQR / PayOS',
        status: 'SUCCESS',
        paidAt: DateTime(2026, 4, 25, 09, 15),
        createdAt: DateTime(2026, 4, 25, 09, 10),
      ),
    ];

    return BillingState(
      invoices: mockInvoices,
      payments: mockPayments,
    );
  }

  /// Khởi tạo đường link thanh toán giả lập PayOS (VietQR)
  Future<String> getPaymentLink(int invoiceId) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 800)); // Giả lập mạng
    state = state.copyWith(
      isLoading: false,
      activePaymentUrl: 'https://pay.payos.vn/web/checkout/$invoiceId',
    );
    return state.activePaymentUrl!;
  }

  /// Giả lập callback thành công từ PayOS (webhook) để cập nhật trạng thái
  Future<Payment> simulateSuccessPayment(int invoiceId) async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 1500)); // Đợi xử lý

    final invoiceIndex = state.invoices.indexWhere((inv) => inv.id == invoiceId);
    if (invoiceIndex == -1) {
      state = state.copyWith(isLoading: false, errorMessage: 'Không tìm thấy hóa đơn');
      throw Exception('Invoice not found');
    }

    final invoice = state.invoices[invoiceIndex];
    final updatedInvoice = Invoice(
      id: invoice.id,
      contractId: invoice.contractId,
      apartmentId: invoice.apartmentId,
      monthYear: invoice.monthYear,
      prevElectricityIndex: invoice.prevElectricityIndex,
      currElectricityIndex: invoice.currElectricityIndex,
      electricityConsumption: invoice.electricityConsumption,
      prevWaterIndex: invoice.prevWaterIndex,
      currWaterIndex: invoice.currWaterIndex,
      waterConsumption: invoice.waterConsumption,
      roomRentSnapshot: invoice.roomRentSnapshot,
      mgmtFeeSnapshot: invoice.mgmtFeeSnapshot,
      extraFee: invoice.extraFee,
      extraFeeDescription: invoice.extraFeeDescription,
      totalAmount: invoice.totalAmount,
      status: 'PAID',
      dueDate: invoice.dueDate,
    );

    final updatedInvoices = List<Invoice>.from(state.invoices);
    updatedInvoices[invoiceIndex] = updatedInvoice;

    final newPayment = Payment(
      id: 500 + invoiceId, // Tự sinh ID
      invoiceId: invoiceId,
      residentId: 3, // ID Resident test
      payosOrderId: 'ORDER_${DateTime.now().millisecondsSinceEpoch}',
      transactionCode: 'FT${DateTime.now().microsecondsSinceEpoch.toString().substring(0, 10)}',
      amount: invoice.totalAmount,
      paymentMethod: 'VietQR / PayOS',
      status: 'SUCCESS',
      paidAt: DateTime.now(),
      createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
    );

    final updatedPayments = List<Payment>.from(state.payments)..insert(0, newPayment);

    state = state.copyWith(
      invoices: updatedInvoices,
      payments: updatedPayments,
      isLoading: false,
      activePaymentUrl: null,
    );

    return newPayment;
  }
}

final billingProvider = NotifierProvider<BillingNotifier, BillingState>(() {
  return BillingNotifier();
});
