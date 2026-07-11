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
import '../../communication/screens/notification_list_screen.dart';
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
        children: [
          const DashboardTab(),
          const _ComingSoonTab(
            title: 'Căn hộ',
            child: ComingSoon(
              icon: Icons.apartment,
              title: 'Quản lý căn hộ',
              moduleNote: 'sẽ có ở Module 6 (Apartment Management)',
            ),
          ),
          const _ManagementHubTab(),
          const NotificationListScreen(),
          const _ComingSoonTab(
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
              if (ref
                      .watch(authNotifierProvider)
                      .user
                      ?.roles
                      .contains('LANDLORD') ==
                  true) ...[
                AppCard(
                  onTap: () => context.push(AppRoutes.managerList),
                  child: const _HubRow(
                    icon: Icons.admin_panel_settings,
                    iconBg: AppColors.primary,
                    iconColor: Colors.white,
                    title: 'Tài khoản Quản lý viên',
                    subtitle: 'Danh sách Quản lý viên',
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              AppCard(
                onTap: () => context.push(AppRoutes.staffList),
                child: const _HubRow(
                  icon: Icons.engineering,
                  iconBg: AppColors.infoBg,
                  iconColor: AppColors.primary,
                  title: 'Nhân viên vận hành',
                  subtitle: 'Bảo vệ, lao công, kỹ thuật viên',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
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
                onTap: () => context.push(AppRoutes.managerInvoiceList),
                child: const _HubRow(
                  icon: Icons.receipt_long,
                  iconBg: AppColors.purpleBg,
                  iconColor: AppColors.purple,
                  title: 'Hóa đơn & Thu tiền',
                  subtitle: 'Chỉ số điện nước, thanh toán',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                onTap: () => context.push(AppRoutes.tickets),
                child: const _HubRow(
                  icon: Icons.build_circle,
                  iconBg: AppColors.warningBg,
                  iconColor: AppColors.warning,
                  title: 'Sự cố & Sửa chữa',
                  subtitle: 'Theo dõi yêu cầu sửa chữa của cư dân',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                onTap: () => context.push(AppRoutes.managerRoommates),
                child: const _HubRow(
                  icon: Icons.how_to_reg,
                  iconBg: AppColors.successBg,
                  iconColor: AppColors.success,
                  title: 'Duyệt thành viên',
                  subtitle: 'Xem xét yêu cầu đăng ký tạm trú',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                onTap: () => context.push(AppRoutes.pricingSettings),
                child: const _HubRow(
                  icon: Icons.settings,
                  iconBg: AppColors.infoBg,
                  iconColor: AppColors.info,
                  title: 'Thiết lập đơn giá',
                  subtitle: 'Đơn giá điện, nước, phí quản lý',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
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
