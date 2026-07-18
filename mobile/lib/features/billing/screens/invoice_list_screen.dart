import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
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
    return '${buffer.toString()} đ';
  }

  @override
  Widget build(BuildContext context) {
    final billingState = ref.watch(billingProvider);
    final unpaidInvoices = billingState.invoices.where((inv) => inv.status == 'UNPAID').toList();
    final paidInvoices = billingState.invoices.where((inv) => inv.status == 'PAID').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            GradientHeader(
              title: 'Hóa đơn của tôi',
              subtitle: 'Căn hộ 502 · Chung cư Apora',
              bottom: const TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                tabs: [
                  Tab(text: 'Chưa thanh toán'),
                  Tab(text: 'Đã thanh toán'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Chưa thanh toán
                  _buildUnpaidTab(unpaidInvoices, billingState.isLoading),
                  // Tab 2: Đã thanh toán
                  _buildPaidTab(paidInvoices),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdown(Invoice invoice) {
    return Column(
      children: [
        _buildBreakdownItem(
          icon: Icons.home_work_rounded,
          iconColor: AppColors.primary,
          title: 'Tiền thuê căn hộ',
          subtitle: 'Theo giá cố định hợp đồng',
          value: _formatMoney(invoice.roomRentSnapshot),
        ),
        const Divider(height: 20, color: AppColors.divider),
        _buildBreakdownItem(
          icon: Icons.electric_bolt_rounded,
          iconColor: AppColors.warning,
          title: 'Tiền điện tiêu thụ',
          subtitle: 'Chỉ số: ${invoice.prevElectricityIndex.toInt()} → ${invoice.currElectricityIndex.toInt()} (${invoice.electricityConsumption.toInt()} kWh)',
          value: _formatMoney(invoice.electricityConsumption * invoice.electricityRateSnapshot),
        ),
        const Divider(height: 20, color: AppColors.divider),
        _buildBreakdownItem(
          icon: Icons.water_drop_rounded,
          iconColor: Colors.cyan,
          title: 'Tiền nước sinh hoạt',
          subtitle: 'Chỉ số: ${invoice.prevWaterIndex.toInt()} → ${invoice.currWaterIndex.toInt()} (${invoice.waterConsumption.toInt()} m³)',
          value: _formatMoney(invoice.waterConsumption * invoice.waterRateSnapshot),
        ),
        const Divider(height: 20, color: AppColors.divider),
        _buildBreakdownItem(
          icon: Icons.admin_panel_settings_rounded,
          iconColor: AppColors.success,
          title: 'Phí dịch vụ & Quản lý',
          subtitle: 'Phí vận hành chung cư',
          value: _formatMoney(invoice.mgmtFeeSnapshot),
        ),
        if (invoice.extraFee > 0) ...[
          const Divider(height: 20, color: AppColors.divider),
          _buildBreakdownItem(
            icon: Icons.add_circle_rounded,
            iconColor: AppColors.purple,
            title: 'Chi phí phát sinh',
            subtitle: invoice.extraFeeDescription ?? 'Không có mô tả',
            value: _formatMoney(invoice.extraFee),
          ),
        ],
      ],
    );
  }

  Widget _buildUnpaidTab(List<Invoice> unpaidInvoices, bool isLoading) {
    if (unpaidInvoices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, size: 40, color: AppColors.success),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hoàn thành hóa đơn!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Căn hộ của bạn hiện không có hóa đơn nào cần thanh toán. Tuyệt vời!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: unpaidInvoices.length,
      itemBuilder: (context, idx) {
        final invoice = unpaidInvoices[idx];
        return _UnpaidInvoiceCard(
          invoice: invoice,
          isLoading: isLoading,
          formatMoney: _formatMoney,
          buildBreakdown: _buildBreakdown,
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
      },
    );
  }

  Widget _buildPaidTab(List<Invoice> paidInvoices) {
    if (paidInvoices.isEmpty) {
      return const Center(
        child: Text(
          'Không có lịch sử hóa đơn đã thanh toán',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: paidInvoices.length,
      itemBuilder: (context, index) {
        final invoice = paidInvoices[index];
        final billingState = ref.watch(billingProvider);
        // Tìm transaction tương ứng
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: () {
              // Chuyển tới xem biên lai thanh toán (UC17)
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
                    color: AppColors.successBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long, color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hóa đơn Tháng ${invoice.monthYear}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        payment.paidAt != null
                            ? 'Thanh toán: ${payment.paidAt!.day}/${payment.paidAt!.month}/${payment.paidAt!.year}'
                            : 'Đã hoàn thành',
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMoney(invoice.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Đã đóng',
                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreakdownItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hóa đơn Tháng ${widget.invoice.monthYear}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        const StatusBadge(
                          text: 'Chưa đóng',
                          color: AppColors.error,
                          backgroundColor: AppColors.errorBg,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              'Hạn đóng: ${widget.invoice.dueDate.day}/${widget.invoice.dueDate.month}/${widget.invoice.dueDate.year}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              _isExpanded ? 'Thu gọn' : 'Xem chi tiết',
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                            Icon(
                              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: AppColors.divider),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tổng tiền cần đóng',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.formatMoney(widget.invoice.totalAmount),
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.error),
                            ),
                          ],
                        ),
                        if (!_isExpanded)
                          ElevatedButton.icon(
                            onPressed: widget.isLoading ? null : widget.onPay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.qr_code, size: 14),
                            label: const Text('Đóng tiền', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'BẢNG KÊ CHI TIẾT KHOẢN PHÍ',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 4),
              widget.buildBreakdown(widget.invoice),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: widget.isLoading ? null : widget.onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'THANH TOÁN NGAY VIA VietQR',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
