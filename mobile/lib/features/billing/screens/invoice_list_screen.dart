import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/invoice.dart';
import '../models/payment.dart';
import '../providers/billing_provider.dart';

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  // Bộ định dạng tiền tệ đơn giản không cần thư viện intl
  String _formatMoney(double amount) {
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()}đ';
  }

  @override
  Widget build(BuildContext context) {
    final billingState = ref.watch(billingProvider);
    
    // Hóa đơn chưa thanh toán sắp xếp tăng dần theo MonthYear (cũ nhất lên đầu)
    final unpaidInvoices = billingState.invoices.where((inv) => inv.status == 'UNPAID' || inv.status == 'PARTIAL').toList();
    unpaidInvoices.sort((a, b) {
      try {
        final aParts = a.monthYear.split('/');
        final bParts = b.monthYear.split('/');
        final aMonth = int.parse(aParts[0]);
        final aYear = int.parse(aParts[1]);
        final bMonth = int.parse(bParts[0]);
        final bYear = int.parse(bParts[1]);
        if (aYear != bYear) return aYear.compareTo(bYear);
        return aMonth.compareTo(bMonth);
      } catch (_) {
        return a.id.compareTo(b.id);
      }
    });

    // Hóa đơn đã thanh toán sắp xếp giảm dần theo MonthYear (mới nhất lên đầu)
    final paidInvoices = billingState.invoices.where((inv) => inv.status == 'PAID').toList();
    paidInvoices.sort((a, b) {
      try {
        final aParts = a.monthYear.split('/');
        final bParts = b.monthYear.split('/');
        final aMonth = int.parse(aParts[0]);
        final aYear = int.parse(aParts[1]);
        final bMonth = int.parse(bParts[0]);
        final bYear = int.parse(bParts[1]);
        if (aYear != bYear) return bYear.compareTo(aYear);
        return bMonth.compareTo(aMonth);
      } catch (_) {
        return b.id.compareTo(a.id);
      }
    });

    final user = ref.watch(authNotifierProvider).user;
    final isAdminOrOwner = user != null &&
        (user.roles.contains('MANAGER') || user.roles.contains('LANDLORD'));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            decoration: isAdminOrOwner
                ? const BoxDecoration(gradient: AppColors.headerGradient)
                : const BoxDecoration(gradient: AppColors.residentGradient),
            width: double.infinity,
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Text(
                  'Hoá đơn của tôi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Danh sách hóa đơn chưa thanh toán
                ...unpaidInvoices.map((invoice) {
                  return _UnpaidInvoiceCard(
                    invoice: invoice,
                    isLoading: billingState.isLoading,
                    formatMoney: _formatMoney,
                    buildBreakdown: (_) => const SizedBox.shrink(),
                    onPay: () async {
                      final paymentUrl = await ref.read(billingProvider.notifier).getPaymentLink(invoice.id);
                      if (!context.mounted) return;
                      context.push(
                        '/invoices/pay',
                        extra: {
                          'invoiceId': invoice.id,
                          'paymentUrl': paymentUrl,
                          'totalAmount': invoice.totalAmount,
                        },
                      );
                    },
                  );
                }),

                if (unpaidInvoices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.successBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle, color: AppColors.success),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'Không có hoá đơn chưa thanh toán',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 2. Nhãn "LỊCH SỬ THANH TOÁN"
                if (paidInvoices.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 12),
                    child: Text(
                      'LỊCH SỬ THANH TOÁN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  // 3. Danh sách hóa đơn đã thanh toán
                  ...paidInvoices.map((invoice) {
                    final payment = billingState.payments.firstWhere(
                      (p) => p.invoiceId == invoice.id,
                      orElse: () => Payment(
                        id: 0,
                        invoiceId: invoice.id,
                        residentId: 3,
                        payosOrderId: '',
                        amount: invoice.totalAmount,
                        paymentMethod: 'VietQR / PayOS',
                        status: 'SUCCESS',
                        createdAt: DateTime.now(),
                      ),
                    );

                    String methodText = 'Chuyển khoản';
                    if (payment.paymentMethod.toLowerCase().contains('cash') == true || 
                        payment.paymentMethod.toLowerCase().contains('tiền mặt') == true) {
                      methodText = 'Tiền mặt';
                    }

                    final payDate = payment.paidAt ?? payment.createdAt;
                    final dateStr = '${payDate.day.toString().padLeft(2, '0')}/${payDate.month.toString().padLeft(2, '0')}';

                    final double amountInMillions = invoice.totalAmount / 1000000;
                    final String amountStr = '${amountInMillions.toStringAsFixed(2)}M';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        onTap: () {
                          context.push(
                            '/invoices/receipt',
                            extra: {
                              'invoice': invoice,
                              'payment': payment,
                            },
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFFDCFCE7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Color(0xFF16A34A), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tháng ${invoice.monthYear}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Thanh toán $dateStr · $methodText',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              amountStr,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF16A34A)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnpaidInvoiceCard extends StatefulWidget {
  final Invoice invoice;
  final bool isLoading;
  final String Function(double) formatMoney;
  final Widget Function(Invoice) buildBreakdown;
  final VoidCallback onPay;

  const _UnpaidInvoiceCard({
    required this.invoice,
    required this.isLoading,
    required this.formatMoney,
    required this.buildBreakdown,
    required this.onPay,
  });

  @override
  State<_UnpaidInvoiceCard> createState() => _UnpaidInvoiceCardState();
}

class _UnpaidInvoiceCardState extends State<_UnpaidInvoiceCard> {
  bool _isExpanded = false;

  Widget _buildExpandedDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isExpanded) {
      // Trạng thái ĐÓNG: giao diện gọn giống lịch sử thanh toán bên dưới
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          onTap: () => setState(() => _isExpanded = true),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7), // Màu nền vàng nhạt
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hóa đơn Tháng ${widget.invoice.monthYear}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hạn đóng: ${widget.invoice.dueDate.day}/${widget.invoice.dueDate.month}/${widget.invoice.dueDate.year}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.formatMoney(widget.invoice.totalAmount),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Chưa đóng',
                    style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      );
    }

    // Trạng thái MỞ: giao diện thẻ chi tiết có viền xanh và nút thanh toán VietQR
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF12A8F1), width: 2), // Viền xanh dương
          boxShadow: AppColors.cardShadow,
        ),
        padding: const EdgeInsets.all(20),
        child: InkWell(
          onTap: () => setState(() => _isExpanded = false),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tháng ${widget.invoice.monthYear}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Chưa thanh toán',
                      style: TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Bảng kê chi tiết khoản phí
              _buildExpandedDetailRow('Tiền thuê', widget.formatMoney(widget.invoice.roomRentSnapshot)),
              _buildExpandedDetailRow(
                'Điện · ${widget.invoice.electricityConsumption.toInt()} kWh',
                widget.formatMoney(widget.invoice.electricityConsumption * widget.invoice.electricityRateSnapshot),
              ),
              _buildExpandedDetailRow(
                'Nước · ${widget.invoice.waterConsumption.toInt()} m³',
                widget.formatMoney(widget.invoice.waterConsumption * widget.invoice.waterRateSnapshot),
              ),
              _buildExpandedDetailRow('Phí dịch vụ', widget.formatMoney(widget.invoice.mgmtFeeSnapshot)),
              if (widget.invoice.extraFee > 0)
                _buildExpandedDetailRow(
                  widget.invoice.extraFeeDescription ?? 'Phí phát sinh',
                  widget.formatMoney(widget.invoice.extraFee),
                ),
              const Divider(height: 24, color: AppColors.divider),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    widget.formatMoney(widget.invoice.totalAmount),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF12A8F1)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: widget.isLoading ? null : widget.onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF12A8F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Thanh toán qua QR',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
