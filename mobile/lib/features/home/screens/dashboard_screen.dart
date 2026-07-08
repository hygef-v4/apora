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
import '../../management/models/staff_stats.dart';
import '../../management/providers/staff_notifier.dart';

/// Tab Trang chủ của Quản lý — theo màn 01 "Dashboard" trong thiết kế.
/// Stat cards dùng số liệu THẬT từ API staff (Module 8);
/// số liệu căn hộ/doanh thu sẽ thay vào khi có Module 6/7.
class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  static const _weekdays = [
    'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật',
  ];

  String get _today {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${now.day} tháng ${now.month} · ${now.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final stats = ref.watch(staffDirectoryProvider).value?.stats ??
        StaffStats.empty;

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
                child: InitialsAvatar(
                  name: user?.fullName ?? '?',
                  imageUrl: user?.avatarUrl,
                  size: 44,
                  square: true,
                ),
              ),
            ],
          ),
          bottom: const SizedBox(height: 12), // chừa chỗ cho grid đè lên header
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(staffDirectoryProvider.notifier).refresh(),
            child: ListView(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Column(
                    children: [
                      // Lưới thống kê 2x2 (số liệu thật từ Module 8)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Tổng nhân viên',
                              value: '${stats.total}',
                              caption: 'Chung cư Apora',
                              captionColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Đang làm việc',
                              value: '${stats.active}',
                              valueColor: AppColors.success,
                              caption: 'Nhân sự sẵn sàng',
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
                              label: 'Đã nghỉ',
                              value: '${stats.inactive}',
                              valueColor: AppColors.primary,
                              caption: 'Tài khoản vô hiệu',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatCard(
                              label: 'Việc đang mở',
                              value: '${stats.openTasks}',
                              caption: 'Chờ xử lý',
                              highlight: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Thao tác nhanh (màn 01)
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
                                  icon: Icons.person_add_alt_1,
                                  label: 'Thêm NV',
                                  color: AppColors.primary,
                                  backgroundColor: AppColors.infoBg,
                                  onTap: () => context.push(AppRoutes.staffCreate),
                                ),
                                QuickActionButton(
                                  icon: Icons.groups,
                                  label: 'Nhân viên',
                                  color: AppColors.success,
                                  backgroundColor: AppColors.successBg,
                                  onTap: () => context.push(AppRoutes.staffList),
                                ),
                                QuickActionButton(
                                  icon: Icons.person,
                                  label: 'Hồ sơ',
                                  color: AppColors.warning,
                                  backgroundColor: AppColors.warningBg,
                                  onTap: () => context.push(AppRoutes.profile),
                                ),
                                QuickActionButton(
                                  icon: Icons.lock_reset,
                                  label: 'Đổi MK',
                                  color: AppColors.purple,
                                  backgroundColor: AppColors.purpleBg,
                                  onTap: () =>
                                      context.push(AppRoutes.changePassword),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Hoạt động gần đây (dữ liệu thật sẽ có ở Module 5)
                      const AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hoạt động gần đây',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 14),
                            Center(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Chưa có hoạt động — bảng tin & thông báo sẽ có ở Module 5.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
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
}
