import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth_profile/providers/auth_notifier.dart';
import '../constants/app_colors.dart';

/// Header gradient navy -> blue (chuẩn mọi màn hình trong thiết kế).
/// Slot: [title]/[subtitle] hoặc [titleWidget] tự do, [actions] là các nút
/// 36x36 nền mờ, [bottom] cho search bar/nội dung thêm, [leading] nút back.
class GradientHeader extends ConsumerWidget {
  const GradientHeader({
    super.key,
    this.title,
    this.subtitle,
    this.titleWidget,
    this.actions = const [],
    this.bottom,
    this.showBack = false,
    this.centerTitle = false,
  });

  final String? title;
  final String? subtitle;
  final Widget? titleWidget;
  final List<Widget> actions;
  final Widget? bottom;
  final bool showBack;

  /// Tiêu đề căn giữa (các màn theo wireframe: Profile, Change Password...).
  /// Chừa khoảng trống đối xứng với nút back để chữ nằm đúng giữa màn.
  final bool centerTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final isAdminOrOwner = user != null &&
        (user.roles.contains('MANAGER') || user.roles.contains('LANDLORD'));
    final isStaff = user != null &&
        (user.roles.contains('SECURITY_GUARD') ||
            user.roles.contains('JANITOR') ||
            user.roles.contains('TECHNICIAN'));

    return Container(
      decoration: isAdminOrOwner
          ? const BoxDecoration(gradient: AppColors.headerGradient)
          : isStaff
              ? const BoxDecoration(gradient: AppColors.staffGradient)
              : const BoxDecoration(gradient: AppColors.residentGradient),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showBack)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: HeaderIconButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              Expanded(
                child: titleWidget ??
                    Column(
                      crossAxisAlignment: centerTitle
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            textAlign: centerTitle ? TextAlign.center : null,
                            style: TextStyle(
                              fontSize: centerTitle ? 17 : 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              textAlign: centerTitle ? TextAlign.center : null,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: .6),
                              ),
                            ),
                          ),
                      ],
                    ),
              ),
              ...actions.map(
                (a) => Padding(padding: const EdgeInsets.only(left: 8), child: a),
              ),
              // Chừa chỗ đối xứng nút back / action để tiêu đề nằm đúng giữa.
              if (centerTitle && showBack && actions.isEmpty)
                const SizedBox(width: 48),
              if (centerTitle && !showBack && actions.isNotEmpty)
                const SizedBox(width: 44),
            ],
          ),
          if (bottom != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: bottom!),
        ],
      ),
    );
  }
}

/// Nút icon 36x36 nền trắng mờ trong header (chuẩn thiết kế).
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({super.key, required this.icon, this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

/// Search bar nền mờ đặt trong header (như màn 04 "Cư dân").
class HeaderSearchBar extends StatelessWidget {
  const HeaderSearchBar({super.key, required this.hint, this.onChanged});

  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          icon: Icon(Icons.search,
              size: 16, color: Colors.white.withValues(alpha: .7)),
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: .5),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
