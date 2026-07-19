import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/staff_member.dart';
import '../providers/staff_notifier.dart';

/// UC38 (FID-37): Tạo tài khoản nhân viên.
/// Nhân viên tạo mới sẽ bị ép đổi mật khẩu ở lần đăng nhập đầu (BR-01/BR-04 UC38).
class StaffFormScreen extends ConsumerStatefulWidget {
  const StaffFormScreen({super.key});

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _selectedRole;
  bool _isSubmitting = false;

  bool get _isDirty =>
      _fullNameController.text.isNotEmpty ||
      _phoneController.text.isNotEmpty ||
      _passwordController.text.isNotEmpty ||
      _selectedRole != null;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// AT4 (UC38): cancel khi form có dữ liệu -> confirm mất dữ liệu.
  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy tạo tài khoản?'),
        content: const Text(AppStrings.msgUnsavedChanges),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(staffDirectoryProvider.notifier).createStaff(
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            role: _selectedRole!,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo tài khoản nhân viên thành công.')),
      );
      context.pop();
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
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        body: Column(
          children: [
            const GradientHeader(
              title: 'Thêm nhân viên',
              subtitle: 'Cấp tài khoản cho nhân viên vận hành',
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
                          controller: _fullNameController,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Họ và tên',
                            prefixIcon: Icon(Icons.badge, size: 20),
                            counterText: '',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? AppStrings.msgFieldRequired
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 15,
                          decoration: const InputDecoration(
                            labelText: 'Số điện thoại (dùng để đăng nhập)',
                            prefixIcon: Icon(Icons.phone, size: 20),
                            counterText: '',
                          ),
                          // BR-02: validate định dạng ngay trên client
                          validator: Validators.vnPhone,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Vai trò',
                            prefixIcon: Icon(Icons.work, size: 20),
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
                              value == null ? 'Vui lòng chọn vai trò.' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mật khẩu ban đầu',
                            helperText:
                                'Tối thiểu 8 ký tự, gồm 1 chữ hoa và 1 chữ số. Nhân viên sẽ phải đổi khi đăng nhập lần đầu.',
                            helperMaxLines: 2,
                            prefixIcon: Icon(Icons.lock, size: 20),
                          ),
                          // BR-09: validate độ phức tạp ngay trên client,
                          // nhất quán với màn Quên/Đổi mật khẩu
                          validator: Validators.passwordComplexity,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Xác nhận mật khẩu',
                            prefixIcon: Icon(Icons.lock_outline, size: 20),
                          ),
                          validator: (value) =>
                              value != _passwordController.text
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
                              : const Text('Tạo tài khoản'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (await _confirmDiscard() && context.mounted) {
                              context.pop();
                            }
                          },
                          child: const Text('Hủy'),
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
}
