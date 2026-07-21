import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/labeled_field.dart';
import '../models/staff_member.dart';
import '../providers/staff_notifier.dart';

/// UC38 (FID-37): Add Staff — layout theo wireframe (label nằm trên ô nhập,
/// hộp thông báo "mật khẩu mặc định sẽ được sinh tự động", nút Create Account
/// và Cancel full-width xếp dọc). Giao diện dùng design system Apora.
///
/// BR-01: mật khẩu mặc định do hệ thống sinh, nhân viên bị ép đổi ở lần đăng
/// nhập đầu — Manager không tự đặt mật khẩu nữa, mà nhận lại mật khẩu đã sinh
/// trong dialog sau khi tạo để bàn giao cho nhân viên.
class StaffFormScreen extends ConsumerStatefulWidget {
  const StaffFormScreen({super.key});

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _phoneFieldKey = GlobalKey<FormFieldState<String>>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedRole;
  bool _isSubmitting = false;

  /// Lỗi từ backend gắn vào ô SĐT (409 - số đã tồn tại), hiển thị inline
  /// dưới ô nhập như wireframe thay vì SnackBar.
  String? _phoneServerError;

  bool get _isDirty =>
      _fullNameController.text.isNotEmpty ||
      _phoneController.text.isNotEmpty ||
      _selectedRole != null;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Mặc định Flutter chỉ validate lại khi submit, nên lỗi cũ còn treo dù người
  /// dùng đã sửa xong. Field nào đang lỗi thì validate lại theo từng ký tự để
  /// lỗi biến mất ngay khi giá trị hợp lệ (field chưa lỗi vẫn im lặng, không
  /// bắt lỗi lúc người dùng mới gõ dở).
  void _clearErrorWhenFixed(GlobalKey<FormFieldState<String>> fieldKey) {
    final field = fieldKey.currentState;
    if (field != null && field.hasError) field.validate();
  }

  /// AT4 (UC38): cancel khi form có dữ liệu -> confirm mất dữ liệu.
  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard this staff account?'),
        content: const Text(AppStrings.msgUnsavedChanges),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// BR-09: mật khẩu mặc định >= 8 ký tự, có chữ hoa + chữ số.
  /// Bỏ các ký tự dễ nhầm (O/0, I/l/1) để Manager đọc lại cho nhân viên.
  String _generateDefaultPassword() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    final random = Random.secure();
    String pick(String pool) => pool[random.nextInt(pool.length)];

    final chars = <String>[
      pick(upper),
      pick(digits),
      for (var i = 0; i < 8; i++) pick(upper + lower + digits),
    ]..shuffle(random);
    return chars.join();
  }

  Future<void> _submit() async {
    setState(() => _phoneServerError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final password = _generateDefaultPassword();
    try {
      await ref.read(staffDirectoryProvider.notifier).createStaff(
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
            password: password,
            role: _selectedRole!,
          );
      if (!mounted) return;
      // Tắt spinner trước khi mở dialog: API đã xong, để nút không kẹt ở
      // trạng thái loading suốt lúc Manager đọc/copy mật khẩu.
      setState(() => _isSubmitting = false);
      await _showCredentialsDialog(password);
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      // 409 khi tạo = SĐT đã tồn tại -> báo ngay dưới ô SĐT (wireframe).
      if (e is DioException && e.response?.statusCode == 409) {
        _phoneServerError = 'Phone number already exists';
        _phoneFieldKey.currentState?.validate();
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(mapDioError(e))));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Bàn giao mật khẩu mặc định cho Manager — đây là lần duy nhất mật khẩu
  /// hiển thị (backend chỉ lưu hash theo BR-03).
  Future<void> _showCredentialsDialog(String password) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Staff account created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share this default password with ${_fullNameController.text.trim()}. '
              'It is shown only once and must be changed at first login.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                password,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: password));
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Password copied.')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        body: Column(
          children: [
            const GradientHeader(title: 'Add Staff', showBack: true),
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
                        LabeledField(
                          label: 'Full name',
                          child: TextFormField(
                            key: _nameFieldKey,
                            controller: _fullNameController,
                            maxLength: 100,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Jane Doe',
                              counterText: '',
                            ),
                            onChanged: (_) => _clearErrorWhenFixed(_nameFieldKey),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'This field is required.'
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LabeledField(
                          label: 'Phone number',
                          child: TextFormField(
                            key: _phoneFieldKey,
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 15,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 0912345678',
                              counterText: '',
                            ),
                            onChanged: (_) {
                              _phoneServerError = null; // số đổi -> lỗi 409 hết hiệu lực
                              _clearErrorWhenFixed(_phoneFieldKey);
                            },
                            validator: _validatePhone,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LabeledField(
                          label: 'Role',
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedRole,
                            decoration: const InputDecoration(
                              hintText: 'Select a role',
                            ),
                            items: kStaffRoles
                                .map((role) => DropdownMenuItem(
                                      value: role,
                                      child: Text(staffRoleLabel(role)),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedRole = value),
                            validator: (value) =>
                                value == null ? 'Please select a role.' : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _DefaultPasswordNotice(),
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
                              : const Text('Create Account'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  if (await _confirmDiscard() &&
                                      context.mounted) {
                                    context.pop();
                                  }
                                },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// BR-02: SĐT là username - 10 chữ số bắt đầu bằng 0 (khớp rule backend).
  /// Ưu tiên hiển thị lỗi backend trả về (số đã tồn tại).
  String? _validatePhone(String? value) {
    if (_phoneServerError != null) return _phoneServerError;
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Please enter a phone number.';
    if (!RegExp(r'^0\d{9}$').hasMatch(phone)) {
      return 'Invalid phone number. Enter 10 digits starting with 0.';
    }
    return null;
  }
}

/// Hộp thông báo mật khẩu mặc định (wireframe) — BR-01.
class _DefaultPasswordNotice extends StatelessWidget {
  const _DefaultPasswordNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.infoBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'A default password will be generated for this staff account.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
