import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/spec_layout.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../widgets/ticket_category.dart';

/// UC23 - Task Detail (bố cục theo wireframe FID-23 trong SRS).
/// Nhân viên được giao: bắt đầu làm (IN_PROGRESS) hoặc nghiệm thu
/// (COMPLETED - bắt buộc >= 1 ảnh theo BR-43, tối đa 3 theo BR-37).
class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final int taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  static const int _maxImages = 3;

  final _notesController = TextEditingController();
  final List<Uint8List> _images = [];
  bool _isSubmitting = false;
  bool _isPicking = false;

  /// AT1: tô đỏ khối ảnh khi bấm hoàn thành mà chưa có ảnh nghiệm thu.
  bool _highlightPhotoError = false;

  /// Ghi chú từ server lần gần nhất - chỉ đồng bộ vào ô khi server đổi.
  String _serverNotes = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(taskDetailProvider.notifier).fetch(widget.taskId),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatDateTime(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'COMPLETED':
        return StatusBadge.success('COMPLETED');
      case 'IN_PROGRESS':
        return StatusBadge.warning('IN_PROGRESS');
      case 'CANCELLED':
        return StatusBadge.muted('CANCELLED');
      default:
        return const StatusBadge(
          text: 'ASSIGNED',
          color: AppColors.primary,
          backgroundColor: AppColors.infoBg,
        );
    }
  }

  Future<void> _pickImage() async {
    // AT3: chặn quá 3 ảnh ngay tại nút (nút ẩn khi đủ - đây là phòng thủ)
    if (_isPicking || _images.length >= _maxImages) return;
    setState(() => _isPicking = true);
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      // BR-10: nén < 500KB trước khi giữ để upload
      final compressed = await ImageUtil.compressUnder500Kb(picked.path);
      if (compressed == null) {
        _showSnack('Could not compress the image. Please pick another.');
        return;
      }
      setState(() {
        _images.add(compressed);
        _highlightPhotoError = false;
      });
    } catch (e) {
      _showSnack('Image pick error: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  /// Bắt đầu làm: ASSIGNED -> IN_PROGRESS (ticket cha -> PROCESSING).
  Future<void> _start() => _update('IN_PROGRESS');

  /// Nghiệm thu: -> COMPLETED. AT1/BR-43: bắt buộc >= 1 ảnh.
  Future<void> _complete() async {
    if (_images.isEmpty) {
      setState(() => _highlightPhotoError = true);
      _showSnack('At least 1 completion photo is required to finish the task.');
      return;
    }
    await _update('COMPLETED');
  }

  Future<void> _update(String status) async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(taskDetailProvider.notifier).updateProgress(
            widget.taskId,
            status: status,
            progressNotes: _notesController.text,
            imageBytes: status == 'COMPLETED' ? _images : const [],
          );
      _showSnack(status == 'COMPLETED'
          ? 'Task completed. The ticket is now marked resolved.'
          : 'Task started.');
      if (status == 'COMPLETED') {
        setState(_images.clear);
        // FID-23 field 13: hoàn thành xong quay về danh sách công việc
        if (mounted && context.canPop()) context.pop();
      }
    } catch (e) {
      // AT4: lỗi mạng/server -> giữ nguyên dữ liệu đã nhập
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskDetailProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(title: 'Task Detail', showBack: true),
          Expanded(
            child: state.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => _ErrorRetry(
                message: e.toString(),
                onRetry: () =>
                    ref.read(taskDetailProvider.notifier).fetch(widget.taskId),
              ),
              data: (task) {
                if (task == null) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                return _buildContent(task);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(TaskDetail task) {
    final serverNotes = task.progressNotes ?? '';
    if (_serverNotes != serverNotes) {
      _serverNotes = serverNotes;
      _notesController.text = serverNotes;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // Badge trạng thái
        Align(
          alignment: Alignment.centerRight,
          child: _statusBadge(task.status),
        ),
        const SizedBox(height: 12),

        // Task ID + tiêu đề + mô tả
        Text(
          'Task ID: TASK-${task.id.toString().padLeft(3, '0')}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          task.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (task.description != null &&
            task.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            task.description!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetaField(
                label: 'Assigned by',
                value: task.assignedByName,
              ),
            ),
            Expanded(
              child: _MetaField(
                label: 'Assigned on',
                value: _formatDateTime(task.assignedAt),
              ),
            ),
          ],
        ),
        if (task.completedAt != null) ...[
          const SizedBox(height: 10),
          _MetaField(
            label: 'Completed on',
            value: _formatDateTime(task.completedAt!),
          ),
        ],
        const SizedBox(height: 14),

        // Khối tham chiếu sự cố gốc (FID-23 field 7)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.divider,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#TK-${task.ticketId.toString().padLeft(3, '0')}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CategoryChip(category: task.category),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Apartment: Room ${task.unitNumber}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Reported by: ${task.residentName}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                task.ticketDescription,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        // BEFORE PHOTOS (ảnh cư dân báo - read only)
        if (task.ticketBeforeImages.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SpecSectionHeader('Before Photos'),
          const SizedBox(height: 4),
          const Text(
            'Photos reported by resident',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _imageWrap(task.ticketBeforeImages),
        ],

        // COMPLETION PHOTOS đã lưu (task xong)
        if (task.completionImages.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SpecSectionHeader('Completion Photos'),
          const SizedBox(height: 10),
          _imageWrap(task.completionImages),
        ],

        // Khối cập nhật tiến độ - chỉ khi task còn mở (PRE-02)
        if (task.isOpen) ...[
          const SizedBox(height: 18),
          const SpecSectionHeader('Progress Notes'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 500,
            enabled: !_isSubmitting,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Describe what was done, parts replaced, etc...',
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
          ),
          const SizedBox(height: 14),
          const SpecFieldLabel('Completion Photos', required: true),
          const Text(
            'min 1 required',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 10),
          Container(
            // AT1: viền đỏ khi thiếu ảnh nghiệm thu
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _highlightPhotoError
                    ? AppColors.error
                    : Colors.transparent,
              ),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._images
                    .asMap()
                    .entries
                    .map((e) => _pickedThumbnail(e.key, e.value)),
                if (_images.length < _maxImages) _addImageButton(),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'JPG/PNG, max 5MB each. At least 1 photo required.',
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 18),
          if (task.status == 'ASSIGNED') ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'START TASK',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, letterSpacing: .5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _start,
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text(
                'MARK AS COMPLETE',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: .5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSubmitting ? null : _complete,
            ),
          ),
        ],

        // Ghi chú tiến độ đã lưu (task đã đóng - read-only)
        if (!task.isOpen &&
            task.progressNotes != null &&
            task.progressNotes!.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          const SpecSectionHeader('Progress Notes'),
          const SizedBox(height: 8),
          Text(
            task.progressNotes!,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  /// Lưới thumbnail ảnh từ URL, bấm để phóng to.
  Widget _imageWrap(List<String> urls) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final url in urls)
          GestureDetector(
            onTap: () => _showFullImage(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 84,
                  height: 84,
                  color: AppColors.divider,
                  child: const Icon(Icons.broken_image,
                      color: AppColors.textTertiary),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Thumbnail ảnh nghiệm thu vừa chọn (chưa upload) + nút xóa.
  Widget _pickedThumbnail(int index, Uint8List bytes) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(bytes, width: 84, height: 84, fit: BoxFit.cover),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: _isSubmitting
                ? null
                : () => setState(() => _images.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// Ô "+" thêm ảnh nghiệm thu (FID-23 field 11).
  Widget _addImageButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          color: AppColors.surface,
        ),
        child: _isPicking
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: AppColors.textTertiary, size: 24),
                  SizedBox(height: 2),
                  Text(
                    'ADD PHOTO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(child: Center(child: Image.network(url))),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cặp "nhãn nhỏ trên - giá trị đậm dưới" (2 cột meta theo wireframe).
class _MetaField extends StatelessWidget {
  const _MetaField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ticketCategoryIcon(category),
              size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            ticketCategoryLabel(category),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
