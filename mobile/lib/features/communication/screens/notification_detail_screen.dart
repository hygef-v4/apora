import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/notification_model.dart';
import '../repositories/communication_repository.dart';
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
        ref.read(communicationRepositoryProvider).markAsRead(widget.notification.id).then((_) {
          ref.invalidate(notificationListProvider);
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          GradientHeader(
            title: 'Chi tiết thông báo',
            showBackButton: true,
            onBack: () => context.pop(),
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
                          color: iconColor.withOpacity(0.1),
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
                          // Navigate to invoice details (TODO)
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
                          // Navigate to ticket details (TODO)
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
