import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/phone_otp_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../providers/auth_notifier.dart';

/// UC03: Quên mật khẩu (FID-03) - 2 bước, OTP qua Firebase Phone Auth (BR-08):
/// Bước 1: nhập SĐT -> backend check tài khoản -> Firebase gửi SMS OTP.
/// Bước 2: nhập OTP + mật khẩu mới -> Firebase xác thực -> backend đổi mật khẩu.
/// Có nút "Gửi lại OTP" (Firebase tự vô hiệu mã cũ khi cấp mã mới).
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

  /// Đếm ngược trước khi được "Gửi lại OTP" - giảm bấm liên tục dính
  /// rate-limit `too-many-requests` của Firebase (khớp timeout 60s của SMS).
  static const int _resendCooldownSeconds = 60;
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendCountdown -= 1);
      if (_resendCountdown <= 0) timer.cancel();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Lỗi OTP từ Firebase đã có message tiếng Việt sẵn; còn lại map lỗi Dio.
  String _errorText(Object e) =>
      e is OtpException ? e.message : mapDioError(e);

  /// Bước 1 + Resend: backend check tài khoản rồi Firebase gửi SMS OTP.
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage(AppStrings.msgPhoneRequired);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authNotifierProvider.notifier).requestOtp(phone);
      setState(() => _otpSent = true);
      _startResendCountdown();
      _showMessage(AppStrings.msgOtpSent);
    } catch (e) {
      _showMessage(_errorText(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Bước 2: Firebase xác thực OTP -> backend đổi mật khẩu.
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
      _showMessage(_errorText(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            title: 'Quên mật khẩu',
            subtitle: 'Khôi phục quyền truy cập qua mã OTP',
            showBack: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AppCard(
                padding: const EdgeInsets.all(20),
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
                          prefixIcon: Icon(Icons.phone, size: 20),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
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
                            prefixIcon: Icon(Icons.pin, size: 20),
                            counterText: '',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
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
                          // BR-09: validate ngay trên client, không chờ server
                          validator: Validators.passwordComplexity,
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
                          onPressed: _isSubmitting ? null : _resetPassword,
                          child: const Text('Đổi mật khẩu'),
                        ),
                        TextButton(
                          onPressed: (_isSubmitting || _resendCountdown > 0)
                              ? null
                              : _sendOtp,
                          child: Text(_resendCountdown > 0
                              ? 'Gửi lại OTP (${_resendCountdown}s)'
                              : 'Gửi lại OTP'),
                        ),
                        // Gõ nhầm SĐT -> quay lại bước 1 sửa, không phải thoát màn
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                    _otpSent = false;
                                    _otpController.clear();
                                  }),
                          child: const Text('Đổi số điện thoại'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
