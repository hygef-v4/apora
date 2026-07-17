import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_util.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/task.dart';
import '../models/ticket.dart';
import '../providers/task_provider.dart';

/// UC23 - Chi tiết công việc + cập nhật tiến độ (theo màn FID-23).
/// Nhân viên được giao: bắt đầu làm (IN_PROGRESS) hoặc nghiệm thu
/// (COMPLETED - bắt buộc ≥1 ảnh theo BR-43, tối đa 3 theo BR-37).
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

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  StatusBadge _statusBadge(String status) {
    final label = kTaskStatusLabels[status] ?? status;
    switch (status) {
      case 'COMPLETED':
        return StatusBadge.success(label);
      case 'IN_PROGRESS':
        return StatusBadge.warning(label);
      case 'CANCELLED':
        return StatusBadge(
          text: label,
          color: AppColors.error,
          backgroundColor: AppColors.errorBg,
        );
      default:
        return StatusBadge.info(label);
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
        _showSnack('Không thể nén ảnh. Vui lòng chọn ảnh khác.');
        return;
      }
      setState(() {
        _images.add(compressed);
        _highlightPhotoError = false;
      });
    } catch (e) {
      _showSnack('Lỗi chọn ảnh: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  /// Bắt đầu làm: ASSIGNED -> IN_PROGRESS (ticket cha -> PROCESSING).
  Future<void> _start() => _update('IN_PROGRESS');

  /// Nghiệm thu: -> COMPLETED. AT1/BR-43: bắt buộc ≥1 ảnh.
  Future<void> _complete() async {
    if (_images.isEmpty) {
      setState(() => _highlightPhotoError = true);
      _showSnack('Cần ít nhất 1 ảnh nghiệm thu để hoàn thành công việc.');
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
          ? 'Đã hoàn thành công việc. Sự cố chuyển sang "Đã xong".'
          : 'Đã bắt đầu xử lý công việc.');
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
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const GradientHeader(title: 'Chi Tiết Công Việc', showBack: true),
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
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Thông tin công việc
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TASK-${task.id}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textTertiary),
                    ),
                  ),
                  _statusBadge(task.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                task.title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              if (task.description != null &&
                  task.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description!,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4),
                ),
              ],
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Người giao',
                value: task.assignedByName,
              ),
              _InfoRow(
                icon: Icons.schedule,
                label: 'Giao lúc',
                value: _formatDate(task.assignedAt),
              ),
              if (task.completedAt != null)
                _InfoRow(
                  icon: Icons.check_circle_outline,
                  label: 'Hoàn thành',
                  value: _formatDate(task.completedAt!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Thẻ tham chiếu sự cố gốc (FID-23 field 7)
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Sự cố liên quan'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '#TK-${task.ticketId}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.infoBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      task.category,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Căn hộ',
                value: 'Phòng ${task.unitNumber}',
              ),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Người báo',
                value: task.residentName,
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  task.ticketDescription,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                ),
              ),
            ],
          ),
        ),

        // 3. Ảnh hiện trạng từ cư dân (read-only - FID-23 field 8/9)
        if (task.ticketBeforeImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                    'Ảnh hiện trạng (${task.ticketBeforeImages.length})'),
                const SizedBox(height: 4),
                const Text(
                  'Ảnh do cư dân cung cấp khi báo sự cố.',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                _imageWrap(task.ticketBeforeImages),
              ],
            ),
          ),
        ],

        // 4. Ảnh nghiệm thu đã lưu (task xong)
        if (task.completionImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Ảnh nghiệm thu (${task.completionImages.length})'),
                const SizedBox(height: 10),
                _imageWrap(task.completionImages),
              ],
            ),
          ),
        ],

        // 5. Khối cập nhật tiến độ - chỉ khi task còn mở (PRE-02)
        if (task.isOpen) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Cập nhật tiến độ'),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 500,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú tiến độ (tùy chọn)',
                    hintText: 'Đã làm gì, thay vật tư nào...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Ảnh nghiệm thu (bắt buộc ≥1 khi hoàn thành, tối đa $_maxImages)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                const Text(
                  'Ảnh JPG/PNG, tự động nén trước khi gửi.',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
                      ..._images.asMap().entries.map(
                            (e) => _pickedThumbnail(e.key, e.value),
                          ),
                      if (_images.length < _maxImages) _addImageButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (task.status == 'ASSIGNED') ...[
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('BẮT ĐẦU LÀM',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : _start,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('ĐÁNH DẤU HOÀN THÀNH',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : _complete,
                  ),
                ),
              ],
            ),
          ),
        ],

        // 6. Ghi chú tiến độ đã lưu (task đã đóng - read-only)
        if (!task.isOpen &&
            task.progressNotes != null &&
            task.progressNotes!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Ghi chú tiến độ'),
                const SizedBox(height: 8),
                Text(
                  task.progressNotes!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
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

  /// Ô "+" thêm ảnh nghiệm thu (viền đứt - FID-23 field 11).
  Widget _addImageButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inactive),
          color: AppColors.divider,
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
            : const Icon(Icons.add_a_photo_outlined,
                color: AppColors.textTertiary),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
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
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
