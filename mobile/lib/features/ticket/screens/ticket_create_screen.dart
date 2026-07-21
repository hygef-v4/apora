import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/spec_layout.dart';
import '../../contract/providers/contract_provider.dart';
import '../widgets/ticket_category.dart';
import '../providers/ticket_provider.dart';

/// UC19 - Report Issue (bố cục theo wireframe FID-19 trong SRS). Chỉ RESIDENT.
/// Chọn danh mục, nhập mô tả (>= 10 ký tự), đính kèm tối đa 3 ảnh (BR-37,
/// nén < 500KB theo BR-10). Danh mục lưu tiếng Việt (khớp enum backend),
/// chỉ hiển thị nhãn tiếng Anh.
class TicketCreateScreen extends ConsumerStatefulWidget {
  const TicketCreateScreen({super.key});

  @override
  ConsumerState<TicketCreateScreen> createState() => _TicketCreateScreenState();
}

class _TicketCreateScreenState extends ConsumerState<TicketCreateScreen> {
  static const int _maxImages = 3;

  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  String? _category;
  final List<Uint8List> _images = [];
  bool _isSubmitting = false;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    // Cập nhật khối Summary khi mô tả đổi (số ký tự / ảnh)
    _descController.addListener(() => setState(() {}));
    // Nạp căn hộ của cư dân để hiển thị khối Apartment Info (chỉ đọc)
    Future.microtask(() => ref.read(myContractProvider.notifier).fetch());
  }

  String _formatFloor(String floor) {
    final n = int.tryParse(floor.trim());
    if (n == null) return floor;
    final suffix = (n % 100 >= 11 && n % 100 <= 13)
        ? 'th'
        : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
    return '$n$suffix Floor';
  }

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
        _showMessage('Could not compress the image. Please pick another.');
        return;
      }
      setState(() => _images.add(compressed));
    } catch (e) {
      _showMessage('Image pick error: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _submit() async {
    if (_category == null) {
      _showMessage('Please select an issue category.');
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
      _showMessage('Issue reported successfully.');
      if (mounted) context.pop();
    } catch (e) {
      _showMessage(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final apt = ref.watch(myContractProvider).value?.apartment;
    final apartment = apt == null
        ? '—'
        : 'Room ${apt.unitNumber} — ${_formatFloor(apt.floor)}';
    final selectedLabel =
        _category == null ? '—' : ticketCategoryLabel(_category!);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(title: 'Report Issue', showBack: true),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  // APARTMENT INFO
                  const SpecSectionHeader('Apartment Info'),
                  SpecDetailRow(label: 'Apartment', value: apartment),
                  const SizedBox(height: 20),

                  // TICKET DETAILS
                  const SpecSectionHeader('Ticket Details'),
                  const SizedBox(height: 8),
                  const SpecFieldLabel('Category', required: true),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kTicketCategories.map((c) {
                      final selected = _category == c.value;
                      return ChoiceChip(
                        avatar: Icon(
                          c.icon,
                          size: 18,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        label: Text(c.label),
                        selected: selected,
                        onSelected: _isSubmitting
                            ? null
                            : (_) => setState(() => _category = c.value),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        showCheckmark: false,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  const SpecFieldLabel('Description', required: true),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    maxLength: 500,
                    enabled: !_isSubmitting,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'Describe the issue in detail... (min 10 characters)',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (val) {
                      final v = val?.trim() ?? '';
                      if (v.isEmpty) return 'Please enter an issue description.';
                      if (v.length < 10) {
                        return 'Description must be at least 10 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  const SpecFieldLabel('Attach Photos (max 3)'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ..._images
                          .asMap()
                          .entries
                          .map((e) => _thumbnail(e.key, e.value)),
                      if (_images.length < _maxImages) _addImageButton(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'JPG/PNG, max 5MB each',
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 20),

                  // SUMMARY
                  const SpecSectionHeader('Summary'),
                  SpecDetailRow(label: 'Category', value: selectedLabel),
                  SpecDetailRow(
                    label: 'Photos Attached',
                    value: '${_images.length} / $_maxImages',
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'SUBMIT TICKET',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: .5,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : () => context.pop(),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: .5,
                        ),
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
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: _isPicking
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: AppColors.textTertiary, size: 26),
                  SizedBox(height: 4),
                  Text(
                    'ADD PHOTO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
