import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class FilterPill<T> {
  const FilterPill({required this.value, required this.label, this.color});

  final T value;
  final String label;

  /// Màu chữ khi CHƯA chọn (thiết kế: pill "Đang thuê" chữ xanh lá...).
  final Color? color;
}

/// Hàng pill lọc cuộn ngang: chọn = nền navy chữ trắng,
/// chưa chọn = nền trắng viền #E2E8F0 (chuẩn màn 02).
class FilterPills<T> extends StatelessWidget {
  const FilterPills({
    super.key,
    required this.pills,
    required this.selected,
    required this.onSelected,
  });

  final List<FilterPill<T>> pills;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: pills.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pill = pills[index];
          final isSelected = pill.value == selected;
          return Material(
            color: isSelected ? AppColors.navy : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
              side: isSelected
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.border, width: 1.5),
            ),
            child: InkWell(
              onTap: () => onSelected(pill.value),
              borderRadius: BorderRadius.circular(100),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Text(
                  pill.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (pill.color ?? AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
