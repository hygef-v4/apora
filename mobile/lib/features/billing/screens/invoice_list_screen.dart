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
  int _selectedTabIndex = 0; // 0: Chưa thanh toán, 1: Đã thanh toán

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

    final unpaidInvoices = billingState.invoices
        .where((inv) => inv.status == 'UNPAID' || inv.status == 'PARTIAL')
        .toList();
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

    final paidInvoices = billingState.invoices
        .where((inv) => inv.status == 'PAID')
        .toList();
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
          // Header Bar
          Container(
            decoration: isAdminOrOwner
                ? const BoxDecoration(gradient: AppColors.headerGradient)
                : const BoxDecoration(gradient: AppColors.residentGradient),
            width: double.infinity,
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'My Bills',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Body with Tab Bar
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // Top Segmented Control Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTabIndex == 0 ? AppColors.cardShadow : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Unpaid (${unpaidInvoices.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTabIndex == 0 ? AppColors.textPrimary : AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTabIndex = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedTabIndex == 1 ? AppColors.cardShadow : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Paid (${paidInvoices.length})',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedTabIndex == 1 ? AppColors.textPrimary : AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // TAB 0: UNPAID INVOICES
                if (_selectedTabIndex == 0) ...[
                  if (unpaidInvoices.isEmpty)
                    AppCard(
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
                              'No unpaid bills',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...unpaidInvoices.map((invoice) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _UnpaidInvoiceCard(
                          invoice: invoice,
                          isLoading: billingState.isLoading,
                          formatMoney: _formatMoney,
                          onPay: () async {
                            final paymentUrl = await ref
                                .read(billingProvider.notifier)
                                .getPaymentLink(invoice.id);
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
                        ),
                      );
                    }),
                ],

                // TAB 1: PAID INVOICES
                if (_selectedTabIndex == 1) ...[
                  if (paidInvoices.isEmpty)
                    const AppCard(
                      child: Center(
                        child: Text(
                          'No payment history',
                          style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
                        ),
                      ),
                    )
                  else
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

                      String methodText = 'Bank Transfer';
                      if (payment.paymentMethod.toLowerCase().contains('cash') ||
                          payment.paymentMethod.toLowerCase().contains('tiền mặt')) {
                        methodText = 'Cash';
                      }

                      final payDate = payment.paidAt ?? payment.createdAt;
                      final dateStr =
                          '${payDate.day.toString().padLeft(2, '0')}/${payDate.month.toString().padLeft(2, '0')}';

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
                                      'Bill ${invoice.monthYear}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Paid on $dateStr · $methodText',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatMoney(invoice.totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF16A34A),
                                ),
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

class _UnpaidInvoiceCard extends StatelessWidget {
  final Invoice invoice;
  final bool isLoading;
  final String Function(double) formatMoney;
  final VoidCallback onPay;

  const _UnpaidInvoiceCard({
    required this.invoice,
    required this.isLoading,
    required this.formatMoney,
    required this.onPay,
  });

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dueDateStr =
        '${invoice.dueDate.month.toString().padLeft(2, '0')}/${invoice.dueDate.day.toString().padLeft(2, '0')}/${invoice.dueDate.year}';
    final elecAmount = invoice.electricityConsumption * invoice.electricityRateSnapshot;
    final waterAmount = invoice.waterConsumption * invoice.waterRateSnapshot;

    return Column(
      children: [
        // Main Invoice Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppColors.cardShadow,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Month Year & Due Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill ${invoice.monthYear}',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Due: $dueDateStr',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider, thickness: 1),
              const SizedBox(height: 12),

              // Item Breakdown List
              _buildDetailRow('Room Rent', formatMoney(invoice.roomRentSnapshot)),
              _buildDetailRow('Electricity', formatMoney(elecAmount)),
              _buildDetailRow('Water', formatMoney(waterAmount)),
              _buildDetailRow('Management Fee', formatMoney(invoice.mgmtFeeSnapshot)),
              if (invoice.extraFee > 0)
                _buildDetailRow(
                  invoice.extraFeeDescription ?? 'Extra Fee',
                  formatMoney(invoice.extraFee),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider, thickness: 1),
              const SizedBox(height: 16),

              // Total Amount Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Text(
                    formatMoney(invoice.totalAmount),
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // PAY NOW Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPay,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 3,
              shadowColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'PAY NOW',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                  ),
          ),
        ),
      ],
    );
  }
}
