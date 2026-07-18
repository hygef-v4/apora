import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/quick_action_button.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../../management/providers/apartment_notifier.dart';
import '../../billing/providers/billing_provider.dart';
import '../../ticket/providers/ticket_provider.dart';
import '../../contract/providers/contract_provider.dart';

/// Tab Trang chủ của Quản lý — theo màn 01 "Dashboard" trong thiết kế.
/// Sử dụng dữ liệu thật từ các providers tương ứng.
class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  static const _weekdays = [
    'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
  ];

  String get _today {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${now.day} tháng ${now.month} · ${now.year}';
  }

  String _formatCurrency(double amount) {
    final format = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    var count = 0;
    for (var i = format.length - 1; i >= 0; i--) {
      buffer.write(format[i]);
      count++;
      if (count == 3 && i > 0) {
        buffer.write('.');
        count = 0;
      }
    }
    return '${buffer.toString().split('').reversed.join()}đ';
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ';
    } else {
      return '${diff.inDays} ngày';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    
    // Watch real data providers
    final apartmentsAsync = ref.watch(apartmentDirectoryProvider);
    final billingState = ref.watch(billingProvider);
    final ticketState = ref.watch(ticketProvider);
    final extensionsAsync = ref.watch(extensionListProvider);

    // Compute apartment stats
    final apartments = apartmentsAsync.value ?? [];
    final totalApartments = apartments.length;
    final occupiedApartments = apartments.where((a) => a.status == 'OCCUPIED').length;
    final vacantApartments = apartments.where((a) => a.status == 'EMPTY').length;
    final occupancyRate = totalApartments > 0 
        ? (occupiedApartments / totalApartments * 100) 
        : 0.0;

    // Compute billing stats (Revenue for current month)
    final now = DateTime.now();
    final currentMonthStr = "${now.month.toString().padLeft(2, '0')}/${now.year}";
    final currentMonthPaidInvoices = billingState.invoices
        .where((inv) => inv.monthYear == currentMonthStr && inv.status == 'PAID');
    final revenue = currentMonthPaidInvoices.fold<double>(0, (sum, inv) => sum + inv.totalAmount);

    // Sum paid invoices for the previous month to calculate growth
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    final prevMonthStr = "${prevMonth.toString().padLeft(2, '0')}/$prevYear";
    final prevMonthPaidInvoices = billingState.invoices
        .where((inv) => inv.monthYear == prevMonthStr && inv.status == 'PAID');
    final prevRevenue = prevMonthPaidInvoices.fold<double>(0, (sum, inv) => sum + inv.totalAmount);

    final diffPercent = prevRevenue > 0 
        ? ((revenue - prevRevenue) / prevRevenue * 100) 
        : 0.0;
    final diffSign = diffPercent >= 0 ? '+' : '';
    
    final revenueText = revenue >= 1000000 
        ? '${(revenue / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M'
        : _formatCurrency(revenue);

    final growthText = prevRevenue > 0
        ? '$diffSign${diffPercent.toStringAsFixed(1).replaceAll('.', ',')}% tháng trước'
        : '↑ 0% tháng trước';

    // Construct Activities feed
    final List<Map<String, dynamic>> activities = [];
    
    // 1. Success Payments
    activities.addAll(
      billingState.payments
          .where((p) => p.status == 'SUCCESS')
          .map((p) => {
                'title': '${p.residentName ?? 'Cư dân'} đã thanh toán',
                'subtitle': 'Tiền thuê ${p.unitNumber ?? ''} - ${_formatCurrency(p.amount)}',
                'createdAt': p.paidAt ?? p.createdAt,
                'icon': Icons.credit_card,
                'iconColor': AppColors.success,
                'iconBg': AppColors.successBg,
              }),
    );
    
    // 2. Repair Tickets
    activities.addAll(
      ticketState.tickets.map((t) => {
            'title': 'Yêu cầu bảo trì ${t.unitNumber}',
            'subtitle': '${t.category} - ${t.description}',
            'createdAt': t.createdAt,
            'icon': Icons.build,
            'iconColor': AppColors.primary,
            'iconBg': AppColors.infoBg,
          }),
    );
    
    // 3. Contract Extensions
    final extensions = extensionsAsync.value ?? [];
    activities.addAll(
      extensions.map((e) => {
            'title': 'Gia hạn hợp đồng ${e.unitNumber}',
            'subtitle': 'Đề xuất mới - ${e.residentName}',
            'createdAt': e.createdAt,
            'icon': Icons.insert_drive_file,
            'iconColor': AppColors.warning,
            'iconBg': AppColors.warningBg,
          }),
    );
    
    // Sort activities by date desc
    activities.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
    final recentActivities = activities.take(3).toList();

    return Column(
      children: [
        GradientHeader(
          titleWidget: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quản lý · Chung cư Apora',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: .6),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Xin chào, ${user?.fullName ?? 'Quản lý'} 👋',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _today,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: .55),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.profile),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: InitialsAvatar(
                      name: user?.fullName ?? '?',
                      imageUrl: user?.avatarUrl,
                      size: 40,
                      square: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            HeaderIconButton(
              icon: Icons.logout,
              tooltip: 'Đăng xuất',
              onTap: () => ref.read(authNotifierProvider.notifier).logout(),
            ),
          ],
          bottom: const SizedBox(height: 12),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(apartmentDirectoryProvider.notifier).refresh();
            },
            child: ListView(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Tổng căn hộ',
                              value: '$totalApartments',
                              caption: 'Chung cư Apora',
                              captionColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Đang thuê',
                              value: '$occupiedApartments',
                              valueColor: AppColors.success,
                              caption: '↑ ${occupancyRate.toStringAsFixed(1).replaceAll('.', ',')}% lấp đầy',
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
                              label: 'Đang trống',
                              value: '$vacantApartments',
                              valueColor: AppColors.primary,
                              caption: 'Sẵn cho thuê',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Doanh thu T${now.month}',
                              value: revenueText,
                              caption: growthText,
                              highlight: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thao tác nhanh',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                QuickActionButton(
                                  icon: Icons.apartment,
                                  label: 'Căn hộ',
                                  color: AppColors.primary,
                                  backgroundColor: AppColors.infoBg,
                                  onTap: () => context.push(AppRoutes.apartmentList),
                                ),
                                QuickActionButton(
                                  icon: Icons.people,
                                  label: 'Duyệt thành viên',
                                  color: AppColors.success,
                                  backgroundColor: AppColors.successBg,
                                  onTap: () => context.push(AppRoutes.managerRoommates),
                                ),
                                QuickActionButton(
                                  icon: Icons.engineering,
                                  label: 'Nhân viên',
                                  color: AppColors.warning,
                                  backgroundColor: AppColors.warningBg,
                                  onTap: () => context.push(AppRoutes.staffList),
                                ),
                                QuickActionButton(
                                  icon: Icons.receipt_long,
                                  label: 'Hóa đơn',
                                  color: AppColors.purple,
                                  backgroundColor: AppColors.purpleBg,
                                  onTap: () => context.push(AppRoutes.managerInvoiceList),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Hoạt động gần đây',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (recentActivities.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20.0),
                                  child: Text(
                                  'Chưa có hoạt động',
                                  textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: recentActivities.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final act = recentActivities[index];
                                  return _buildActivityItem(
                                    icon: act['icon'] as IconData,
                                    iconColor: act['iconColor'] as Color,
                                    iconBg: act['iconBg'] as Color,
                                    title: act['title'] as String,
                                    subtitle: act['subtitle'] as String,
                                    time: _formatRelativeTime(act['createdAt'] as DateTime),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
