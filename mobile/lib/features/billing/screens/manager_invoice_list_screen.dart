import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/billing_provider.dart';
import '../models/payment.dart';
import '../../../core/router/app_router.dart';

class ManagerInvoiceListScreen extends ConsumerStatefulWidget {
  const ManagerInvoiceListScreen({super.key});

  @override
  ConsumerState<ManagerInvoiceListScreen> createState() => _ManagerInvoiceListScreenState();
}

class _ManagerInvoiceListScreenState extends ConsumerState<ManagerInvoiceListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Tải dữ liệu mới nhất khi mở màn hình
    Future.microtask(() => ref.read(billingProvider.notifier).fetchData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
    final state = ref.watch(billingProvider);

    final unpaidInvoices = state.invoices.where((inv) => inv.status == 'UNPAID').toList();
    final paidInvoices = state.invoices.where((inv) => inv.status == 'PAID').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          GradientHeader(
            title: 'Hóa Đơn & Thu Tiền',
            subtitle: 'Quản lý công nợ toàn tòa nhà',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: 'Làm mới',
                onTap: () => ref.read(billingProvider.notifier).fetchData(),
              ),
            ],
          ),
          // Tab bar phân loại
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                Tab(text: 'Chưa đóng (${unpaidInvoices.length})'),
                Tab(text: 'Đã đóng (${paidInvoices.length})'),
                Tab(text: 'Giao dịch (${state.payments.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInvoiceList(unpaidInvoices, isPaid: false),
                _buildInvoiceList(paidInvoices, isPaid: true),
                _buildTransactionList(state.payments),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Đi tới màn lập hóa đơn, sau khi về sẽ reload dữ liệu
          await context.push(AppRoutes.generateBill);
          ref.read(billingProvider.notifier).fetchData();
        },
        backgroundColor: AppColors.navy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Lập hóa đơn', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildInvoiceList(List<dynamic> invoices, {required bool isPaid}) {
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPaid ? Icons.check_circle_outline : Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 8),
            Text(
              isPaid ? 'Chưa có hóa đơn nào đã đóng.' : 'Không có hóa đơn chưa thanh toán nào.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(billingProvider.notifier).fetchData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: invoices.length,
        itemBuilder: (context, idx) {
          final invoice = invoices[idx];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Căn ${invoice.unitNumber ?? "N/A"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tháng ${invoice.monthYear}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        isPaid ? StatusBadge.success('Đã đóng') : const StatusBadge(text: 'Chưa đóng', color: AppColors.error, backgroundColor: AppColors.errorBg),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.divider),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Số tiền hóa đơn', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              _formatMoney(invoice.totalAmount),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.navy),
                            ),
                          ],
                        ),
                        if (invoice.extraFee > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Phí phát sinh', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                              const SizedBox(height: 2),
                              Text(
                                '+${_formatMoney(invoice.extraFee)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hạn nộp: ${invoice.dueDate.day}/${invoice.dueDate.month}/${invoice.dueDate.year}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        ),
                        Text(
                          'Điện: ${invoice.electricityConsumption.toInt()} kWh | Nước: ${invoice.waterConsumption.toInt()} m³',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionList(List<Payment> payments) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            const Text(
              'Không có giao dịch thanh toán nào.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(billingProvider.notifier).fetchData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: payments.length,
        itemBuilder: (context, idx) {
          final payment = payments[idx];
          
          Widget statusBadge;
          if (payment.status == 'SUCCESS') {
            statusBadge = StatusBadge.success('Thành công');
          } else if (payment.status == 'PENDING') {
            statusBadge = StatusBadge.warning('Đang xử lý');
          } else {
            statusBadge = const StatusBadge(
              text: 'Thất bại',
              color: AppColors.error,
              backgroundColor: AppColors.errorBg,
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Căn ${payment.unitNumber ?? "N/A"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              payment.monthYear != null ? 'Tháng ${payment.monthYear}' : 'Hóa đơn',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        statusBadge,
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.divider),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Số tiền thanh toán', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            const SizedBox(height: 2),
                            Text(
                              _formatMoney(payment.amount),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.navy),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Phương thức', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                            const SizedBox(height: 2),
                            Text(
                              payment.paymentMethod,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mã GD: ${payment.transactionCode ?? "Chưa có"}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Ngày: ${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year} ${payment.createdAt.hour}:${payment.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
