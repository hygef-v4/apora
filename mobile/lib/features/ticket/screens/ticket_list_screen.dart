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

/// UC18 - Danh sách sự cố (theo màn FID-18). Dùng chung cho Resident
/// (sự cố của mình) và Manager (toàn bộ) - backend tự phân luồng theo vai trò.
/// Tải toàn bộ 1 lần rồi lọc phía client: tab đếm được số "Chờ xử lý"
/// (field 2) và ô tìm kiếm lọc realtime (AT3) không cần gọi lại API.
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

  /// Badge màu theo FID-18 field 4: PENDING cam, ASSIGNED xanh dương,
  /// PROCESSING vàng, RESOLVED xanh lá, CANCELLED đỏ.
  StatusBadge _statusBadge(String status) {
    final label = kTicketStatusLabels[status] ?? status;
    switch (status) {
      case 'RESOLVED':
        return StatusBadge.success(label);
      case 'ASSIGNED':
        return StatusBadge.info(label);
      case 'PROCESSING':
        return StatusBadge.warning(label);
      case 'CANCELLED':
        return StatusBadge(
          text: label,
          color: AppColors.error,
          backgroundColor: AppColors.errorBg,
        );
      default: // PENDING - cam
        return const StatusBadge(
          text: 'Chờ xử lý',
          color: Color(0xFFEA580C),
          backgroundColor: Color(0xFFFFEDD5),
        );
    }
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  /// AT3: lọc realtime theo mã sự cố, tên người báo hoặc số phòng.
  List<Ticket> _applyFilters(List<Ticket> all) {
    var list = _filter == null
        ? all
        : all.where((t) => t.status == _filter).toList();
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
    final isResident = ref.watch(authNotifierProvider).roles.contains('RESIDENT');
    final pendingCount =
        state.tickets.where((t) => t.status == 'PENDING').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      floatingActionButton: isResident
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push(AppRoutes.ticketCreate);
                // Quay lại từ màn tạo -> làm mới danh sách
                if (context.mounted) notifier.fetchTickets();
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
              // FID-18 field 1: mở/đóng thanh tìm kiếm (AT3)
              HeaderIconButton(
                icon: _searchOpen ? Icons.search_off : Icons.search,
                tooltip: 'Tìm kiếm',
                onTap: () => setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) _searchController.clear();
                }),
              ),
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: 'Làm mới',
                onTap: () => notifier.fetchTickets(),
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
                  hintText: 'Tìm theo mã (TK-1), tên người báo, số phòng...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () =>
                              setState(_searchController.clear),
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
          // Thanh lọc trạng thái - tab "Chờ xử lý" kèm số lượng (field 2)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filter == f.value;
                final label = f.value == 'PENDING' && pendingCount > 0
                    ? '${f.label} ($pendingCount)'
                    : f.label;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = f.value),
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
        onRetry: () => notifier.fetchTickets(),
      );
    }
    final visible = _applyFilters(state.tickets);
    if (visible.isEmpty) {
      // AT1/AT2: trạng thái rỗng chung / theo bộ lọc-tìm kiếm đang chọn
      final searching = _searchController.text.trim().isNotEmpty;
      return _emptyOrError(
        icon: Icons.inbox_outlined,
        message: searching
            ? 'Không tìm thấy sự cố nào khớp từ khóa.'
            : _filter == null
                ? 'Chưa có sự cố nào.'
                : 'Không có sự cố "${kTicketStatusLabels[_filter]}" nào.',
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => notifier.fetchTickets(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: visible.length,
        itemBuilder: (_, i) => _ticketCard(visible[i]),
      ),
    );
  }

  Widget _ticketCard(Ticket t) {
    // FID-18 field 9: tên nhân viên chỉ hiện khi ASSIGNED / PROCESSING
    final showAssignee = t.assigneeName != null &&
        (t.status == 'ASSIGNED' || t.status == 'PROCESSING');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        // UC20 (TRG-01): bấm thẻ mở chi tiết; quay lại làm mới danh sách
        // (Manager có thể vừa đổi trạng thái trong màn chi tiết).
        onTap: () async {
          await context.push(AppRoutes.ticketDetailPath(t.id));
          if (!mounted) return;
          ref.read(ticketProvider.notifier).fetchTickets();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // FID-18 field 3: mã sự cố "#TK-XXX"
                Expanded(
                  child: Text(
                    '#TK-${t.id}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary),
                  ),
                ),
                _statusBadge(t.status),
              ],
            ),
            const SizedBox(height: 6),
            Row(
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
            const SizedBox(height: 8),
            Text(
              t.description,
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // FID-18 field 8: người báo sự cố
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(t.reporterName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
                const Icon(Icons.location_on_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('Phòng ${t.unitNumber}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            if (showAssignee) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.engineering_outlined,
                      size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Giao cho: ${t.assigneeName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                if (t.beforeImages.isNotEmpty) ...[
                  const Icon(Icons.image_outlined,
                      size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('${t.beforeImages.length} ảnh',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
                const Spacer(),
                const Icon(Icons.schedule,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(_formatDate(t.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
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
