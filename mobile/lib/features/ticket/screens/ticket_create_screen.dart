import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../providers/ticket_provider.dart';

/// UC19 - Màn hình tạo sự cố (Resident). Chọn danh mục, nhập mô tả (≥10 ký tự),
/// đính kèm tối đa 3 ảnh (BR-37, nén < 500KB theo BR-10).
class TicketCreateScreen extends ConsumerStatefulWidget {
  const TicketCreateScreen({super.key});

  @override
  ConsumerState<TicketCreateScreen> createState() => _TicketCreateScreenState();
}

class _TicketCreateScreenState extends ConsumerState<TicketCreateScreen> {
  /// Danh mục hợp lệ - khớp TICKET_CATEGORIES ở backend (UC19 bước 2).
  static const List<({String value, IconData icon})> _categories = [
    (value: 'Điện', icon: Icons.electrical_services),
    (value: 'Nước', icon: Icons.water_drop),
    (value: 'Nội thất', icon: Icons.chair),
    (value: 'Khác', icon: Icons.more_horiz),
  ];
  static const int _maxImages = 3;

  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  String? _category;
  final List<Uint8List> _images = [];
  bool _isSubmitting = false;
  bool _isPicking = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickImage() async {
    if (_isPicking || _images.length >= _maxImages) return;
    setState(() => _isPicking = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      // BR-10: nén < 500KB trước khi giữ để upload
      final compressed = await ImageUtil.compressUnder500Kb(picked.path);
      if (compressed == null) {
        _showMessage('Không thể nén ảnh. Vui lòng chọn ảnh khác.');
        return;
      }
      setState(() => _images.add(compressed));
    } catch (e) {
      _showMessage('Lỗi chọn ảnh: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _submit() async {
    if (_category == null) {
      _showMessage('Vui lòng chọn danh mục sự cố.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(ticketProvider.notifier).createTicket(
            category: _category!,
            description: _descController.text.trim(),
            imageBytes: _images,
          );
      _showMessage('Gửi yêu cầu sửa chữa thành công.');
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(e.toString());
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
            title: 'Báo Sự Cố',
            subtitle: 'Gửi yêu cầu sửa chữa tới Ban quản lý',
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
                        const Text('1. Danh mục sự cố *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _categories.map((c) {
                            final selected = _category == c.value;
                            return ChoiceChip(
                              avatar: Icon(c.icon,
                                  size: 18,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary),
                              label: Text(c.value),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _category = c.value),
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('2. Mô tả chi tiết *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descController,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: InputDecoration(
                            hintText:
                                'Mô tả rõ sự cố (tối thiểu 10 ký tự) để BQL xử lý nhanh hơn...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            final v = val?.trim() ?? '';
                            if (v.isEmpty) return 'Vui lòng nhập mô tả sự cố.';
                            if (v.length < 10) {
                              return 'Mô tả phải có ít nhất 10 ký tự.';
                            }
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
                        Text('3. Ảnh sự cố (tùy chọn, tối đa $_maxImages)',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary)),
                        const SizedBox(height: 6),
                        const Text(
                          'Ảnh JPG/PNG, tự động nén trước khi gửi.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ..._images.asMap().entries.map((e) => _thumbnail(e.key, e.value)),
                            if (_images.length < _maxImages) _addImageButton(),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('GỬI YÊU CẦU',
                              style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _thumbnail(int index, Uint8List bytes) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: 90, height: 90, fit: BoxFit.cover),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(index)),
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addImageButton() {
    return GestureDetector(
      onTap: _isPicking ? null : _pickImage,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: _isPicking
            ? const Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo,
                      color: AppColors.textTertiary, size: 26),
                  SizedBox(height: 4),
                  Text('Thêm ảnh',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
      ),
    );
  }
}
