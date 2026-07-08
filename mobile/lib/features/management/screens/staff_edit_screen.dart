import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../models/staff_member.dart';
import '../providers/staff_notifier.dart';

/// UC39 (FID-38): Cập nhật hồ sơ nhân viên.
/// - Avatar nén < 500KB (BR-10), lỗi upload backend vẫn lưu field text (AT3)
/// - Đổi role khi còn task mở -> cảnh báo xác nhận (AT4)
/// - Status read-only; deactivate đi qua flow UC40 ở màn Detail
/// - Nút "Đặt lại mật khẩu" - flow riêng do Manager khởi tạo (BR-03 UC39)
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
      _showMessage('Không thể xử lý ảnh. Vui lòng chọn ảnh khác.');
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
        title: const Text('Cảnh báo đổi vai trò'),
        content: const Text(AppStrings.msgRoleChangeWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tiếp tục'),
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
      await ref.read(staffDetailProvider.notifier).updateStaff(
            widget.staffId,
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
            role: _selectedRole!,
            avatarBytes: _avatarBytes,
          );
      _showMessage('Cập nhật hồ sơ nhân viên thành công.');
      // Danh sách cũng cần số liệu mới
      await ref.read(staffDirectoryProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Manager đặt lại mật khẩu cho nhân viên (flow riêng, khác UC03).
  Future<void> _resetPasswordDialog() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đặt lại mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nhân viên sẽ bị đăng xuất khỏi mọi thiết bị và phải đổi mật khẩu ở lần đăng nhập kế tiếp.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới',
                helperText: 'Tối thiểu 8 ký tự, gồm 1 chữ hoa và 1 chữ số.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref
          .read(staffDetailProvider.notifier)
          .resetPassword(widget.staffId, passwordController.text);
      _showMessage('Đặt lại mật khẩu thành công.');
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
            title: const Text('Thay đổi chưa lưu'),
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
        if ((leave ?? false) && context.mounted) context.pop();
      },
      child: Scaffold(
        body: Column(
          children: [
            const GradientHeader(
              title: 'Chỉnh sửa nhân viên',
              subtitle: 'Cập nhật hồ sơ & vai trò',
              showBack: true,
            ),
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
                        Center(
                          child: Stack(
                            children: [
                              _avatarBytes != null
                                  ? CircleAvatar(
                                      radius: 48,
                                      backgroundImage:
                                          MemoryImage(_avatarBytes!),
                                    )
                                  : InitialsAvatar(
                                      name: _staffName.isEmpty
                                          ? '?'
                                          : _staffName,
                                      imageUrl: _currentAvatarUrl,
                                      size: 96,
                                    ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: IconButton.filled(
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  onPressed: _pickAvatar,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
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
                          onChanged: (value) => setState(() {
                            _selectedRole = value;
                            _dirty = true;
                          }),
                          validator: (value) =>
                              value == null ? 'Vui lòng chọn vai trò.' : null,
                        ),
                        const SizedBox(height: 20),
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
                              : const Text('Lưu thay đổi'),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.lock_reset, size: 18),
                          label: const Text('Đặt lại mật khẩu'),
                          onPressed: _resetPasswordDialog,
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
