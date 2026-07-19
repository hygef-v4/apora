import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../providers/dashboard_notifier.dart';

/// UC35 (FID-40): Dashboard & Báo cáo thống kê (Landlord/Manager).
class DashboardReportScreen extends ConsumerWidget {
  const DashboardReportScreen({super.key});

  /// Sinh danh sách 12 tháng gần nhất làm bộ lọc nhanh
  List<DateTime> _getFilterMonths() {
    final now = DateTime.now();
    return List.generate(12, (index) {
      return DateTime(now.year, now.month - index, 1);
    });
  }

  void _showMonthPicker(BuildContext context, WidgetRef ref, String currentFilter) {
    final months = _getFilterMonths();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'Chọn tháng báo cáo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final date = months[index];
                    final valStr = '${date.month.toString().padLeft(2, '0')}/${date.year}';
                    final isSelected = valStr == currentFilter;

                    return ListTile(
                      title: Text(
                        'Tháng ${date.month} năm ${date.year}',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        ref.read(dashboardProvider.notifier).changeMonth(valStr);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(dashboardProvider);
    final currentMonth = ref.watch(dashboardProvider.notifier).monthYear;

    final vndFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Báo cáo',
            subtitle: 'Tổng quan tài chính & sự cố vận hành',
            actions: [
              // Nút lọc tháng ở Header
              TextButton.icon(
                onPressed: () => _showMonthPicker(context, ref, currentMonth),
                icon: const Icon(Icons.calendar_month, color: Colors.white),
                label: Text(
                  currentMonth,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
              child: asyncStats.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          mapDioError(err),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (stats) {
                  final double unpaidAmount = stats.unpaidRevenue;
                  final double rate = stats.collectionRate;
                  final String ratePercent = '${(rate * 100).toStringAsFixed(1)}%';

                  return ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      // Tiêu đề tháng báo cáo hiện tại
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Số liệu thống kê tháng $currentMonth',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Grid 2x2 chỉ số
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Doanh thu phát sinh',
                              value: vndFormat.format(stats.totalRevenue),
                              caption: 'Tổng tiền hóa đơn tạo mới',
                              captionColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Doanh thu đã thu',
                              value: vndFormat.format(stats.collectedRevenue),
                              valueColor: AppColors.success,
                              caption: 'Hóa đơn trạng thái PAID',
                              captionColor: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Hóa đơn chưa đóng',
                              value: '${stats.unpaidBillsCount}',
                              valueColor: AppColors.warning,
                              caption: 'Trạng thái UNPAID',
                              captionColor: AppColors.warning,
                              highlight: stats.unpaidBillsCount > 0,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Sự cố chưa xử lý',
                              value: '${stats.unresolvedTicketsCount}',
                              valueColor: Colors.redAccent,
                              caption: 'Chờ/Đang xử lý',
                              captionColor: Colors.redAccent,
                              highlight: stats.unresolvedTicketsCount > 0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Biểu đồ hình tròn đo tỷ lệ thu hồi công nợ
                      AppCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tỷ lệ thu hồi nợ (Collection Rate)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                SizedBox(
                                  height: 90,
                                  width: 90,
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: SizedBox(
                                          height: 80,
                                          width: 80,
                                          child: CircularProgressIndicator(
                                            value: rate,
                                            strokeWidth: 8,
                                            backgroundColor: AppColors.successBg,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Text(
                                          ratePercent,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _legendItem(
                                        AppColors.success,
                                        'Đã thu hồi',
                                        vndFormat.format(stats.collectedRevenue),
                                      ),
                                      const SizedBox(height: 12),
                                      _legendItem(
                                        stats.unpaidBillsCount > 0 ? AppColors.warning : AppColors.textTertiary,
                                        'Chưa thu hồi',
                                        vndFormat.format(unpaidAmount),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Gợi ý quản trị vận hành (Business recommendations)
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gợi ý vận hành',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (stats.unpaidBillsCount > 0)
                              _recommendationItem(
                                Icons.notification_important,
                                AppColors.warning,
                                'Gửi thông báo nhắc nhở thanh toán cho ${stats.unpaidBillsCount} hóa đơn còn nợ đọng.',
                              )
                            else
                              _recommendationItem(
                                Icons.check_circle,
                                AppColors.success,
                                'Tuyệt vời! Toàn bộ hóa đơn phát sinh trong tháng đã được thu hồi đầy đủ.',
                              ),
                            const SizedBox(height: 8),
                            if (stats.unresolvedTicketsCount > 0)
                              _recommendationItem(
                                Icons.engineering,
                                Colors.redAccent,
                                'Hiện đang có ${stats.unresolvedTicketsCount} yêu cầu sự cố kỹ thuật chưa xử lý xong. Hãy kiểm tra và phân công công việc sớm.',
                              )
                            else
                              _recommendationItem(
                                Icons.verified,
                                AppColors.primary,
                                'Hệ thống vận hành tốt, không có sự cố tồn đọng trong tháng.',
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _recommendationItem(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
          ),
        ),
      ],
    );
  }
}
