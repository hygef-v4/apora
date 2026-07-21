import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../widgets/ticket_category.dart';

/// UC20 - Chi tiết sự cố (theo màn FID-20).
/// - MANAGER/LANDLORD: xem đầy đủ + đổi trạng thái (BR-40) + ghi chú nội bộ.
/// - RESIDENT: chỉ đọc sự cố của chính mình (BR-39), không có khối cập nhật.
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

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  StatusBadge _statusBadge(String status) {
    final label = kTicketStatusLabels[status] ?? status;
    switch (status) {
      case 'RESOLVED':
        return StatusBadge.success(label);
      case 'PROCESSING':
        return StatusBadge.warning(label);
      case 'ASSIGNED':
        return StatusBadge.info(label);
      case 'CANCELLED':
        return const StatusBadge(
          text: 'Cancelled',
          color: Color(0xFF64748B),
          backgroundColor: Color(0xFFF1F5F9),
        );
      default: // PENDING - cam (FID-20 field 1)
        return const StatusBadge(
          text: 'Pending',
          color: Color(0xFFEA580C),
          backgroundColor: Color(0xFFFFEDD5),
        );
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
          Container(
            decoration: isManager
                ? const BoxDecoration(gradient: AppColors.headerGradient)
                : const BoxDecoration(gradient: AppColors.residentGradient),
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Text(
                      'Ticket Detail',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Tổng quan: mã ticket + badge trạng thái + danh mục + thời gian
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '#TK-${ticket.id}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _statusBadge(ticket.status),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ticketCategoryLabel(ticket.category),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.schedule,
                label: 'Created',
                value: _formatDate(ticket.createdAt),
              ),
              _InfoRow(
                icon: Icons.update,
                label: 'Last Updated',
                // Chưa từng cập nhật -> hiện "—" (theo screen definition)
                value: ticket.updatedAt.isAfter(ticket.createdAt)
                    ? _formatDate(ticket.updatedAt)
                    : '—',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Người báo cáo
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Reported By'),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.person_outline,
                label: 'Full Name',
                value: ticket.residentName,
              ),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Apartment',
                value: 'Room ${ticket.unitNumber}',
              ),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'SĐT',
                value: ticket.residentPhone,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2.5. Nhân viên xử lý (Assigned Staff)
        if (ticket.assignedTask != null) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Assigned Staff'),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.engineering_outlined,
                  label: 'Full Name',
                  value: ticket.assignedTask!.assigneeName,
                ),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'SĐT',
                  value: ticket.assignedTask!.assigneePhone ?? '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ] else if (isManager && ticket.status == 'PENDING') ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Assigned Staff'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'No staff assigned yet',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final assigned = await context.push<bool>(
                          AppRoutes.ticketAssignPath(ticket.id),
                          extra: ticket,
                        );
                        if (assigned == true && mounted) {
                          ref.read(ticketDetailProvider.notifier).fetch(widget.ticketId);
                        }
                      },
                      icon: const Icon(Icons.add, size: 16, color: Color(0xFF149EE7)),
                      label: const Text(
                        'Assign',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF149EE7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 3. Mô tả sự cố
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Issue Description'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ticket.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 4. Ảnh đính kèm (nếu có) - bấm để xem full
        if (ticket.beforeImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Attached Photos (${ticket.beforeImages.length})'),
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
            ),
          ),
        ],



        // 6. Khối cập nhật - chỉ MANAGER/LANDLORD (BR-39)
        if (isManager) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Update Status'),
                const SizedBox(height: 10),
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
                      labelText: 'New Status',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    hint: Text(
                      'Current: ${kTicketStatusLabels[ticket.status]}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    items: [
                      for (final s in nextStatuses)
                        DropdownMenuItem(
                          value: s,
                          child: Text(
                            kTicketStatusLabels[s] ?? s,
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
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  maxLength: 500,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    labelText: 'Internal Notes (optional)',
                    hintText: 'Notes for the handling team...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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
                        : const Text('SAVE CHANGES',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
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
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
            const Icon(Icons.error_outline, size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
