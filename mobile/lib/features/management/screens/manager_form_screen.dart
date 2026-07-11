import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../providers/manager_notifier.dart';

/// UC43: Create Manager Account.
/// Landlord creates a new Manager account.
/// Default password is "Apora@123".
class ManagerFormScreen extends ConsumerStatefulWidget {
  const ManagerFormScreen({super.key});

  @override
  ConsumerState<ManagerFormScreen> createState() => _ManagerFormScreenState();
}

class _ManagerFormScreenState extends ConsumerState<ManagerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSuccess = false;

  bool get _isDirty =>
      _fullNameController.text.isNotEmpty || _phoneController.text.isNotEmpty;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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
      await ref.read(managerDirectoryProvider.notifier).createManager(
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
          );
      if (!mounted) return;
      setState(() => _isSuccess = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tạo tài khoản quản lý thành công.')),
      );
      
      // Chờ PopScope cập nhật canPop = true rồi mới pop
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
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
      canPop: !_isDirty || _isSuccess,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        body: Column(
          children: [
            const GradientHeader(
              title: 'Thêm quản lý',
              subtitle: 'Cấp tài khoản cho ban quản lý',
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
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? AppStrings.msgPhoneRequired
                                  : null,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Tài khoản sẽ được tạo với mật khẩu mặc định là Apora@123',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
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
