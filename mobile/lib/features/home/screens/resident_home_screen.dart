import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../../billing/providers/billing_provider.dart';
import '../../billing/screens/invoice_list_screen.dart';
import '../../ticket/screens/ticket_list_screen.dart';
import '../../chat/screens/chat_screen.dart';

/// Khung trang chủ Cư dân — theo thiết kế mới.
/// Bottom nav: Trang chủ · Hóa đơn · Yêu cầu · Tin nhắn · Cá nhân.
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
    AppBottomNavItem(icon: Icons.build, label: 'Bảo trì'),
    AppBottomNavItem(icon: Icons.chat_bubble, label: 'Tin nhắn'),
  ];

  void _switchTab(int index) {
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: [
          // Tab Trang chủ
          _HomeTab(onSwitchTab: _switchTab),
          
          // Tab Hóa đơn
          const InvoiceListScreen(),

          // Tab Bảo trì (Yêu cầu)
          const TicketListScreen(),
          
          // Tab Tin nhắn (Hỗ trợ)
          const ChatScreen(
            title: 'Hỗ trợ',
            subtitle: 'Trò chuyện và nhận hỗ trợ từ BQL',
            showBack: false,
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: _tabs,
        currentIndex: _index,
        onTap: _switchTab,
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.onSwitchTab});
  
  final void Function(int) onSwitchTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final firstName = user?.fullName.split(' ').last ?? 'Cư dân';
    
    final billingState = ref.watch(billingProvider);
    final unpaidInvoices = billingState.invoices.where((inv) => inv.status == 'UNPAID' || inv.status == 'PARTIAL').toList();
    // Sắp xếp tăng dần theo MonthYear (định dạng MM/yyyy) để lấy hoá đơn cũ nhất
    unpaidInvoices.sort((a, b) {
      try {
        final aParts = a.monthYear.split('/');
        final bParts = b.monthYear.split('/');
        final aMonth = int.parse(aParts[0]);
        final aYear = int.parse(aParts[1]);
        final bMonth = int.parse(bParts[0]);
        final bYear = int.parse(bParts[1]);
        
        if (aYear != bYear) {
          return aYear.compareTo(bYear);
        }
        return aMonth.compareTo(bMonth);
      } catch (_) {
        return a.id.compareTo(b.id);
      }
    });
    final hasUnpaid = unpaidInvoices.isNotEmpty;
    final currentInvoice = hasUnpaid ? unpaidInvoices.first : null;

    String formatCurrency(double amount) {
      final format = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
      return format.format(amount);
    }

    return Stack(
      children: [
        // Blue Header Background
        Container(
          height: 240,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF149EE7), // Màu xanh dương sáng theo UI
          ),
        ),
        // Scrollable content overlapping the header
        SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 10, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Căn hộ A101 · Apora Tower',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chào $firstName 👋',
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.profile),
                      child: InitialsAvatar(
                        name: user?.fullName ?? 'N A',
                        size: 46,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Đăng xuất',
                      onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
                    ),
                  ],
                ),
              ),
              // 1. Billing Card
              if (hasUnpaid && currentInvoice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2336), // Dark navy from image
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Color(0x2A000000), blurRadius: 12, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Hoá đơn tháng ${currentInvoice.monthYear}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFBE6A1), // Yellow badge
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Chưa thanh toán',
                                style: TextStyle(color: Color(0xFF8B6400), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          formatCurrency(currentInvoice.totalAmount),
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hạn: ${DateFormat('dd/MM/yyyy').format(currentInvoice.dueDate)}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (currentInvoice == null) return;
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                              try {
                                final paymentUrl = await ref
                                    .read(billingProvider.notifier)
                                    .getPaymentLink(currentInvoice.id);
                                if (context.mounted) {
                                  Navigator.of(context).pop(); // Đóng loading dialog
                                  context.push(
                                    '/invoices/pay',
                                    extra: {
                                      'invoiceId': currentInvoice.id,
                                      'paymentUrl': paymentUrl,
                                      'totalAmount': currentInvoice.totalAmount,
                                    },
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.of(context).pop(); // Đóng loading dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Lỗi tải link thanh toán: $e')),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF12A8F1), // Bright blue button
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: const Text('Thanh toán ngay', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.successBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_circle, color: AppColors.success),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Không có hoá đơn chưa thanh toán',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              
              // 3. Notifications Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  radius: 20,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Thông báo từ BQL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            GestureDetector(
                              onTap: () => context.push(AppRoutes.notifications),
                              child: const Text('Xem tất cả', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      const _NotificationItem(
                        icon: Icons.water_drop, iconColor: Color(0xFF3B82F6), iconBg: Color(0xFFEFF6FF),
                        title: 'Cúp nước bảo trì', time: 'Thứ 7, 28/6 từ 8h-11h sáng', duration: '1 giờ'
                      ),
                      const Divider(height: 1, indent: 64, endIndent: 20, color: AppColors.divider),
                      const _NotificationItem(
                        icon: Icons.celebration, iconColor: Color(0xFF10B981), iconBg: Color(0xFFECFDF5),
                        title: 'Tiệc cư dân tháng 7', time: 'Sảnh tầng trệt - 06/07 19h', duration: '2 ngày'
                      ),
                      const SizedBox(height: 12),
                    ],
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

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.time,
    required this.duration,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String time;
  final String duration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            duration,
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
