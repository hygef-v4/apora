import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';

/// UC18 - Danh sách sự cố (theo màn FID-18).
/// Đã được thiết kế lại theo mockup giao diện cao cấp:
/// - Bộ lọc trạng thái: Tất cả, Mới, Đang xử lý, Xong.
/// - Mỗi thẻ sự cố có thanh viền trái hiển thị màu sắc theo trạng thái của sự cố.
/// - Không hiển thị mức độ ưu tiên (Cao/Trung bình/Thấp) và số điện thoại của người báo.
class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> {
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

  String _getRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return 'Vừa xong';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes.clamp(1, 59)} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} ngày trước';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFEA580C); // Cam đỏ
      case 'ASSIGNED':
        return const Color(0xFF0284C7); // Xanh dương
      case 'PROCESSING':
        return const Color(0xFFD97706); // Vàng cam
      case 'RESOLVED':
        return const Color(0xFF16A34A); // Xanh lá
      case 'CANCELLED':
        return const Color(0xFF64748B); // Xám
      default:
        return const Color(0xFF149EE7);
    }
  }

  Widget _buildStatusBadge(String status) {
    switch (status) {
      case 'RESOLVED':
        return StatusBadge.success('Đã xong');
      case 'ASSIGNED':
        return const StatusBadge(
          text: 'Đã phân công',
          color: Color(0xFF0284C7),
          backgroundColor: Color(0xFFF0F9FF),
        );
      case 'PROCESSING':
        return StatusBadge.warning('Đang xử lý');
      case 'CANCELLED':
        return const StatusBadge(
          text: 'Đã hủy',
          color: Color(0xFF64748B),
          backgroundColor: Color(0xFFF1F5F9),
        );
      default:
        return const StatusBadge(
          text: 'Chờ xử lý',
          color: Color(0xFFEA580C),
          backgroundColor: Color(0xFFFFF7ED),
        );
    }
  }

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

    // UC19: chỉ cư dân (RESIDENT) mới được tạo báo sự cố; Manager/Landlord chỉ xem & phân công.
    final isResident = ref.watch(authNotifierProvider).user?.isResident ?? false;

    // Tính toán số lượng cho từng tab bộ lọc
    final total = state.tickets.length;
    final pendingCount = state.tickets.where((t) => t.status == 'PENDING').length;
    final assignedCount = state.tickets.where((t) => t.status == 'ASSIGNED').length;
    final processingCount = state.tickets.where((t) => t.status == 'PROCESSING').length;
    final resolvedCount = state.tickets.where((t) => t.status == 'RESOLVED').length;
    final cancelledCount = state.tickets.where((t) => t.status == 'CANCELLED').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF149EE7), // Đồng bộ màu xanh dương sáng của ứng dụng
            width: double.infinity,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    if (widget.showBack)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bảo trì',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$processingCount đang xử lý · $pendingCount mới',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(_searchOpen ? Icons.search_off : Icons.search, color: Colors.white),
                      tooltip: 'Tìm kiếm',
                      onPressed: () => setState(() {
                        _searchOpen = !_searchOpen;
                        if (!_searchOpen) _searchController.clear();
                      }),
                    ),
                    if (isResident)
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        tooltip: 'Báo sự cố',
                        onPressed: () async {
                          await context.push(AppRoutes.ticketCreate);
                          if (mounted) ref.read(ticketProvider.notifier).fetchTickets();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm theo người báo, số phòng...',
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
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          // Tab bộ lọc theo mockup
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabItem(
                    label: 'Tất cả ($total)',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                    selectedBgColor: const Color(0xFF1E293B),
                    selectedTextColor: Colors.white,
                    unselectedTextColor: const Color(0xFF64748B),
                    borderColor: const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 8),
                  _buildTabItem(
                    label: 'Chờ xử lý ($pendingCount)',
                    selected: _filter == 'PENDING',
                    onTap: () => setState(() => _filter = 'PENDING'),
                    selectedBgColor: const Color(0xFFFFF7ED),
                    selectedTextColor: const Color(0xFFEA580C),
                    unselectedTextColor: const Color(0xFFEA580C),
                    borderColor: const Color(0xFFFFEDD5),
                  ),
                  const SizedBox(width: 8),
                  _buildTabItem(
                    label: 'Đã phân công ($assignedCount)',
                    selected: _filter == 'ASSIGNED',
                    onTap: () => setState(() => _filter = 'ASSIGNED'),
                    selectedBgColor: const Color(0xFFF0F9FF),
                    selectedTextColor: const Color(0xFF0284C7),
                    unselectedTextColor: const Color(0xFF0284C7),
                    borderColor: const Color(0xFFE0F2FE),
                  ),
                  const SizedBox(width: 8),
                  _buildTabItem(
                    label: 'Đang xử lý ($processingCount)',
                    selected: _filter == 'PROCESSING',
                    onTap: () => setState(() => _filter = 'PROCESSING'),
                    selectedBgColor: const Color(0xFFFFFBEB),
                    selectedTextColor: const Color(0xFFD97706),
                    unselectedTextColor: const Color(0xFFD97706),
                    borderColor: const Color(0xFFFEF3C7),
                  ),
                  const SizedBox(width: 8),
                  _buildTabItem(
                    label: 'Đã xong ($resolvedCount)',
                    selected: _filter == 'RESOLVED',
                    onTap: () => setState(() => _filter = 'RESOLVED'),
                    selectedBgColor: const Color(0xFFF0FDF4),
                    selectedTextColor: const Color(0xFF16A34A),
                    unselectedTextColor: const Color(0xFF16A34A),
                    borderColor: const Color(0xFFBBF7D0),
                  ),
                  const SizedBox(width: 8),
                  _buildTabItem(
                    label: 'Đã hủy ($cancelledCount)',
                    selected: _filter == 'CANCELLED',
                    onTap: () => setState(() => _filter == 'CANCELLED'),
                    selectedBgColor: const Color(0xFFF1F5F9),
                    selectedTextColor: const Color(0xFF64748B),
                    unselectedTextColor: const Color(0xFF64748B),
                    borderColor: const Color(0xFFE2E8F0),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color selectedBgColor,
    required Color selectedTextColor,
    required Color unselectedTextColor,
    required Color borderColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? selectedBgColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedBgColor : borderColor,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? selectedTextColor : unselectedTextColor,
          ),
        ),
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
        onRetry: () => notifier.fetchTickets(),
      );
    }
    final visible = _applyFilters(state.tickets);
    if (visible.isEmpty) {
      final searching = _searchController.text.trim().isNotEmpty;
      return _emptyOrError(
        icon: Icons.build_circle_outlined,
        message: searching
            ? 'Không tìm thấy sự cố nào khớp từ khóa.'
            : 'Không có sự cố nào.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.fetchTickets(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: visible.length,
        itemBuilder: (_, i) => _ticketCard(visible[i]),
      ),
    );
  }

  Widget _ticketCard(Ticket t) {
    final statusColor = _getStatusColor(t.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
          border: Border.all(
            color: statusColor.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await context.push(AppRoutes.ticketDetailPath(t.id));
            if (!mounted) return;
            ref.read(ticketProvider.notifier).fetchTickets();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.unitNumber,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      _getRelativeTime(t.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  t.category,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        t.description,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(t.status),
                  ],
                ),
              ],
            ),
          ),
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
