import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/payment.dart';
import '../providers/billing_provider.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            title: 'Hóa Đơn',
            subtitle: 'Quản lý công nợ toàn tòa nhà',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.settings,
                tooltip: 'Thiết lập đơn giá',
                onTap: () => context.push(AppRoutes.pricingSettings),
              ),
            ],
          ),
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
                _TransactionHistoryView(payments: state.payments, formatMoney: _formatMoney),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push(AppRoutes.generateBill);
          ref.read(billingProvider.notifier).fetchData();
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      itemBuilder: (context, index) {
        final inv = invoices[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaid ? Icons.check : Icons.receipt_long,
                  color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Căn ${inv.unitNumber ?? "N/A"} · Tháng ${inv.monthYear}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hạn: ${inv.dueDate.day}/${inv.dueDate.month}/${inv.dueDate.year}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
              Text(
                _formatMoney(inv.totalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isPaid ? const Color(0xFF16A34A) : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionHistoryView extends StatefulWidget {
  final List<Payment> payments;
  final String Function(double) formatMoney;

  const _TransactionHistoryView({
    required this.payments,
    required this.formatMoney,
  });

  @override
  State<_TransactionHistoryView> createState() => _TransactionHistoryViewState();
}

class _TransactionHistoryViewState extends State<_TransactionHistoryView> {
  static const List<String> _statusOptions = ['Tất cả trạng thái', 'Thành công', 'Thất bại'];

  String _selectedMonth = 'Tất cả các tháng';
  String _selectedStatus = 'Tất cả trạng thái';
  int _currentPage = 1;
  final int _pageSize = 5;

  @override
  Widget build(BuildContext context) {
    // Trích xuất danh sách các tháng thực tế có trong dữ liệu giao dịch
    final monthSet = <String>{};
    for (final p in widget.payments) {
      if (p.monthYear != null && p.monthYear!.isNotEmpty) {
        monthSet.add('Tháng ${p.monthYear}');
      } else {
        final m = p.createdAt.month.toString().padLeft(2, '0');
        final y = p.createdAt.year;
        monthSet.add('Tháng $m/$y');
      }
    }

    final monthOptions = ['Tất cả các tháng', ...monthSet.toList()..sort((a, b) => b.compareTo(a))];
    final currentMonth = monthOptions.contains(_selectedMonth) ? _selectedMonth : monthOptions.first;
    final currentStatus = _statusOptions.contains(_selectedStatus) ? _selectedStatus : _statusOptions.first;

    if (widget.payments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 8),
            Text(
              'Không có giao dịch thanh toán nào.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Filter Payments chính xác theo Tháng & Trạng thái
    final filteredPayments = widget.payments.where((p) {
      // 1. Lọc theo Trạng thái
      if (currentStatus == 'Thành công' && p.status != 'SUCCESS') return false;
      if (currentStatus == 'Thất bại' && p.status == 'SUCCESS') return false;

      // 2. Lọc theo Tháng
      if (currentMonth != 'Tất cả các tháng') {
        final targetMonthYear = currentMonth.replaceAll('Tháng ', '').trim();
        final pMonthYear = p.monthYear ?? '${p.createdAt.month.toString().padLeft(2, '0')}/${p.createdAt.year}';
        if (!pMonthYear.contains(targetMonthYear)) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalPages = (filteredPayments.length / _pageSize).ceil().clamp(1, 99);
    final startIndex = (_currentPage - 1) * _pageSize;
    final pagePayments = filteredPayments.skip(startIndex).take(_pageSize).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Title Bar
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Lịch sử giao dịch',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
        ),

        // Filter Controls (Vertical Layout per mockup)
        Column(
          children: [
            // 1. Select Month Filter Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chọn tháng', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      value: currentMonth,
                      items: monthOptions.map((m) {
                        return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() { _selectedMonth = val; _currentPage = 1; });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 2. Status Filter Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trạng thái', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      value: currentStatus,
                      items: _statusOptions.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() { _selectedStatus = val; _currentPage = 1; });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Main Transaction Table (Vietnamese Style)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.0),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 1.0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Mã Căn Hộ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                    Expanded(flex: 4, child: Text('Ngày thanh toán', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                    Expanded(flex: 3, child: Text('Trạng thái', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                  ],
                ),
              ),

              // Table Body Rows
              ...pagePayments.map((payment) {
                final dateStr = '${payment.createdAt.day.toString().padLeft(2, '0')}/${payment.createdAt.month.toString().padLeft(2, '0')}/${payment.createdAt.year}';
                final timeStr = '${payment.createdAt.hour}:${payment.createdAt.minute.toString().padLeft(2, '0')}';
                final aptIdStr = payment.unitNumber != null ? 'Căn ${payment.unitNumber}' : 'Căn ${payment.id}';
                final isSuccess = payment.status == 'SUCCESS';

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Column 1: Apartment ID
                          Expanded(
                            flex: 3,
                            child: Text(
                              aptIdStr,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                          ),
                          // Column 2: Payment Date & Time
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                Text(timeStr, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          // Column 3: Status Badge
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFEF4444), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isSuccess ? Icons.check_circle : Icons.info_outline, size: 12, color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                                  const SizedBox(width: 4),
                                  Text(
                                    isSuccess ? 'Thành công' : 'Thất bại',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSuccess ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (payment.transactionCode != null) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Mã GD: ${payment.transactionCode}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Pagination Control Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border, width: 1.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('< Trước', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ...List.generate(totalPages.clamp(1, 3), (idx) {
              final pageNum = idx + 1;
              final isSelected = pageNum == _currentPage;
              return GestureDetector(
                onTap: () => setState(() => _currentPage = pageNum),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 1.0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$pageNum',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border, width: 1.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Sau >', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
