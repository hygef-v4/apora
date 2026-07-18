import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../providers/announce_notifier.dart';
import '../providers/notification_list_provider.dart';

class AnnounceFormScreen extends ConsumerStatefulWidget {
  const AnnounceFormScreen({super.key});

  @override
  ConsumerState<AnnounceFormScreen> createState() => _AnnounceFormScreenState();
}

class _AnnounceFormScreenState extends ConsumerState<AnnounceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  File? _bannerImage;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // BR-10: Compress image at client side
    final picker = ref.read(imagePickerProvider);
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Giảm chất lượng để tối ưu dung lượng < 500KB
    );
    if (pickedFile != null) {
      setState(() {
        _bannerImage = File(pickedFile.path);
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ref.read(announceNotifierProvider.notifier).submit(
            title: _titleController.text.trim(),
            body: _bodyController.text.trim(),
            banner: _bannerImage,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announceNotifierProvider);

    ref.listen<AnnounceState>(announceNotifierProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.error!)));
      } else if (next.isSuccess) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Đăng thông báo thành công')));
        ref.invalidate(notificationListProvider);
        context.pop();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'Tạo thông báo',
            showBack: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề thông báo *',
                      ),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Vui lòng nhập tiêu đề'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung *',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Vui lòng nhập nội dung'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    
                    // Image Picker Section
                    const Text(
                      'Ảnh bìa (Không bắt buộc)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: _bannerImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(_bannerImage!, fit: BoxFit.cover),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      size: 40, color: AppColors.textTertiary),
                                  SizedBox(height: 8),
                                  Text(
                                    'Nhấn để tải ảnh lên',
                                    style: TextStyle(color: AppColors.textTertiary),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: state.isLoading ? null : _submit,
                      child: state.isLoading
                          ? const SizedBox(
                              width: 20, height: 20, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Đăng thông báo'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
