import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/manager_member.dart';
import '../providers/manager_notifier.dart';

/// UC43: Create Manager Account.
/// UC44: Update Manager Account.
/// Landlord creates a new Manager account or edits an existing one.
class ManagerFormScreen extends ConsumerStatefulWidget {
  const ManagerFormScreen({super.key, this.manager});

  final ManagerMember? manager;

  @override
  ConsumerState<ManagerFormScreen> createState() => _ManagerFormScreenState();
}

class _ManagerFormScreenState extends ConsumerState<ManagerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSuccess = false;

  bool get _isEditMode => widget.manager != null;

  bool get _isDirty {
    if (!_isEditMode) {
      return _fullNameController.text.isNotEmpty || _phoneController.text.isNotEmpty;
    }
    return _fullNameController.text.trim() != widget.manager!.fullName ||
           _phoneController.text.trim() != widget.manager!.phoneNumber;
  }

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _fullNameController.text = widget.manager!.fullName;
      _phoneController.text = widget.manager!.phoneNumber;
    }
  }

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
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Discard'),
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
      if (_isEditMode) {
        await ref.read(managerDirectoryProvider.notifier).updateManager(
              widget.manager!.id,
              fullName: _fullNameController.text.trim(),
              phone: _phoneController.text.trim(),
            );
      } else {
        await ref.read(managerDirectoryProvider.notifier).createManager(
              fullName: _fullNameController.text.trim(),
              phone: _phoneController.text.trim(),
            );
      }
      
      if (!mounted) return;
      setState(() => _isSuccess = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode
              ? 'Manager profile updated successfully.'
              : 'Manager account created successfully.'),
        ),
      );
      
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
            GradientHeader(
              title: _isEditMode ? 'Edit Manager Profile' : 'Create Manager',
              actions: _isEditMode
                  ? const []
                  : [
                      IconButton(
                        icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
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
                        if (_isEditMode) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Account Status',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              widget.manager!.isActive
                                  ? StatusBadge.success('ACTIVE')
                                  : const StatusBadge(
                                      text: 'INACTIVE',
                                      color: AppColors.error,
                                      backgroundColor: AppColors.errorBg,
                                    ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        TextFormField(
                          controller: _fullNameController,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            hintText: 'e.g. John Smith',
                            prefixIcon: Icon(Icons.badge, size: 20),
                            counterText: '',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Full Name is required'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 15,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'e.g. +1 (555) 012-3456',
                            prefixIcon: Icon(Icons.phone, size: 20),
                            counterText: '',
                          ),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? 'Phone Number is required'
                                  : null,
                        ),
                        const SizedBox(height: 24),
                        if (!_isEditMode) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'A default password will be generated and sent to this user.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ] else ...[
                          const Divider(height: 32, thickness: 1, color: AppColors.border),
                          const SizedBox(height: 12),
                        ],
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(_isEditMode ? 'Save Changes' : 'CREATE ADMIN'),
                        ),
                        const SizedBox(height: 16),
                        if (_isEditMode)
                          Center(
                            child: InkWell(
                              onTap: () async {
                                if (await _confirmDiscard() && context.mounted) {
                                  context.pop();
                                }
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          )
                        else
                          OutlinedButton(
                            onPressed: () async {
                              if (await _confirmDiscard() && context.mounted) {
                                context.pop();
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
