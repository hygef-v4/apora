import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../widgets/ticket_category.dart';

/// UC18 - Ticket Management (bố cục theo wireframe FID-18 trong SRS).
/// Tab lọc theo trạng thái: All / Pending / Assigned / Processing.
/// UC19: chỉ RESIDENT được tạo báo sự cố; Manager/Landlord xem & phân công.
class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> {
  /// null = All; ngược lại PENDING / ASSIGNED / PROCESSING.
  String? _filter;
  bool _searchOpen = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(ticketProvider.notifier).fetchTickets());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  List<Ticket> _applyFilters(List<Ticket> all) {
    var list = all;
    if (_filter != null) {
      list = all.where((t) => t.status == _filter).toList();
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((t) {
      final id = 'tk-${t.id}';
      return id.contains(q) ||
          '${t.id}' == q ||
          t.reporterName.toLowerCase().contains(q) ||
          t.unitNumber.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ticketProvider);
    final notifier = ref.read(ticketProvider.notifier);

    final isResident = ref.watch(authNotifierProvider).user?.isResident ?? false;

    final total = state.tickets.length;
    final pendingCount =
        state.tickets.where((t) => t.status == 'PENDING').length;
    final assignedCount =
        state.tickets.where((t) => t.status == 'ASSIGNED').length;
    final processingCount =
        state.tickets.where((t) => t.status == 'PROCESSING').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'Ticket Management',
            showBack: widget.showBack,
            actions: [
              HeaderIconButton(
                icon: _searchOpen ? Icons.search_off : Icons.search,
                tooltip: 'Search',
                onTap: () => setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) _searchController.clear();
                }),
              ),
              if (isResident)
                HeaderIconButton(
                  icon: Icons.add,
                  tooltip: 'Report Issue',
                  onTap: () async {
                    await context.push(AppRoutes.ticketCreate);
                    if (mounted) {
                      ref.read(ticketProvider.notifier).fetchTickets();
                    }
                  },
                ),
            ],
          ),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by reporter, room...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(_searchController.clear),
                        ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          // Thanh tab chữ gạch chân theo wireframe
          Container(
            color: AppColors.surface,
            child: Row(
              children: [
                _TabItem(
                  label: 'All',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                _TabItem(
                  label: 'Pending',
                  badgeCount: pendingCount,
                  selected: _filter == 'PENDING',
                  onTap: () => setState(() => _filter = 'PENDING'),
                ),
                _TabItem(
                  label: 'Assigned',
                  badgeCount: assignedCount,
                  selected: _filter == 'ASSIGNED',
                  onTap: () => setState(() => _filter = 'ASSIGNED'),
                ),
                _TabItem(
                  label: 'Processing',
                  badgeCount: processingCount,
                  selected: _filter == 'PROCESSING',
                  onTap: () => setState(() => _filter = 'PROCESSING'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(state, notifier, total)),
        ],
      ),
    );
  }

  Widget _buildBody(TicketState state, TicketNotifier notifier, int total) {
    if (state.isLoading && state.tickets.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (state.errorMessage != null && state.tickets.isEmpty) {
      return _emptyOrError(
        icon: Icons.error_outline,
        message: state.errorMessage!,
        onRetry: () => notifier.fetchTickets(),
      );
    }
    final visible = _applyFilters(state.tickets);
    if (visible.isEmpty) {
      final searching = _searchController.text.trim().isNotEmpty;
      return _emptyOrError(
        icon: Icons.build_circle_outlined,
        message: searching
            ? 'No tickets match your search.'
            : 'No tickets found.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.fetchTickets(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        itemCount: visible.length,
        itemBuilder: (_, i) => _ticketCard(visible[i]),
      ),
    );
  }

  Widget _ticketCard(Ticket t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await context.push(AppRoutes.ticketDetailPath(t.id));
            if (!mounted) return;
            ref.read(ticketProvider.notifier).fetchTickets();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // #TK-001 + badge trạng thái
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '#TK-${t.id.toString().padLeft(3, '0')}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    _statusBadge(t.status),
                  ],
                ),
                const SizedBox(height: 10),
                // Chip danh mục có icon
                _CategoryChip(category: t.category),
                const SizedBox(height: 10),
                // Tiêu đề = mô tả
                Text(
                  t.description,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  'Room ${t.unitNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reported by: ${t.reporterName}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (t.assigneeName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Assigned to: ${t.assigneeName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Created: ${_formatDate(t.createdAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    switch (status) {
      case 'RESOLVED':
        return StatusBadge.success('RESOLVED');
      case 'ASSIGNED':
        return const StatusBadge(
          text: 'ASSIGNED',
          color: AppColors.primary,
          backgroundColor: AppColors.infoBg,
        );
      case 'PROCESSING':
        return StatusBadge.warning('PROCESSING');
      case 'CANCELLED':
        return StatusBadge.muted('CANCELLED');
      default:
        return StatusBadge.warning('PENDING');
    }
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
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tab chữ có gạch chân khi đang chọn (theo wireframe).
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final showCount = badgeCount != null && badgeCount! > 0;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 2.5 : 1,
              ),
            ),
          ),
          child: Text(
            showCount ? '$label ($badgeCount)' : label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

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
