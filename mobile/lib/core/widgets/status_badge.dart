import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Badge chip: nền tint + chữ màu, bo 8, 10px w700 (chuẩn thiết kế).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    required this.backgroundColor,
  });

  final String text;
  final Color color;
  final Color backgroundColor;

  /// Badge xanh lá "Đang..." (success).
  factory StatusBadge.success(String text) => StatusBadge(
      text: text, color: AppColors.success, backgroundColor: AppColors.successBg);

  /// Badge cam cảnh báo.
  factory StatusBadge.warning(String text) => StatusBadge(
      text: text, color: AppColors.warning, backgroundColor: AppColors.warningBg);

  /// Badge xanh dương thông tin.
  factory StatusBadge.info(String text) => StatusBadge(
      text: text, color: AppColors.info, backgroundColor: AppColors.infoBg);

  /// Badge xám (ngừng hoạt động).
  factory StatusBadge.muted(String text) => StatusBadge(
      text: text,
      color: AppColors.textSecondary,
      backgroundColor: AppColors.divider);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
