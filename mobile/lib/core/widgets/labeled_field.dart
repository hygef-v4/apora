import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Nhãn đặt phía trên ô nhập (chuẩn wireframe các màn form).
/// Dùng trực tiếp khi màn tự sắp xếp khoảng cách; còn muốn gói cả nhãn lẫn ô
/// nhập thì dùng [LabeledField].
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Nhãn + ô nhập gộp sẵn khoảng cách chuẩn (label nằm trên ô nhập).
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: FieldLabel(label),
        ),
        child,
      ],
    );
  }
}
