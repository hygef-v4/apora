import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/phone_otp_service.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/labeled_field.dart';
import '../providers/auth_notifier.dart';

/// UC03: Quên mật khẩu (FID-03) - 2 bước, OTP qua Firebase Phone Auth (BR-08):
/// Bước 1: nhập SĐT -> backend check tài khoản -> Firebase gửi SMS OTP.
/// Bước 2: nhập OTP + mật khẩu mới -> Firebase xác thực -> backend đổi mật khẩu.
/// Có nút "Resend OTP" (Firebase tự vô hiệu mã cũ khi cấp mã mới).
///
/// Layout bám wireframe: header có back + tiêu đề căn giữa -> banner minh hoạ
/// -> câu hướng dẫn -> label nằm trên ô nhập -> nút chính ghim đáy màn ->
/// link "Back to Login". Style theo design system Apora.
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

  /// Đếm ngược trước khi được "Resend OTP" - giảm bấm liên tục dính
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

  /// Lỗi OTP từ Firebase đã có message sẵn; còn lại map lỗi Dio.
  String _errorText(Object e) =>
      e is OtpException ? e.message : mapDioError(e);

  /// Bước 1 + Resend: backend check tài khoản rồi Firebase gửi SMS OTP.
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('Please enter your phone number.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(authNotifierProvider.notifier).requestOtp(phone);
      setState(() => _otpSent = true);
      _startResendCountdown();
      _showMessage('An OTP code has been sent to your phone.');
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
      _showMessage('Password updated. Please log in again.');
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header: back trái + tiêu đề căn giữa (layout wireframe)
          const GradientHeader(
            title: 'Forgot Password',
            centerTitle: true,
            showBack: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner minh hoạ (thay ô ảnh placeholder của wireframe)
                    Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.lock_reset,
                          size: 56, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _otpSent
                          ? 'Enter the 6-digit OTP code we sent to your phone '
                              'and choose a new password.'
                          : 'Enter your phone number to receive a 6-digit '
                              'OTP code.',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const FieldLabel('Phone Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !_otpSent,
                      decoration: const InputDecoration(
                        hintText: 'Enter your phone number',
                        prefixIcon: Icon(Icons.phone, size: 20),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Please enter your phone number.'
                              : null,
                    ),

                    if (_otpSent) ...[
                      const SizedBox(height: 18),
                      const FieldLabel('OTP Code'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'Enter the 6-digit code',
                          prefixIcon: Icon(Icons.pin, size: 20),
                          counterText: '',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'This field is required.'
                                : null,
                      ),
                      const SizedBox(height: 18),
                      const FieldLabel('New Password'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter your new password',
                          helperText:
                              'At least 8 characters, 1 uppercase and 1 digit.',
                          prefixIcon: Icon(Icons.lock, size: 20),
                        ),
                        // BR-09: validate ngay trên client, không chờ server
                        validator: Validators.passwordComplexity,
                      ),
                      const SizedBox(height: 18),
                      const FieldLabel('Confirm New Password'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Re-enter your new password',
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                        ),
                        validator: (value) =>
                            value != _newPasswordController.text
                                ? 'Passwords do not match.'
                                : null,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: (_isSubmitting || _resendCountdown > 0)
                                ? null
                                : _sendOtp,
                            child: Text(_resendCountdown > 0
                                ? 'Resend OTP (${_resendCountdown}s)'
                                : 'Resend OTP'),
                          ),
                          // Gõ nhầm SĐT -> quay lại bước 1 sửa, không thoát màn
                          TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(() {
                                      _otpSent = false;
                                      _otpController.clear();
                                    }),
                            child: const Text('Change phone number'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Nút chính ghim đáy màn + link quay lại đăng nhập (layout wireframe)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: _isSubmitting
                        ? null
                        : (_otpSent ? _resetPassword : _sendOtp),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _otpSent ? 'UPDATE PASSWORD' : 'RESET PASSWORD',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              letterSpacing: .5,
                            ),
                          ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: const Text('Back to Login'),
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

