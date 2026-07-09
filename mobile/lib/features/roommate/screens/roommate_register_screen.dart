import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/network/dio_client.dart'; // Để dùng mapDioError
import '../providers/roommate_provider.dart';

class RoommateRegisterScreen extends ConsumerStatefulWidget {
  const RoommateRegisterScreen({super.key});

  @override
  ConsumerState<RoommateRegisterScreen> createState() => _RoommateRegisterScreenState();
}

class _RoommateRegisterScreenState extends ConsumerState<RoommateRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cccdController = TextEditingController();

  Uint8List? _cccdFrontBytes;
  Uint8List? _cccdBackBytes;
  bool _isSubmitting = false;
  bool _isPickingImage = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cccdController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage(bool isFront) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cắt ảnh CCCD',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Cắt ảnh CCCD',
          ),
        ],
      );

      if (croppedFile == null) return;

      // BR-10: Nén ảnh phía client xuống dưới 500KB trước khi gửi
      final compressed = await ImageUtil.compressUnder500Kb(croppedFile.path);
      if (compressed == null) {
        _showMessage('Không thể nén ảnh. Vui lòng chọn ảnh khác.');
        return;
      }

      setState(() {
        if (isFront) {
          _cccdFrontBytes = compressed;
        } else {
          _cccdBackBytes = compressed;
        }
      });
    } catch (e) {
      _showMessage('Lỗi chọn ảnh: $e');
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cccdFrontBytes == null || _cccdBackBytes == null) {
      _showMessage('Vui lòng chọn đầy đủ ảnh chụp mặt trước và mặt sau CCCD.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(roommateProvider.notifier).registerRoommate(
            fullName: _fullNameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            cccdNumber: _cccdController.text.trim(),
            cccdFrontBytes: _cccdFrontBytes,
            cccdBackBytes: _cccdBackBytes,
          );

      _showMessage('Gửi yêu cầu đăng ký thành công, vui lòng chờ Quản lý phê duyệt.');
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Đăng Ký Thành Viên',
            subtitle: 'Nhập thông tin người ở ghép / tạm trú',
            showBack: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Thông Tin Cá Nhân',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'Họ và tên thành viên *',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Vui lòng nhập họ và tên.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Số điện thoại liên hệ (Tùy chọn)',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cccdController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Số CCCD / Định danh cá nhân *',
                            prefixIcon: const Icon(Icons.credit_card),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số CCCD.';
                            if (val.length != 12) return 'Số CCCD phải gồm 12 chữ số.';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '2. Ảnh Chụp Giấy Tờ Tùy Thân (CCCD) *',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Vui lòng tải lên ảnh chụp rõ nét cả hai mặt mặt trước và mặt sau của CCCD để Quản lý đối chiếu.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _buildImagePickerCard(
                                title: 'Mặt trước CCCD',
                                imageBytes: _cccdFrontBytes,
                                onTap: () => _pickImage(true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildImagePickerCard(
                                title: 'Mặt sau CCCD',
                                imageBytes: _cccdBackBytes,
                                onTap: () => _pickImage(false),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'GỬI YÊU CẦU ĐĂNG KÝ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePickerCard({
    required String title,
    required Uint8List? imageBytes,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo, color: AppColors.textTertiary, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ],
              ),
      ),
    );
  }
}
