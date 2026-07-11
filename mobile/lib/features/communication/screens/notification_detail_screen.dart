import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/notification_model.dart';
import '../providers/notification_detail_provider.dart';
import '../providers/notification_list_provider.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  final NotificationModel notification;

  const NotificationDetailScreen({super.key, required this.notification});

  @override
  ConsumerState<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends ConsumerState<NotificationDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Đánh dấu đã đọc khi mở chi tiết
    if (!widget.notification.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(notificationDetailProvider.notifier)
           .markAsRead(widget.notification.id)
           .then((_) {
             final status = ref.read(notificationDetailProvider);
             if (status == NotificationDetailStatus.success) {
               ref.invalidate(notificationListProvider);
             }
           });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(notificationDetailProvider);

    // Xử lý AT1: Bị xóa / 404
    if (status == NotificationDetailStatus.notFound) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const GradientHeader(
              title: 'Lỗi',
              showBack: true,
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      const Text(
                        'This notification is no longer available or has been removed by the management.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
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

    // Choose icon based on type (same as list)
    IconData icon;
    Color iconColor;
    
    switch (widget.notification.type) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(
            title: 'Chi tiết thông báo',
            showBack: true,
          ),
          
          // AT2: Cảnh báo Offline Mode
          if (status == NotificationDetailStatus.networkError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.warning.withValues(alpha: 0.1),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline mode: Cannot load full details or mark as read. Please check your connection.',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.notification.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(widget.notification.createdAt),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 24),
                  
                  Text(
                    widget.notification.body,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Optional Action Button depending on type
                  if (widget.notification.type == 'INVOICE')
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tính năng xem hóa đơn đang phát triển')),
                          );
                        },
                        icon: const Icon(Icons.payment),
                        label: const Text('Xem hóa đơn'),
                      ),
                    ),
                  if (widget.notification.type == 'TICKET')
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tính năng xem sự cố đang phát triển')),
                          );
                        },
                        icon: const Icon(Icons.build),
                        label: const Text('Xem yêu cầu sửa chữa'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

