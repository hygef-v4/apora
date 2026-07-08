import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../providers/auth_notifier.dart';

/// UC03: Quên mật khẩu (FID-03) - 2 bước:
/// Bước 1: nhập SĐT -> gửi OTP. Bước 2: nhập OTP + mật khẩu mới.
/// Có nút "Gửi lại OTP" (mã cũ bị vô hiệu, đếm lại 5 phút - BR-08).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _otpSent = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Bước 1 + Resend: yêu cầu gửi OTP.
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage(AppStrings.msgPhoneRequired);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final devOtp =
          await ref.read(authNotifierProvider.notifier).requestOtp(phone);
      setState(() => _otpSent = true);
      // Backend dev mode trả kèm OTP để demo không cần SMS thật
      _showMessage(devOtp != null
          ? '${AppStrings.msgOtpSent} (Dev OTP: $devOtp)'
          : AppStrings.msgOtpSent);
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Bước 2: xác thực OTP + đặt mật khẩu mới.
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authNotifierProvider.notifier).resetPassword(
            _phoneController.text.trim(),
            _otpController.text.trim(),
            _newPasswordController.text,
          );
      _showMessage('Đổi mật khẩu thành công. Vui lòng đăng nhập lại.');
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_otpSent,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại đã đăng ký',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? AppStrings.msgPhoneRequired
                      : null,
                ),
                const SizedBox(height: 16),
                if (!_otpSent)
                  FilledButton(
                    onPressed: _isSubmitting ? null : _sendOtp,
                    child: const Text('Gửi mã OTP'),
                  ),
                if (_otpSent) ...[
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Mã OTP (6 chữ số)',
                      prefixIcon: Icon(Icons.pin),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    validator: (value) => (value == null || value.trim().isEmpty)
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
                    onPressed: _isSubmitting ? null : _resetPassword,
                    child: const Text('Đổi mật khẩu'),
                  ),
                  TextButton(
                    onPressed: _isSubmitting ? null : _sendOtp,
                    child: const Text('Gửi lại OTP'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
