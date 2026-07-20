import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Các khối bố cục dùng chung cho 4 màn Module 2, dựng theo wireframe
/// trong SRS: nhãn nhóm chữ hoa có kẻ dưới, dòng "nhãn trái - giá trị phải".
/// Chỉ lấy BỐ CỤC từ wireframe; màu vẫn dùng bảng màu APORA (AppColors).

/// Nhãn nhóm chữ hoa + đường kẻ dưới.
class SpecSectionHeader extends StatelessWidget {
  const SpecSectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, thickness: 1, color: AppColors.border),
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Một dòng "nhãn trái - giá trị phải". Dùng [SpecDetailRow.widget] khi giá
/// trị là badge trạng thái thay vì chuỗi.
class SpecDetailRow extends StatelessWidget {
  const SpecDetailRow({super.key, required this.label, required this.value})
      : child = null;

  const SpecDetailRow.widget({
    super.key,
    required this.label,
    required this.child,
  }) : value = null;

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          child ??
              Text(
                value!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
        ],
      ),
    );
  }
}

/// Nhãn của một trường nhập, kèm dấu * đỏ khi bắt buộc (theo wireframe).
class SpecFieldLabel extends StatelessWidget {
  const SpecFieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
      ),
    );
  }
}
