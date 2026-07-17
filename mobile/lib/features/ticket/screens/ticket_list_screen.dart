import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';

/// UC18 - Danh sách sự cố. Dùng chung cho Resident (sự cố của mình) và
/// Manager (toàn bộ) - backend tự phân luồng theo vai trò.
class TicketListScreen extends ConsumerStatefulWidget {
  /// true khi mở bằng push (Manager) -> hiện nút back; false khi nhúng làm tab
  /// trong Home cư dân -> không có nút back.
  const TicketListScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> {
  /// Bộ lọc trạng thái trên thanh chip. null = Tất cả.
  static const List<({String? value, String label})> _filters = [
    (value: null, label: 'Tất cả'),
    (value: 'PENDING', label: 'Chờ xử lý'),
    (value: 'ASSIGNED', label: 'Đã phân công'),
    (value: 'PROCESSING', label: 'Đang xử lý'),
    (value: 'RESOLVED', label: 'Đã xong'),
    (value: 'CANCELLED', label: 'Đã hủy'),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(ticketProvider.notifier).fetchTickets());
  }

  StatusBadge _statusBadge(String status) {
    final label = kTicketStatusLabels[status] ?? status;
    switch (status) {
      case 'RESOLVED':
        return StatusBadge.success(label);
      case 'PROCESSING':
      case 'ASSIGNED':
        return StatusBadge.warning(label);
      case 'CANCELLED':
        return const StatusBadge(
          text: 'Đã hủy',
          color: AppColors.error,
          backgroundColor: AppColors.errorBg,
        );
      default: // PENDING
        return StatusBadge(
          text: label,
          color: AppColors.textSecondary,
          backgroundColor: AppColors.divider,
        );
    }
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ticketProvider);
    final notifier = ref.read(ticketProvider.notifier);
    final isResident = ref.watch(authNotifierProvider).roles.contains('RESIDENT');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: isResident
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.ticketCreate);
                // Quay lại từ màn tạo -> làm mới theo bộ lọc hiện tại
                if (context.mounted) notifier.fetchTickets(status: state.statusFilter);
              },
              backgroundColor: AppColors.navy,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('BÁO SỰ CỐ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : null,
      body: Column(
        children: [
          GradientHeader(
            title: 'Sự Cố & Sửa Chữa',
            subtitle: 'Theo dõi các yêu cầu sửa chữa',
            showBack: widget.showBack,
            actions: [
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: 'Làm mới',
                onTap: () => notifier.fetchTickets(status: state.statusFilter),
              ),
            ],
          ),
          // Thanh lọc trạng thái
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = state.statusFilter == f.value;
                return ChoiceChip(
                  label: Text(f.label),
                  selected: selected,
                  onSelected: (_) => notifier.fetchTickets(status: f.value),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                );
              },
            ),
          ),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(TicketState state, TicketNotifier notifier) {
    if (state.isLoading && state.tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (state.errorMessage != null && state.tickets.isEmpty) {
      return _emptyOrError(
        icon: Icons.error_outline,
        message: state.errorMessage!,
        onRetry: () => notifier.fetchTickets(status: state.statusFilter),
      );
    }
    if (state.tickets.isEmpty) {
      return _emptyOrError(
        icon: Icons.inbox_outlined,
        message: 'Chưa có sự cố nào.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.fetchTickets(status: state.statusFilter),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.tickets.length,
        itemBuilder: (_, i) => _ticketCard(state.tickets[i]),
      ),
    );
  }

  Widget _ticketCard(Ticket t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        // UC20 (TRG-01): bấm thẻ mở chi tiết; quay lại làm mới theo bộ lọc
        // hiện tại (Manager có thể vừa đổi trạng thái trong màn chi tiết).
        onTap: () async {
          await context.push(AppRoutes.ticketDetailPath(t.id));
          if (!mounted) return;
          final notifier = ref.read(ticketProvider.notifier);
          notifier.fetchTickets(status: ref.read(ticketProvider).statusFilter);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.build_circle_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          t.category,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusBadge(t.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              t.description,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('Phòng ${t.unitNumber}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const Spacer(),
                const Icon(Icons.schedule,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(_formatDate(t.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            if (t.beforeImages.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.image_outlined,
                      size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('${t.beforeImages.length} ảnh',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyOrError({
    required IconData icon,
    required String message,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ],
      ),
    );
  }
}
