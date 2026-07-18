import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Ô thống kê (màn 01 Dashboard): label uppercase nhỏ + giá trị to + caption.
/// [highlight] = true dùng nền gradient xanh (như ô "DOANH THU").
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
    this.captionColor,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;
  final Color? captionColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlight ? null : AppColors.surface,
        gradient: highlight ? AppColors.headerGradient : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : AppColors.cardShadow,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
              color: highlight
                  ? Colors.white.withValues(alpha: .65)
                  : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1,
              color: highlight ? Colors.white : (valueColor ?? AppColors.textPrimary),
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 5),
            Text(
              caption!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: highlight
                    ? Colors.white.withValues(alpha: .6)
                    : (captionColor ?? AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
