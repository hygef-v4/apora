import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/auth_notifier.dart';

/// UC02 (FID-02): dialog xác nhận đăng xuất - thành phần BẮT BUỘC theo SRS
/// (main flow bước 2-3). Bấm Cancel thì ở lại màn hiện tại (AT1); xác nhận mới
/// gọi logout (revoke FCM token + xóa phiên local, router tự về Login).
///
/// Layout bám wireframe: icon ở giữa -> tiêu đề -> mô tả -> 2 nút full-width
/// xếp dọc (xác nhận trên, huỷ dưới). Style theo design system Apora.
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon đăng xuất trong ô bo tròn nền đỏ nhạt
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.logout,
                    size: 30, color: AppColors.error),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Are you sure you want to log out?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You will need to re-authenticate to access your repair '
              'requests and unit schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Yes, Logout'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
  if (confirmed == true) {
    await ref.read(authNotifierProvider.notifier).logout();
  }
}
