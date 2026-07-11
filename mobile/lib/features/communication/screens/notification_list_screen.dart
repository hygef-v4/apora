import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../providers/notification_list_provider.dart';
import '../models/notification_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final notificationsAsyncValue = ref.watch(notificationListProvider);
    final user = ref.watch(authNotifierProvider).user;
    final isManagerOrLandlord = user?.isManagement == true;
    final isLoadingMore = ref.watch(notificationListProvider.notifier).isLoadingMore;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(notificationListProvider);
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    cacheExtent: 1000,
                    itemCount: notifications.length + (ref.read(notificationListProvider.notifier).isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final notification = notifications[index];
                      return _buildNotificationCard(context, notification);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Lỗi: $error', style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 16),
                    ElevatedButton(
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
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, NotificationModel notif) {
    // Lựa chọn icon dựa trên type
    IconData icon;
    Color iconColor;
    
    switch (notif.type) {
      case 'INVOICE':
      case 'PAYMENT':
        icon = Icons.receipt_long;
        iconColor = AppColors.warning;
        break;
      case 'TICKET':
      case 'TASK':
        icon = Icons.handyman;
        iconColor = AppColors.info;
        break;
      default:
        icon = Icons.campaign;
        iconColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: () {
        context.push(AppRoutes.notificationDetail, extra: notif);
      },
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                          color: notif.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!notif.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif.body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(notif.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
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
