import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../providers/billing_provider.dart';

class ManagerInvoiceListScreen extends ConsumerStatefulWidget {
  const ManagerInvoiceListScreen({super.key});

  @override
  ConsumerState<ManagerInvoiceListScreen> createState() => _ManagerInvoiceListScreenState();
}

class _ManagerInvoiceListScreenState extends ConsumerState<ManagerInvoiceListScreen> {
  static const List<String> _statusOptions = ['All Statuses', 'Success', 'Failed'];

  String _selectedMonth = 'All Months';
  String _selectedStatus = 'All Statuses';
  int _currentPage = 1;
  final int _pageSize = 5;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(billingProvider.notifier).fetchData());
  }

  @override
  Widget build(BuildContext context) {
    final billingState = ref.watch(billingProvider);
    final payments = billingState.payments;

    // Trích xuất danh sách các tháng thực tế có trong dữ liệu giao dịch
    final monthSet = <String>{};
    for (final p in payments) {
      if (p.monthYear != null && p.monthYear!.isNotEmpty) {
        monthSet.add(p.monthYear!);
      } else {
        final m = p.createdAt.month.toString().padLeft(2, '0');
        final y = p.createdAt.year;
        monthSet.add('$m/$y');
      }
    }

    final monthOptions = ['All Months', ...monthSet.toList()..sort((a, b) => b.compareTo(a))];
    final currentMonth = monthOptions.contains(_selectedMonth) ? _selectedMonth : monthOptions.first;
    final currentStatus = _statusOptions.contains(_selectedStatus) ? _selectedStatus : _statusOptions.first;

    // Filter Payments chính xác theo Tháng & Trạng thái
    final filteredPayments = payments.where((p) {
      if (currentStatus == 'Success' && p.status != 'SUCCESS') return false;
      if (currentStatus == 'Failed' && p.status == 'SUCCESS') return false;

      if (currentMonth != 'All Months') {
        final pMonthYear = p.monthYear ?? '${p.createdAt.month.toString().padLeft(2, '0')}/${p.createdAt.year}';
        if (!pMonthYear.contains(currentMonth)) {
          return false;
        }
      }
      return true;
    }).toList();

    final totalPages = (filteredPayments.length / _pageSize).ceil().clamp(1, 99);
    final startIndex = (_currentPage - 1) * _pageSize;
    final pagePayments = filteredPayments.skip(startIndex).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Transaction History',
            showBack: true,
          ),
          Expanded(
            child: billingState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Filter Controls (Vertical Layout per mockup 2)
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
                                const Text('Select Month', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    isDense: true,
                                    value: currentMonth,
                                    items: monthOptions.map((m) {
                                      return DropdownMenuItem(
                                        value: m,
                                        child: Text(m, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      );
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
                                const Text('Status', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    isDense: true,
                                    value: currentStatus,
                                    items: _statusOptions.map((s) {
                                      return DropdownMenuItem(
                                        value: s,
                                        child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                      );
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

                      // Main Transaction Table matching mockup 2
                      if (filteredPayments.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          alignment: Alignment.center,
                          child: const Column(
                            children: [
                              Icon(Icons.history, size: 48, color: AppColors.textTertiary),
                              SizedBox(height: 8),
                              Text(
                                'No payment transactions found.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      else
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
                                    Expanded(flex: 3, child: Text('Apartment ID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                                    Expanded(flex: 4, child: Text('Payment Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                                    Expanded(flex: 3, child: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                                  ],
                                ),
                              ),

                              // Table Body Rows
                              ...pagePayments.map((payment) {
                                final dateStr = '${payment.createdAt.day.toString().padLeft(2, '0')}/${payment.createdAt.month.toString().padLeft(2, '0')}/${payment.createdAt.year}';
                                final timeStr = '${payment.createdAt.hour.toString().padLeft(2, '0')}:${payment.createdAt.minute.toString().padLeft(2, '0')}';
                                final aptIdStr = payment.unitNumber != null ? 'A-${payment.unitNumber}' : 'A-${payment.id}';
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
                                                    isSuccess ? 'Success' : 'Failed',
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
                                            'TX Code: ${payment.transactionCode}',
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

                      // Pagination Control Bar matching mockup 2
                      if (filteredPayments.isNotEmpty)
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
                              child: const Text('< Previous', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
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
                              child: const Text('Next >', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
