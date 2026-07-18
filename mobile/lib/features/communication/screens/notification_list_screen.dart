import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../providers/notification_list_provider.dart';
import '../models/notification_model.dart';
import '../../../core/network/dio_client.dart';

/// UC51 - Màn danh sách thông báo.
/// Thiết kế lại theo mockup giao diện cao cấp:
/// - Chia nhóm thông báo theo "HÔM NAY", "HÔM QUA", "TRƯỚC ĐÓ".
/// - Hiển thị badge màu đỏ báo số lượng thông báo mới ở góc trên bên phải header.
/// - Mỗi thẻ thông báo chưa đọc (unread) sẽ có một dải màu viền trái theo từng loại sự kiện.
/// - Các biểu tượng sự kiện được đặt trong khung hình vuông bo tròn 12px có màu nền dịu mắt.
class NotificationListScreen extends ConsumerStatefulWidget {
  const NotificationListScreen({super.key});

  @override
  ConsumerState<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends ConsumerState<NotificationListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationListProvider.notifier).fetchMore();
    }
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  bool _isYesterday(DateTime dt) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsyncValue = ref.watch(notificationListProvider);
    final user = ref.watch(authNotifierProvider).user;
    final isManagerOrLandlord = user?.isManagement == true;

    // Tính số lượng chưa đọc động để hiển thị badge đỏ trên header
    final unreadCount = notificationsAsyncValue.value?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: isManagerOrLandlord
          ? FloatingActionButton(
              onPressed: () => context.push(AppRoutes.announce),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: Column(
        children: [
          GradientHeader(
            title: 'Thông báo',
            showBack: true,
            actions: [
              if (unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount mới',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: notificationsAsyncValue.when(
              data: (notifications) {
                if (notifications.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notificationListProvider);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: _buildEmptyState(),
                        ),
                      ],
                    ),
                  );
                }

                // Nhóm thông báo theo thời gian
                final todayNotifs = notifications.where((n) => _isToday(n.createdAt)).toList();
                final yesterdayNotifs = notifications.where((n) => _isYesterday(n.createdAt)).toList();
                final olderNotifs = notifications.where((n) => !_isToday(n.createdAt) && !_isYesterday(n.createdAt)).toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(notificationListProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      if (todayNotifs.isNotEmpty) ...[
                        _buildSectionHeader('HÔM NAY'),
                        ...todayNotifs.map((n) => _buildNotificationCard(context, n)),
                      ],
                      if (yesterdayNotifs.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSectionHeader('HÔM QUA'),
                        ...yesterdayNotifs.map((n) => _buildNotificationCard(context, n)),
                      ],
                      if (olderNotifs.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSectionHeader('TRƯỚC ĐÓ'),
                        ...olderNotifs.map((n) => _buildNotificationCard(context, n)),
                      ],
                      if (ref.read(notificationListProvider.notifier).isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(mapDioError(error), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          ref.invalidate(notificationListProvider);
                        },
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF94A3B8), // slate-400
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationModel notif) {
    // Cấu hình biểu tượng & màu sắc dựa trên type
    IconData icon;
    Color iconColor;
    Color iconBgColor;
    Color borderAccentColor;

    switch (notif.type) {
      case 'INVOICE':
      case 'PAYMENT':
        icon = Icons.credit_card_outlined;
        iconColor = const Color(0xFF2563EB); // Xanh dương
        iconBgColor = const Color(0xFFEFF6FF);
        borderAccentColor = const Color(0xFF3B82F6);
        break;
      case 'TICKET':
      case 'TASK':
        icon = Icons.build_outlined;
        iconColor = const Color(0xFFDC2626); // Đỏ
        iconBgColor = const Color(0xFFFEF2F2);
        borderAccentColor = const Color(0xFFEF4444);
        break;
      case 'EXTENSION':
      case 'CONTRACT':
        icon = Icons.description_outlined;
        iconColor = const Color(0xFFD97706); // Cam
        iconBgColor = const Color(0xFFFFFBEB);
        borderAccentColor = const Color(0xFFF59E0B);
        break;
      case 'ROOMMATE':
        icon = Icons.home_outlined;
        iconColor = const Color(0xFF16A34A); // Xanh lá
        iconBgColor = const Color(0xFFF0FDF4);
        borderAccentColor = const Color(0xFF10B981);
        break;
      default:
        icon = Icons.analytics_outlined;
        iconColor = const Color(0xFF4F46E5); // Indigo
        iconBgColor = const Color(0xFFEEF2FF);
        borderAccentColor = const Color(0xFF6366F1);
    }

    final border = !notif.isRead
        ? Border(left: BorderSide(color: borderAccentColor, width: 4))
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
          border: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            context.push(AppRoutes.notificationDetail, extra: notif);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        notif.body,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.textTertiary),
          SizedBox(height: 16),
          Text(
            'Chưa có thông báo nào',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
