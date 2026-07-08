import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/coming_soon.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import 'dashboard_screen.dart';

/// Khung điều hướng của Quản lý/Chủ tòa nhà — bottom nav 5 tab theo thiết kế
/// (Trang chủ · Căn hộ · Quản lý · Thông báo · Báo cáo).
/// Tab thuộc module chưa triển khai hiển thị màn "Sắp ra mắt".
class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int _index = 0;

  static const _tabs = [
    AppBottomNavItem(icon: Icons.home, label: 'Trang chủ'),
    AppBottomNavItem(icon: Icons.apartment, label: 'Căn hộ'),
    AppBottomNavItem(icon: Icons.groups, label: 'Quản lý'),
    AppBottomNavItem(icon: Icons.notifications, label: 'Thông báo'),
    AppBottomNavItem(icon: Icons.bar_chart, label: 'Báo cáo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardTab(),
          _ComingSoonTab(
            title: 'Căn hộ',
            child: ComingSoon(
              icon: Icons.apartment,
              title: 'Quản lý căn hộ',
              moduleNote: 'sẽ có ở Module 6 (Apartment Management)',
            ),
          ),
          _ManagementHubTab(),
          _ComingSoonTab(
            title: 'Thông báo',
            child: ComingSoon(
              icon: Icons.notifications,
              title: 'Thông báo & Bảng tin',
              moduleNote: 'sẽ có ở Module 5 (Communication)',
            ),
          ),
          _ComingSoonTab(
            title: 'Báo cáo',
            child: ComingSoon(
              icon: Icons.bar_chart,
              title: 'Báo cáo & Thống kê',
              moduleNote: 'sẽ có ở Module 7 (Dashboard)',
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: _tabs,
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// Tab bọc màn "Sắp ra mắt" với header gradient đồng bộ.
class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GradientHeader(title: title),
        Expanded(child: child),
      ],
    );
  }
}

/// Tab "Quản lý" — hub các mục quản lý (màn 04 dẫn vào từ đây).
class _ManagementHubTab extends ConsumerWidget {
  const _ManagementHubTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        GradientHeader(
          title: 'Quản lý',
          subtitle: 'Nhân sự & cư dân của tòa nhà',
          actions: [
            HeaderIconButton(
              icon: Icons.logout,
              tooltip: 'Đăng xuất',
              onTap: () => ref.read(authNotifierProvider.notifier).logout(),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              AppCard(
                onTap: () => context.push(AppRoutes.staffList),
                child: const _HubRow(
                  icon: Icons.engineering,
                  iconBg: AppColors.infoBg,
                  iconColor: AppColors.primary,
                  title: 'Nhân viên vận hành',
                  subtitle: 'Bảo vệ, lao công, kỹ thuật viên',
                  trailing: Icon(Icons.chevron_right,
                      color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                child: _HubRow(
                  icon: Icons.people,
                  iconBg: AppColors.successBg,
                  iconColor: AppColors.success,
                  title: 'Cư dân',
                  subtitle: 'Hồ sơ thuê, người ở ghép',
                  trailing: StatusBadge.info('Module 2'),
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                child: _HubRow(
                  icon: Icons.description,
                  iconBg: AppColors.warningBg,
                  iconColor: AppColors.warning,
                  title: 'Hợp đồng',
                  subtitle: 'Thời hạn thuê, gia hạn lưu trú',
                  trailing: StatusBadge.info('Module 2'),
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                child: _HubRow(
                  icon: Icons.receipt_long,
                  iconBg: AppColors.purpleBg,
                  iconColor: AppColors.purple,
                  title: 'Hóa đơn & Thu tiền',
                  subtitle: 'Chỉ số điện nước, thanh toán',
                  trailing: StatusBadge.info('Module 3'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HubRow extends StatelessWidget {
  const _HubRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}
