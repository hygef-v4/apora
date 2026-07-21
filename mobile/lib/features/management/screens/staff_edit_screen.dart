import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/labeled_field.dart';
import '../models/staff_member.dart';
import '../providers/staff_notifier.dart';
import '../widgets/deactivate_staff_dialog.dart';

/// UC39 (FID-38): Update Staff — layout theo wireframe (avatar tròn có nút "+"
/// và caption "Tap to change avatar", các field label-trên-ô, nút SAVE CHANGES
/// full-width, link đỏ "Deactivate Staff Account" cuối trang).
/// - Avatar nén < 500KB (BR-10), lỗi upload backend vẫn lưu field text (AT3)
/// - Đổi role khi còn task mở -> cảnh báo xác nhận (AT4)
/// - Status hiển thị read-only: đổi trạng thái chỉ đi qua flow vô hiệu hóa
///   (UC40) để còn kiểm tra BR-50 + ghi audit, không sửa trực tiếp ở form
/// - Nút "Reset password" - flow riêng do Manager khởi tạo (BR-03 UC39)
class StaffEditScreen extends ConsumerStatefulWidget {
  const StaffEditScreen({super.key, required this.staffId});

  final int staffId;

  @override
  ConsumerState<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends ConsumerState<StaffEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedRole;
  String? _initialRole;
  int _openTaskCount = 0;
  Uint8List? _avatarBytes;
  String? _currentAvatarUrl;
  String _staffName = '';
  bool _isActive = true;
  bool _isSubmitting = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final detail = ref.read(staffDetailProvider).value;
    if (detail != null && detail.member.id == widget.staffId) {
      _fullNameController.text = detail.member.fullName;
      _phoneController.text = detail.member.phoneNumber;
      _selectedRole = detail.member.role;
      _initialRole = detail.member.role;
      _openTaskCount = detail.member.openTaskCount;
      _currentAvatarUrl = detail.member.avatarUrl;
      _staffName = detail.member.fullName;
      _isActive = detail.member.isActive;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final compressed = await ImageUtil.compressUnder500Kb(picked.path); // BR-10
    if (compressed == null) {
      _showMessage('Could not process this image. Please pick another one.');
      return;
    }
    setState(() {
      _avatarBytes = compressed;
      _dirty = true;
    });
  }

  /// AT4 (UC39): đổi role khi nhân viên còn task mở -> cảnh báo.
  Future<bool> _confirmRoleChangeIfNeeded() async {
    final roleChanged = _selectedRole != _initialRole;
    if (!roleChanged || _openTaskCount == 0) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change role?'),
        content: const Text(AppStrings.msgRoleChangeWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!await _confirmRoleChangeIfNeeded()) return;

    setState(() => _isSubmitting = true);
    try {
      final avatarUploadFailed =
          await ref.read(staffDetailProvider.notifier).updateStaff(
                widget.staffId,
                fullName: _fullNameController.text.trim(),
                phone: _phoneController.text.trim(),
                role: _selectedRole!,
                avatarBytes: _avatarBytes,
              );
      _showMessage(avatarUploadFailed
          ? AppStrings.msgAvatarUploadFailed
          : 'Staff profile updated.');
      // Danh sách cũng cần số liệu mới
      await ref.read(staffDirectoryProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// UC40: vô hiệu hóa tài khoản — cùng flow với màn Detail (confirm + lý do).
  /// BR-50: còn task mở thì backend trả 409, hiển thị message của backend.
  Future<void> _confirmDeactivate() async {
    final result = await showDeactivateStaffDialog(context);
    if (result == null) return;
    try {
      await ref.read(staffDirectoryProvider.notifier).deactivateStaff(
            widget.staffId,
            reason: result.reason,
          );
      await ref.read(staffDetailProvider.notifier).fetch(widget.staffId);
      _showMessage('Staff account deactivated.');
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(mapDioError(e));
    }
  }

  /// Manager đặt lại mật khẩu cho nhân viên (flow riêng, khác UC03).
  Future<void> _resetPasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The staff member will be signed out of every device and must '
              'change their password at the next login.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'At least 8 characters, 1 uppercase and 1 digit.',
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    // BR-09: validate độ phức tạp ngay trên client trước khi gọi API
    final complexityError =
        Validators.passwordComplexity(passwordController.text);
    if (complexityError != null) {
      _showMessage(complexityError);
      return;
    }
    try {
      await ref
          .read(staffDetailProvider.notifier)
          .resetPassword(widget.staffId, passwordController.text);
      _showMessage('Password reset.');
    } catch (e) {
      _showMessage(mapDioError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // AT6 (UC39): rời màn khi có thay đổi chưa lưu -> confirm
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Unsaved changes'),
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
        if ((leave ?? false) && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const GradientHeader(title: 'Update Staff', showBack: true),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    onChanged: () {
                      if (!_dirty) setState(() => _dirty = true);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AvatarPicker(
                          bytes: _avatarBytes,
                          imageUrl: _currentAvatarUrl,
                          name: _staffName,
                          onTap: _pickAvatar,
                        ),
                        const SizedBox(height: 24),
                        LabeledField(
                          label: 'Full Name',
                          child: TextFormField(
                            controller: _fullNameController,
                            maxLength: 100,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Jane Doe',
                              counterText: '',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'This field is required.'
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LabeledField(
                          label: 'Phone Number',
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 15,
                            decoration: const InputDecoration(
                              hintText: 'e.g. 0912345678',
                              counterText: '',
                            ),
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
                            onChanged: (value) => setState(() {
                              _selectedRole = value;
                              _dirty = true;
                            }),
                            validator: (value) =>
                                value == null ? 'Please select a role.' : null,
                          ),
                        ),
                        const SizedBox(height: 18),
                        LabeledField(
                          label: 'Status',
                          child: _ReadOnlyStatusField(isActive: _isActive),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isSubmitting ? null : _save,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('SAVE CHANGES'),
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          icon: const Icon(Icons.lock_reset, size: 18),
                          label: const Text('Reset password'),
                          onPressed: _isSubmitting ? null : _resetPasswordDialog,
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            onPressed: (_isSubmitting || !_isActive)
                                ? null
                                : _confirmDeactivate,
                            child: Text(
                              _isActive
                                  ? 'Deactivate Staff Account'
                                  : 'Account already deactivated',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                decoration:
                                    _isActive ? TextDecoration.underline : null,
                                decorationColor: AppColors.error,
                              ),
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

  /// BR-02: SĐT là username - 10 chữ số bắt đầu bằng 0 (khớp rule backend).
  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Please enter a phone number.';
    if (!RegExp(r'^0\d{9}$').hasMatch(phone)) {
      return 'Invalid phone number. Enter 10 digits starting with 0.';
    }
    return null;
  }
}

/// Avatar tròn + nút "+" và caption "Tap to change avatar" (wireframe).
class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.bytes,
    required this.imageUrl,
    required this.name,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String? imageUrl;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              bytes != null
                  ? CircleAvatar(radius: 48, backgroundImage: MemoryImage(bytes!))
                  : InitialsAvatar(
                      name: name.isEmpty ? '?' : name,
                      imageUrl: imageUrl,
                      size: 96,
                    ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2.5),
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tap to change avatar',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Ô Status chỉ đọc — cùng khuôn với các ô nhập để khớp wireframe, nhưng không
/// cho sửa: trạng thái chỉ đổi qua flow vô hiệu hóa (UC40) để kiểm BR-50 + audit.
class _ReadOnlyStatusField extends StatelessWidget {
  const _ReadOnlyStatusField({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.block,
            size: 18,
            color: isActive ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.lock_outline, size: 16, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
