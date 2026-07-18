import 'package:flutter/material.dart';

/// Bảng màu APORA — trích từ file thiết kế Apora.dc.html (24 màn hình).
class AppColors {
  AppColors._();

  // Chủ đạo
  static const Color primary = Color(0xFF2563EB);
  static const Color navy = Color(0xFF1E3A5F);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;

  /// Gradient header: 160deg navy -> blue (dùng khắp các màn).
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, primary],
  );

  // Chữ
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Trạng thái (text + nền tint đi cặp)
  static const Color success = Color(0xFF059669);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF9C3);
  static const Color info = primary;
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleBg = Color(0xFFEDE9FE);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);

  // Viền / phân cách / icon nhạt
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color inactive = Color(0xFFCBD5E1);

  /// Các gradient avatar initials (xoay vòng theo hash tên — như màn 04).
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF2563EB), Color(0xFF1E3A5F)],
    [Color(0xFF059669), Color(0xFF065F46)],
    [Color(0xFF7C3AED), Color(0xFF4C1D95)],
    [Color(0xFF0EA5E9), Color(0xFF0369A1)],
    [Color(0xFFF59E0B), Color(0xFF92400E)],
    [Color(0xFFEF4444), Color(0xFF991B1B)],
  ];

  /// Bóng đổ card chuẩn thiết kế.
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
}
