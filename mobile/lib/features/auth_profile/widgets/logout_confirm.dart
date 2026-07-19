import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../providers/auth_notifier.dart';

/// UC02 (FID-02): dialog xác nhận đăng xuất - thành phần BẮT BUỘC theo SRS
/// (main flow bước 2-3). Bấm Hủy thì ở lại màn hiện tại (AT1); xác nhận mới
/// gọi logout (revoke FCM token + xóa phiên local, router tự về Login).
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Đăng xuất'),
      content: const Text(AppStrings.msgLogoutConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(authNotifierProvider.notifier).logout();
  }
}
