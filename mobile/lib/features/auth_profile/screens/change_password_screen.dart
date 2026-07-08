import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../providers/auth_notifier.dart';

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
      // mustChangePassword đã tắt -> router tự đưa về home theo role
      final roles = ref.read(authNotifierProvider).roles;
      context.go(homePathForRoles(roles));
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
      appBar: AppBar(
        title: const Text('Đổi mật khẩu'),
        // BR-01: không cho back khi đang bị ép đổi mật khẩu mặc định
        automaticallyImplyLeading: !mustChange,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mustChange)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      AppStrings.msgChangePasswordFirstLogin,
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                TextFormField(
                  controller: _oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    prefixIcon: Icon(Icons.lock_open),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? AppStrings.msgFieldRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu mới',
                    helperText: 'Tối thiểu 8 ký tự, gồm 1 chữ hoa và 1 chữ số.',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? AppStrings.msgFieldRequired
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Xác nhận mật khẩu mới',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value != _newPasswordController.text
                      ? AppStrings.msgPasswordMismatch
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Xác nhận'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
