import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
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
  String _relationship = 'Roommate';

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
      _showMessage('Please upload both front and back ID photos.');
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

      _showMessage('Registration submitted successfully, awaiting approval.');
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(mapDioError(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 2.0),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const GradientHeader(
            title: 'REGISTER ROOMMATE',
            showBack: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. TOP SECTION TITLE
                  const Text(
                    'New Resident',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Register a new roommate for your unit.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. FORM FIELDS
                  // Field 1: Roommate Name
                  _buildFieldLabel('Roommate Name'),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: _inputDecoration('Enter full name'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter full name.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Field 2: Relationship
                  _buildFieldLabel('Relationship'),
                  DropdownButtonFormField<String>(
                    initialValue: _relationship,
                    decoration: _inputDecoration('Select relationship'),
                    items: const [
                      DropdownMenuItem(value: 'Roommate', child: Text('Roommate')),
                      DropdownMenuItem(value: 'Family', child: Text('Family')),
                      DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _relationship = val);
                    },
                  ),
                  const SizedBox(height: 14),

                  // Field 3: Phone Number
                  _buildFieldLabel('Phone Number'),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration('+1 (555) 000-0000'),
                  ),
                  const SizedBox(height: 14),

                  // Field 4: ID/Passport Number
                  _buildFieldLabel('ID/Passport Number'),
                  TextFormField(
                    controller: _cccdController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration('Enter identification number'),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter ID number.';
                      if (val.length != 12) return 'ID number must be 12 digits.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Field 5: Attached ID Photo
                  _buildFieldLabel('Attached ID Photo'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPhotoSlot(
                          'ID Card Front',
                          _cccdFrontBytes,
                          () => _pickImage(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPhotoSlot(
                          'ID Card Back',
                          _cccdBackBytes,
                          () => _pickImage(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. IMPORTANT NOTE CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Important Note',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'By submitting this registration, you confirm that the information provided is accurate and that the roommate agrees to the building\'s code of conduct.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. SUBMIT REGISTRATION BUTTON
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Submit Registration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  // 5. BOTTOM PREVIEW CARD
                  Container(
                    width: double.infinity,
                    height: 180,
                    margin: const EdgeInsets.only(top: 24, bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1.2),
                      boxShadow: AppColors.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/apartment-layout.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFF0F172A),
                              child: const Center(
                                child: Icon(Icons.apartment, size: 48, color: Colors.white54),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 14,
                          left: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'UNIT PREVIEW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
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
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(String label, Uint8List? imageBytes, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: imageBytes != null ? Colors.white : AppColors.primary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: imageBytes != null ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to upload',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
      ),
    );
  }
}
