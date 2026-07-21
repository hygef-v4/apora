import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../management/screens/dashboard_report_screen.dart';
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
    AppBottomNavItem(icon: Icons.home, label: 'Home'),
    AppBottomNavItem(icon: Icons.groups, label: 'Management'),
    AppBottomNavItem(icon: Icons.bar_chart, label: 'Reports'),
    AppBottomNavItem(icon: Icons.chat, label: 'Support'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const DashboardTab(),
          const _ManagementHubTab(),
          const DashboardReportScreen(),
          const ManagerChatListScreen(),
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

/// Tab "Quản lý" — hub các mục quản lý (màn 04 dẫn vào từ đây).
class _ManagementHubTab extends ConsumerWidget {
  const _ManagementHubTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const GradientHeader(
          title: 'Quản lý',
          subtitle: 'Nhân sự & cư dân của tòa nhà',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 1, 14, 1),
            children: [
              // 1. tài khoản
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
                    iconBg: Color(0xFFEEF2FF),
                    iconColor: Color(0xFF4F46E5),
                    title: 'Quản lý',
                    subtitle: 'Danh sách quản lý viên',
                    trailing: Icon(
                      Icons.chevron_right,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              // 2. căn hộ
              AppCard(
                onTap: () => context.push(AppRoutes.apartmentList),
                child: const _HubRow(
                  icon: Icons.apartment,
                  iconBg: Color(0xFFECFEFF),
                  iconColor: Color(0xFF0891B2),
                  title: 'Căn hộ',
                  subtitle: 'Quản lý căn hộ, check-in, check-out',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 3. thông báo
              AppCard(
                onTap: () => context.push(AppRoutes.notifications),
                child: const _HubRow(
                  icon: Icons.notifications,
                  iconBg: Color(0xFFFFF7ED),
                  iconColor: Color(0xFFF97316),
                  title: 'Thông báo',
                  subtitle: 'Gửi và quản lý thông báo tòa nhà',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 4. duyệt thành viên
              AppCard(
                onTap: () => context.push(AppRoutes.managerRoommates),
                child: const _HubRow(
                  icon: Icons.people,
                  iconBg: Color(0xFFFDF2F8),
                  iconColor: Color(0xFFEC4899),
                  title: 'Duyệt thành viên',
                  subtitle: 'Phê duyệt yêu cầu tạm trú & người ở ghép',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 5. hợp đồng
              AppCard(
                onTap: () => context.push(AppRoutes.contractList),
                child: const _HubRow(
                  icon: Icons.description,
                  iconBg: Color(0xFFFEFCE8),
                  iconColor: Color(0xFFCA8A04),
                  title: 'Hợp đồng',
                  subtitle: 'Danh sách hợp đồng & duyệt gia hạn',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 6. nhân viên vận hành
              AppCard(
                onTap: () => context.push(AppRoutes.staffList),
                child: const _HubRow(
                  icon: Icons.engineering,
                  iconBg: Color(0xFFF0FDF4),
                  iconColor: Color(0xFF22C55E),
                  title: 'Nhân viên',
                  subtitle: 'Bảo vệ, lao công, kỹ thuật viên',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 7. bảo trì
              AppCard(
                onTap: () => context.push(AppRoutes.tickets),
                child: const _HubRow(
                  icon: Icons.build_circle,
                  iconBg: Color(0xFFEFF6FF),
                  iconColor: Color(0xFF3B82F6),
                  title: 'Bảo trì',
                  subtitle: 'Theo dõi yêu cầu sửa chữa của cư dân',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 8. Transaction History
              AppCard(
                onTap: () => context.push(AppRoutes.managerInvoiceList),
                child: const _HubRow(
                  icon: Icons.history,
                  iconBg: AppColors.purpleBg,
                  iconColor: AppColors.purple,
                  title: 'Transaction History',
                  subtitle: 'Lịch sử giao dịch & xác thực thanh toán',
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 9. Input Monthly Bills
              AppCard(
                onTap: () => context.push(AppRoutes.generateBill),
                child: const _HubRow(
                  icon: Icons.post_add,
                  iconBg: Color(0xFFFEF2F2),
                  iconColor: Color(0xFFEF4444),
                  title: 'Input Monthly Bills.',
                  subtitle: 'Nhập chỉ số điện nước & lập hóa đơn định kỳ',
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
