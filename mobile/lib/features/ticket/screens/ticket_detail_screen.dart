import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/spec_layout.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../widgets/ticket_category.dart';

/// UC20 - Ticket Detail (bố cục theo wireframe FID-20 trong SRS).
/// - MANAGER/LANDLORD: xem đầy đủ + đổi trạng thái (BR-40) + ghi chú nội bộ.
/// - RESIDENT: chỉ đọc sự cố của chính mình (BR-39), không có khối Admin Action.
class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  /// null = chưa chọn trạng thái mới (giữ nguyên hiện tại).
  String? _selectedStatus;
  final _notesController = TextEditingController();
  bool _isSaving = false;

  /// Ghi chú lấy từ server lần gần nhất - so sánh để phát hiện "chưa đổi gì" (AT4).
  String _serverNotes = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(ticketDetailProvider.notifier).fetch(widget.ticketId),
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
      case 'RESOLVED':
        return StatusBadge.success('RESOLVED');
      case 'PROCESSING':
        return StatusBadge.warning('PROCESSING');
      case 'ASSIGNED':
        return const StatusBadge(
          text: 'ASSIGNED',
          color: AppColors.primary,
          backgroundColor: AppColors.infoBg,
        );
      case 'CANCELLED':
        return StatusBadge.muted('CANCELLED');
      default:
        return StatusBadge.warning('PENDING');
    }
  }

  /// AT3: chọn hủy phải xác nhận trước - hành động không hoàn tác được
  /// (ảnh sự cố sẽ bị xóa vĩnh viễn - BR-38).
  Future<bool> _confirmCancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel ticket?'),
        content: const Text(
          'Are you sure you want to cancel this ticket? This action cannot be '
          'undone and attached photos will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _save(TicketDetail ticket) async {
    final newStatus = _selectedStatus ?? ticket.status;
    final notes = _notesController.text.trim();
    final statusChanged = newStatus != ticket.status;
    final notesChanged = notes.isNotEmpty && notes != _serverNotes;

    // AT4: không đổi trạng thái và không có ghi chú mới -> chặn lưu
    if (!statusChanged && !notesChanged) {
      _showSnack('No changes to save.');
      return;
    }
    // AT3: hủy phải xác nhận
    if (statusChanged && newStatus == 'CANCELLED' && !await _confirmCancel()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(ticketDetailProvider.notifier).updateStatus(
            widget.ticketId,
            status: newStatus,
            internalNotes: notesChanged ? notes : null,
          );
      setState(() => _selectedStatus = null);
      _showSnack('Ticket updated successfully.');
    } catch (e) {
      // AT2: lỗi mạng/server -> báo SnackBar, giữ nguyên dữ liệu đã nhập
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ticketDetailProvider);
    final roles = ref.watch(authNotifierProvider).roles;
    final isManager = roles.contains('MANAGER') || roles.contains('LANDLORD');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(title: 'Ticket Detail', showBack: true),
          Expanded(
            child: state.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => _ErrorRetry(
                message: e.toString(),
                onRetry: () => ref
                    .read(ticketDetailProvider.notifier)
                    .fetch(widget.ticketId),
              ),
              data: (ticket) {
                if (ticket == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                return _buildContent(ticket, isManager);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(TicketDetail ticket, bool isManager) {
    // Đồng bộ ghi chú từ server vào ô nhập (chỉ khi user chưa gõ gì khác)
    final serverNotes = ticket.internalNotes ?? '';
    if (_serverNotes != serverNotes) {
      _serverNotes = serverNotes;
      _notesController.text = serverNotes;
    }
    final nextStatuses = kTicketNextStatuses[ticket.status] ?? const <String>[];
    final updated = ticket.updatedAt.isAfter(ticket.createdAt)
        ? _formatDateTime(ticket.updatedAt)
        : '—';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // Badge trạng thái (FID-20 field 1)
        Align(
          alignment: Alignment.centerRight,
          child: _statusBadge(ticket.status),
        ),
        const SizedBox(height: 14),

        // TICKET INFO
        const SpecSectionHeader('Ticket Info'),
        SpecDetailRow(
          label: 'Ticket ID',
          value: '#TK-${ticket.id.toString().padLeft(3, '0')}',
        ),
        SpecDetailRow.widget(
          label: 'Category',
          child: _CategoryChip(category: ticket.category),
        ),
        SpecDetailRow(label: 'Created', value: _formatDateTime(ticket.createdAt)),
        SpecDetailRow(label: 'Last Updated', value: updated),
        const SizedBox(height: 18),

        // REPORTED BY
        const SpecSectionHeader('Reported By'),
        SpecDetailRow(label: 'Resident', value: ticket.residentName),
        SpecDetailRow(label: 'Apartment', value: 'Room ${ticket.unitNumber}'),
        SpecDetailRow(label: 'Phone', value: ticket.residentPhone),
        const SizedBox(height: 18),

        // ISSUE DESCRIPTION
        const SpecSectionHeader('Issue Description'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            ticket.description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),

        // ATTACHED PHOTOS
        if (ticket.beforeImages.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(child: SpecSectionHeader('Attached Photos')),
              Text(
                '${ticket.beforeImages.length} / 3 photos',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final url in ticket.beforeImages)
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
          ),
        ],

        // ASSIGNED TASK (UC21 - nếu có)
        if (ticket.assignedTask != null) ...[
          const SizedBox(height: 18),
          const SpecSectionHeader('Assigned Task'),
          SpecDetailRow(label: 'Title', value: ticket.assignedTask!.title),
          SpecDetailRow(
            label: 'Assignee',
            value: ticket.assignedTask!.assigneeName,
          ),
          SpecDetailRow(
            label: 'Status',
            value: _taskStatusLabel(ticket.assignedTask!.status),
          ),
          SpecDetailRow(
            label: 'Assigned On',
            value: _formatDateTime(ticket.assignedTask!.assignedAt),
          ),
          if (ticket.assignedTask!.completedAt != null)
            SpecDetailRow(
              label: 'Completed On',
              value: _formatDateTime(ticket.assignedTask!.completedAt!),
            ),
        ],

        // UC21: ticket PENDING -> Manager phân công tạo task cho nhân viên
        if (isManager && ticket.status == 'PENDING') ...[
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.assignment_ind_outlined),
              label: const Text(
                'ASSIGN TO STAFF',
                style:
                    TextStyle(fontWeight: FontWeight.bold, letterSpacing: .5),
              ),
              onPressed: () async {
                final assigned = await context.push<bool>(
                  AppRoutes.ticketAssignPath(ticket.id),
                  extra: ticket,
                );
                // Phân công xong -> tải lại chi tiết (đã ASSIGNED + có task)
                if (assigned == true && mounted) {
                  ref
                      .read(ticketDetailProvider.notifier)
                      .fetch(widget.ticketId);
                }
              },
            ),
          ),
        ],

        // ADMIN ACTION - chỉ MANAGER/LANDLORD (BR-39)
        if (isManager) ...[
          const SizedBox(height: 22),
          const SpecSectionHeader('Admin Action'),
          const SizedBox(height: 10),
          const SpecFieldLabel('Update Status'),
          if (nextStatuses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ticket.status == 'RESOLVED'
                    ? 'This ticket is resolved — status can no longer change.'
                    : 'This ticket is cancelled — status can no longer change.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              hint: Text(
                _ticketStatusLabel(ticket.status),
                style: const TextStyle(fontSize: 13),
              ),
              items: [
                for (final s in nextStatuses)
                  DropdownMenuItem(
                    value: s,
                    child: Text(
                      _ticketStatusLabel(s),
                      style: TextStyle(
                        fontSize: 13,
                        color: s == 'CANCELLED'
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
              onChanged: _isSaving
                  ? null
                  : (v) => setState(() => _selectedStatus = v),
            ),
          const SizedBox(height: 14),
          const SpecFieldLabel('Internal Notes / Feedback'),
          TextField(
            controller: _notesController,
            maxLines: 3,
            maxLength: 500,
            enabled: !_isSaving,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add notes for the team or feedback for the resident...',
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
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSaving ? null : () => _save(ticket),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'SAVE CHANGES',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: .5,
                      ),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  /// Xem ảnh full màn hình, chụm/kéo để phóng to.
  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(url)),
            ),
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

/// Nhãn tiếng Anh cho trạng thái sự cố.
String _ticketStatusLabel(String status) => switch (status) {
      'PENDING' => 'Pending',
      'ASSIGNED' => 'Assigned',
      'PROCESSING' => 'Processing',
      'RESOLVED' => 'Resolved',
      'CANCELLED' => 'Cancelled',
      _ => status,
    };

/// Nhãn tiếng Anh cho trạng thái công việc.
String _taskStatusLabel(String status) => switch (status) {
      'ASSIGNED' => 'Assigned',
      'IN_PROGRESS' => 'In Progress',
      'COMPLETED' => 'Completed',
      'CANCELLED' => 'Cancelled',
      _ => status,
    };

/// Chip danh mục nền nhạt, viền, icon + nhãn tiếng Anh (theo wireframe).
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
