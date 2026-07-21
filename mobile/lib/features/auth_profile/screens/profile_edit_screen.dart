import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../providers/profile_notifier.dart';

/// UC05: Cập nhật hồ sơ cá nhân (FID-05).
/// Avatar được nén < 500KB trước khi upload (BR-10).
/// TODO(Tenancy): dropdown đổi căn hộ thuộc module Tenancy - làm sau.
///
/// Layout bám wireframe: header back + tiêu đề căn giữa -> avatar có nút "+"
/// và caption "Change Avatar" -> label nằm trên ô nhập -> hộp lưu ý ->
/// nút "SAVE CHANGES" ghim đáy màn. Style theo design system Apora.
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
      _showMessage('Could not process this image. Please pick another one.');
      return;
    }
    setState(() => _avatarBytes = compressed);
  }

  /// Đổi SĐT = đổi username đăng nhập -> backend yêu cầu xác nhận mật khẩu
  /// hiện tại. Trả về null nếu người dùng hủy.
  Future<String?> _askCurrentPassword() async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm phone number change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your phone number is your login username. '
              'Enter your current password to confirm this change.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Current password'),
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
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return (confirmed ?? false) ? passwordController.text : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(profileNotifierProvider).value;

    // AT4 (UC05): không sửa gì mà bấm Lưu -> báo và bỏ qua API call
    final nothingChanged = user != null &&
        _fullNameController.text.trim() == user.fullName &&
        _phoneController.text.trim() == user.phoneNumber &&
        _avatarBytes == null;
    if (nothingChanged) {
      _showMessage('No changes to save.');
      return;
    }

    final phoneChanged =
        user != null && _phoneController.text.trim() != user.phoneNumber;
    String? currentPassword;
    if (phoneChanged) {
      currentPassword = await _askCurrentPassword();
      if (currentPassword == null) return; // người dùng hủy
    }

    setState(() => _isSubmitting = true);
    try {
      final avatarUploadFailed =
          await ref.read(profileNotifierProvider.notifier).updateProfile(
                fullName: _fullNameController.text.trim(),
                phone: _phoneController.text.trim(),
                avatarBytes: _avatarBytes,
                currentPassword: currentPassword,
              );
      _showMessage(avatarUploadFailed
          ? 'Profile saved, but the avatar could not be uploaded.'
          : 'Profile updated successfully.');
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header: back trái + tiêu đề căn giữa (layout wireframe)
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.residentGradient,
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Row(
              children: [
                HeaderIconButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: Text(
                    'UPDATE PROFILE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Giữ tiêu đề cân giữa so với nút back
                const SizedBox(width: 36),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar + nút "+" ở góc, caption bên dưới (wireframe)
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
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: _pickAvatar,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _pickAvatar,
                        child: const Text('Change Avatar'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const _FieldLabel('Full Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.badge, size: 20),
                        counterText: '',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'This field is required.'
                              : null,
                    ),
                    const SizedBox(height: 18),

                    const _FieldLabel('Phone Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      decoration: const InputDecoration(
                        hintText: 'Enter your phone number',
                        prefixIcon: Icon(Icons.phone, size: 20),
                        counterText: '',
                      ),
                      // BR-02: validate định dạng ngay trên client, khớp backend
                      validator: Validators.vnPhone,
                    ),
                    const SizedBox(height: 18),

                    // Hộp lưu ý (wireframe): nội dung theo ràng buộc thật của
                    // màn này - đổi SĐT là đổi username nên phải xác nhận
                    // mật khẩu hiện tại.
                    AppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your phone number is also your login username. '
                              'Changing it requires your current password.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Nút chính ghim đáy màn (layout wireframe)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
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
                      : const Text(
                          'SAVE CHANGES',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
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

/// Nhãn phía trên ô nhập (theo wireframe).
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}
