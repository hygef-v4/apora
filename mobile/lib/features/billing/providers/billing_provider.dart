import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
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
    // Gọi tải dữ liệu bất đồng bộ từ backend API trong background
    Future.microtask(() => fetchData());

    return BillingState(
      invoices: const [],
      payments: const [],
    );
  }

  /// Tải dữ liệu hóa đơn và thanh toán thật từ API Server
  Future<void> fetchData() async {
    try {
      final dio = ref.read(dioProvider);

      // 1. Lấy danh sách hóa đơn từ /api/bills
      final invoicesRes = await dio.get('/bills');
      final rawInvoices = invoicesRes.data['data'] as List;
      final invoicesList = rawInvoices.map((json) => Invoice.fromJson(json as Map<String, dynamic>)).toList();

      // 2. Lấy danh sách giao dịch từ /api/payments
      final paymentsRes = await dio.get('/payments');
      final rawPayments = paymentsRes.data['data'] as List;
      final paymentsList = rawPayments.map((json) => Payment.fromJson(json as Map<String, dynamic>)).toList();

      state = state.copyWith(
        invoices: invoicesList,
        payments: paymentsList,
      );
      debugPrint('[Billing] Tải dữ liệu thành công từ API.');
    } catch (e, stack) {
      debugPrint('[Billing] Lỗi tải dữ liệu từ API: $e');
      debugPrintStack(stackTrace: stack);
      state = state.copyWith(
        errorMessage: 'Không thể kết nối đến máy chủ: $e',
      );
    }
  }

  /// Khởi tạo đường link thanh toán từ cổng PayOS (API /api/payments/payos/create-url)
  Future<String> getPaymentLink(int invoiceId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dio = ref.read(dioProvider);
      
      final response = await dio.post('/payments/payos/create-url', data: {
        'invoiceId': invoiceId,
      });

      final checkoutUrl = response.data['data']['checkoutUrl'] as String;
      state = state.copyWith(isLoading: false, activePaymentUrl: checkoutUrl);
      return checkoutUrl;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      final errorMsg = mapDioError(e);
      debugPrint('[Billing] Lỗi tạo link thanh toán, chuyển chế độ giả lập offline: $errorMsg');
      
      // Fallback sang link giả lập offline
      final mockOrderId = 'MOCK_ORDER_${invoiceId}_${DateTime.now().millisecondsSinceEpoch}';
      final mockUrl = 'https://pay.payos.vn/web/checkout/$mockOrderId?amount=5190000&invoiceId=$invoiceId';
      state = state.copyWith(activePaymentUrl: mockUrl);
      return mockUrl;
    }
  }

  /// Giả lập hoặc thông báo cập nhật kết quả thanh toán từ API (/api/payments/payos/simulate-success)
  Future<Payment> simulateSuccessPayment(int invoiceId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dio = ref.read(dioProvider);

      final response = await dio.post('/payments/payos/simulate-success', data: {
        'invoiceId': invoiceId,
      });

      final payment = Payment.fromJson(response.data['data'] as Map<String, dynamic>);
      
      // Tải lại dữ liệu mới nhất từ server
      await fetchData();
      state = state.copyWith(isLoading: false, activePaymentUrl: null);
      return payment;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      debugPrint('[Billing] Lỗi gọi API Sandbox, chạy xử lý mock offline: $e');

      // Fallback: Xử lý trạng thái offline cục bộ
      final invoiceIndex = state.invoices.indexWhere((inv) => inv.id == invoiceId);
      if (invoiceIndex == -1) {
        throw Exception('Hóa đơn không tồn tại');
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
        id: 500 + invoiceId,
        invoiceId: invoiceId,
        residentId: 3,
        payosOrderId: 'MOCK_ORDER_${DateTime.now().millisecondsSinceEpoch}',
        transactionCode: 'FT${DateTime.now().microsecondsSinceEpoch.toString().substring(0, 10)}',
        amount: invoice.totalAmount,
        paymentMethod: 'VietQR / PayOS (Mock Offline)',
        status: 'SUCCESS',
        paidAt: DateTime.now(),
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );

      final updatedPayments = List<Payment>.from(state.payments)..insert(0, newPayment);

      state = state.copyWith(
        invoices: updatedInvoices,
        payments: updatedPayments,
        activePaymentUrl: null,
      );

      return newPayment;
    }
  }
}

final billingProvider = NotifierProvider<BillingNotifier, BillingState>(() {
  return BillingNotifier();
});
