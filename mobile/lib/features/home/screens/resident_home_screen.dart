import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/coming_soon.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../../billing/screens/invoice_list_screen.dart';
import '../../ticket/screens/ticket_list_screen.dart';
import '../../chat/screens/chat_screen.dart';


/// Khung trang chủ Cư dân — theo màn 10 trong thiết kế.
/// Bottom nav: Trang chủ · Hóa đơn · Yêu cầu · Tin nhắn · Cá nhân.
/// Nội dung thật sẽ nối khi làm Module 3 (Billing), 4 (Ticket), 5 (Chat).
class ResidentHomeScreen extends ConsumerStatefulWidget {
  const ResidentHomeScreen({super.key});

  @override
  ConsumerState<ResidentHomeScreen> createState() => _ResidentHomeScreenState();
}

class _ResidentHomeScreenState extends ConsumerState<ResidentHomeScreen> {
  int _index = 0;

  static const _tabs = [
    AppBottomNavItem(icon: Icons.home, label: 'Trang chủ'),
    AppBottomNavItem(icon: Icons.receipt_long, label: 'Hóa đơn'),
    AppBottomNavItem(icon: Icons.build, label: 'Yêu cầu'),
    AppBottomNavItem(icon: Icons.chat_bubble, label: 'Hỗ trợ'),
    AppBottomNavItem(icon: Icons.person, label: 'Cá nhân'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          // Tab Trang chủ
          Column(
            children: [
              GradientHeader(
                titleWidget: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.profile),
                      child: InitialsAvatar(
                        name: user?.fullName ?? 'N A',
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xin chào,',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .7),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            user?.fullName ?? 'Cư dân',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  HeaderIconButton(
                    icon: Icons.notifications_none,
                    onTap: () => context.push(AppRoutes.notifications),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    // UC06: hợp đồng & thời hạn lưu trú của cư dân
                    AppCard(
                      onTap: () => context.push(AppRoutes.myContract),
                      child: const _SectionPreview(
                        icon: Icons.description,
                        iconBg: AppColors.warningBg,
                        iconColor: AppColors.warning,
                        title: 'Hợp đồng của tôi',
                        note: 'Thời hạn lưu trú & yêu cầu gia hạn',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const AppCard(
                      child: _SectionPreview(
                        icon: Icons.receipt_long,
                        iconBg: AppColors.infoBg,
                        iconColor: AppColors.primary,
                        title: 'Hóa đơn tháng này',
                        note: 'Xem & thanh toán VietQR — sẽ có ở Module 3',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const AppCard(
                      child: _SectionPreview(
                        icon: Icons.build,
                        iconBg: AppColors.warningBg,
                        iconColor: AppColors.warning,
                        title: 'Yêu cầu sửa chữa',
                        note: 'Báo sự cố kèm ảnh — mở ở tab "Yêu cầu"',
                      ),
                    ),
                    const SizedBox(height: 10),
                    const AppCard(
                      child: _SectionPreview(
                        icon: Icons.campaign,
                        iconBg: AppColors.successBg,
                        iconColor: AppColors.success,
                        title: 'Bảng tin tòa nhà',
                        note: 'Thông báo từ Ban quản lý — sẽ có ở Module 5',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Các tab module sau
          const InvoiceListScreen(),

          // Tab Yêu cầu -> danh sách sự cố của cư dân (UC18/UC19, nhúng nên không back)
          const TicketListScreen(),
          
          // Tab Hỗ trợ (Live Chat - UC28)
          const ChatScreen(
            title: 'Hỗ trợ',
            subtitle: 'Trò chuyện và nhận hỗ trợ từ BQL',
            showBack: false,
          ),
          
          // Tab Cá nhân
          Column(
            children: [
              GradientHeader(
                title: 'Cá nhân',
                actions: [
                  HeaderIconButton(
                    icon: Icons.logout,
                    tooltip: 'Đăng xuất',
                    onTap: () =>
                        ref.read(authNotifierProvider.notifier).logout(),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(14),
                  children: [
                    AppCard(
                      onTap: () => context.push(AppRoutes.profile),
                      child: const Row(
                        children: [
                          Icon(Icons.person, color: AppColors.primary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Hồ sơ cá nhân',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppCard(
                      onTap: () => context.push(AppRoutes.changePassword),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_reset, color: AppColors.primary),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Đổi mật khẩu',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: AppColors.textTertiary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

class _SectionPreview extends StatelessWidget {
  const _SectionPreview({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.note,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String note;

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
                note,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResidentComingSoon extends StatelessWidget {
  const _ResidentComingSoon({
    required this.title,
    required this.icon,
    required this.note,
  });

  final String title;
  final IconData icon;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GradientHeader(title: title),
        Expanded(
          child: ComingSoon(icon: icon, title: title, moduleNote: note),
        ),
      ],
    );
  }
}
