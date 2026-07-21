import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

/// UC40 (FID-39): dialog xác nhận vô hiệu hóa tài khoản nhân viên — layout theo
/// wireframe (nút X góc phải, icon cấm nền đỏ nhạt, tiêu đề + mô tả căn giữa,
/// nút "Deactivate Account" rồi "Cancel" xếp dọc full-width).
///
/// Giữ ô "Reason" của luồng hiện tại: lý do được ghi vào `audit_logs` (UC40).
///
/// @returns null nếu người dùng hủy; ngược lại là record kèm lý do (null khi
/// bỏ trống) để nơi gọi truyền thẳng vào API.
Future<({String? reason})?> showDeactivateStaffDialog(BuildContext context) {
  return showDialog<({String? reason})>(
    context: context,
    builder: (_) => const _DeactivateStaffDialog(),
  );
}

class _DeactivateStaffDialog extends StatefulWidget {
  const _DeactivateStaffDialog();

  @override
  State<_DeactivateStaffDialog> createState() => _DeactivateStaffDialogState();
}

class _DeactivateStaffDialogState extends State<_DeactivateStaffDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _reasonController.text.trim();
    Navigator.pop(context, (reason: reason.isEmpty ? null : reason));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.textTertiary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.errorBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_off_outlined,
                    size: 26, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to deactivate this staff account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                AppStrings.msgStaffDeactivateConfirm,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _reasonController,
                maxLength: 250,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Reason (optional) — e.g. Resigned',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: _confirm,
                  child: const Text('Deactivate Account'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
