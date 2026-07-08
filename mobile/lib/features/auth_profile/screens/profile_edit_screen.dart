import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
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
      body: Column(
        children: [
          const GradientHeader(
            title: 'Chỉnh sửa hồ sơ',
            subtitle: 'Cập nhật thông tin cá nhân',
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
                      Center(
                        child: Stack(
                          children: [
                            _avatarBytes != null
                                ? CircleAvatar(
                                    radius: 48,
                                    backgroundImage: MemoryImage(_avatarBytes!),
                                  )
                                : InitialsAvatar(
                                    name: user?.fullName ?? '?',
                                    imageUrl: user?.avatarUrl,
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
                      TextButton(
                        onPressed: () => context.push(AppRoutes.changePassword),
                        child: const Text('Đổi mật khẩu'),
                      ),
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
