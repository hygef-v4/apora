import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/image_util.dart';
import '../providers/profile_notifier.dart';

/// UC05: Cập nhật hồ sơ cá nhân (FID-05).
/// Avatar được nén < 500KB trước khi upload (BR-10).
/// TODO(Tenancy): dropdown đổi căn hộ thuộc module Tenancy - làm sau.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  Uint8List? _avatarBytes;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(profileNotifierProvider).value;
    if (user != null) {
      _fullNameController.text = user.fullName;
      _phoneController.text = user.phoneNumber;
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
    // BR-10: nén ảnh < 500KB trước khi upload
    final compressed = await ImageUtil.compressUnder500Kb(picked.path);
    if (compressed == null) {
      _showMessage('Không thể xử lý ảnh. Vui lòng chọn ảnh khác.');
      return;
    }
    setState(() => _avatarBytes = compressed);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(profileNotifierProvider.notifier).updateProfile(
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
            avatarBytes: _avatarBytes,
          );
      _showMessage('Cập nhật hồ sơ thành công.');
      if (mounted) context.go(AppRoutes.profile);
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileNotifierProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: _avatarBytes != null
                            ? MemoryImage(_avatarBytes!)
                            : (user?.avatarUrl != null
                                ? NetworkImage(user!.avatarUrl!)
                                : null) as ImageProvider?,
                        child: (_avatarBytes == null && user?.avatarUrl == null)
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: IconButton.filled(
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
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
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
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? AppStrings.msgPhoneRequired
                      : null,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _save,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu thay đổi'),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.changePassword),
                  child: const Text('Đổi mật khẩu'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
