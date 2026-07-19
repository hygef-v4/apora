import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../providers/auth_notifier.dart';
import '../widgets/logout_confirm.dart';

/// Đổi mật khẩu khi đã đăng nhập.
/// BR-01: bị ép vào màn này khi đăng nhập lần đầu bằng mật khẩu mặc định
/// (router chặn mọi route khác cho tới khi đổi xong).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Vào màn từ Profile (không bị ép) -> đổi xong quay về màn trước;
    // flow BR-01 (ép đổi mật khẩu mặc định) -> về home theo role.
    final wasForced = ref.read(authNotifierProvider).mustChangePassword;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authNotifierProvider.notifier).changePassword(
            _oldPasswordController.text,
            _newPasswordController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công.')),
      );
      if (!wasForced && context.canPop()) {
        context.pop();
      } else {
        final roles = ref.read(authNotifierProvider).roles;
        context.go(homePathForRoles(roles));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(mapDioError(e))));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mustChange = ref.watch(
      authNotifierProvider.select((s) => s.mustChangePassword),
    );

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Đổi mật khẩu',
            subtitle: mustChange
                ? 'Bắt buộc trước khi tiếp tục sử dụng'
                : 'Cập nhật mật khẩu đăng nhập',
            // BR-01: không cho back khi đang bị ép đổi mật khẩu mặc định
            showBack: !mustChange,
            actions: [
              if (mustChange)
                HeaderIconButton(
                  icon: Icons.logout,
                  tooltip: 'Đăng xuất',
                  // UC02: hỏi xác nhận trước khi đăng xuất (FID-02)
                  onTap: () => confirmAndLogout(context, ref),
                ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (mustChange)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: AppColors.warning),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppStrings.msgChangePasswordFirstLogin,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _oldPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Mật khẩu hiện tại',
                              prefixIcon: Icon(Icons.lock_open, size: 20),
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty)
                                    ? AppStrings.msgFieldRequired
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Mật khẩu mới',
                              helperText:
                                  'Tối thiểu 8 ký tự, gồm 1 chữ hoa và 1 chữ số.',
                              prefixIcon: Icon(Icons.lock, size: 20),
                            ),
                            // BR-09 validate client + chặn sớm trùng mật khẩu cũ
                            validator: (value) {
                              final complexityError =
                                  Validators.passwordComplexity(value);
                              if (complexityError != null) return complexityError;
                              if (value == _oldPasswordController.text) {
                                return AppStrings.msgSamePassword;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Xác nhận mật khẩu mới',
                              prefixIcon: Icon(Icons.lock_outline, size: 20),
                            ),
                            validator: (value) =>
                                value != _newPasswordController.text
                                    ? AppStrings.msgPasswordMismatch
                                    : null,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Xác nhận'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
