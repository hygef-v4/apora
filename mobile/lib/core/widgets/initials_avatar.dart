import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Avatar chữ cái đầu, nền gradient xoay vòng theo tên (như màn 04).
/// [square] = true dùng ô vuông bo góc (kiểu avatar header màn 01).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 46,
    this.square = false,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool square;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        square ? BorderRadius.circular(size * .3) : BorderRadius.circular(999);
    final colors = AppColors
        .avatarGradients[name.hashCode.abs() % AppColors.avatarGradients.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: imageUrl == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              )
            : null,
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl == null
          ? Text(
              _initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * .3,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}
