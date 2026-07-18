import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/filter_pills.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/apartment.dart';
import '../providers/apartment_notifier.dart';

/// UC29 (FID-29): Danh sách căn hộ.
/// Cho phép tìm kiếm theo số phòng hoặc tên chủ hộ.
/// Bộ lọc trạng thái: Tất cả, Đang thuê, Trống, Bảo trì.
class ApartmentListScreen extends ConsumerStatefulWidget {
  const ApartmentListScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  ConsumerState<ApartmentListScreen> createState() => _ApartmentListScreenState();
}

class _ApartmentListScreenState extends ConsumerState<ApartmentListScreen> {
  Timer? _debounce;
  final _searchController = TextEditingController();
  bool _showSearch = false;
  String? _selectedFilter;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String keyword) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(apartmentDirectoryProvider.notifier).setSearch(keyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentDirectoryProvider);
    final notifier = ref.read(apartmentDirectoryProvider.notifier);
    final userRoles = ref.watch(authNotifierProvider).user?.roles ?? const [];
    final isManagement = userRoles.contains('LANDLORD') || userRoles.contains('MANAGER');

    // Dữ liệu thô từ provider để tính toán số liệu trên các tab bộ lọc
    final list = apartmentsAsync.value ?? [];
    final total = list.length;
    final occupied = list.where((a) => a.status == 'OCCUPIED').length;
    final empty = list.where((a) => a.status == 'EMPTY').length;
    final repair = list.where((a) => a.unresolvedTicketCount > 0).length;

    // Áp dụng bộ lọc client-side cho mượt mà
    final filteredList = list.where((apt) {
      if (_selectedFilter == 'OCCUPIED') {
        return apt.status == 'OCCUPIED';
      } else if (_selectedFilter == 'EMPTY') {
        return apt.status == 'EMPTY';
      } else if (_selectedFilter == 'REPAIR') {
        return apt.unresolvedTicketCount > 0;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            title: 'Căn hộ',
            showBack: widget.showBack,
            actions: [
              HeaderIconButton(
                icon: Icons.search,
                tooltip: 'Tìm kiếm',
                onTap: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      notifier.setSearch('');
                    }
                  });
                },
              ),
              if (isManagement)
                HeaderIconButton(
                  icon: Icons.add,
                  tooltip: 'Thêm căn hộ',
                  onTap: () => context.push('/manager/apartments/create'),
                ),
            ],
            bottom: _showSearch
                ? HeaderSearchBar(
                    hint: 'Tìm số phòng, tên chủ hộ...',
                    onChanged: _onSearchChanged,
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: FilterPills<String?>(
              pills: [
                FilterPill(value: null, label: 'Tất cả ($total)'),
                FilterPill(
                  value: 'OCCUPIED',
                  label: 'Đang thuê ($occupied)',
                  color: AppColors.success,
                ),
                FilterPill(
                  value: 'EMPTY',
                  label: 'Trống ($empty)',
                  color: AppColors.primary,
                ),
                FilterPill(
                  value: 'REPAIR',
                  label: 'Bảo trì ($repair)',
                  color: AppColors.warning,
                ),
              ],
              selected: _selectedFilter,
              onSelected: (value) => setState(() => _selectedFilter = value),
            ),
          ),
          Expanded(
            child: apartmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(mapDioError(error), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: notifier.refresh,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (_) => RefreshIndicator(
                onRefresh: notifier.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  children: [
                    if (filteredList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(
                          child: Text(
                            'Không tìm thấy căn hộ nào khớp điều kiện.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ...filteredList.map(
                        (apt) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ApartmentCard(
                            apartment: apt,
                            onTap: () => context.push('/manager/apartments/${apt.id}'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApartmentCard extends StatelessWidget {
  const _ApartmentCard({required this.apartment, required this.onTap});

  final Apartment apartment;
  final VoidCallback onTap;

  String _getPrefix(String unitNumber) {
    if (unitNumber.length >= 3) {
      return unitNumber.substring(0, 3);
    }
    return unitNumber;
  }

  Color _getPrefixColor(String prefix) {
    final letter = prefix.isNotEmpty ? prefix[0].toUpperCase() : 'A';
    switch (letter) {
      case 'A':
        if (prefix.length >= 2) {
          if (prefix[1] == '1') return const Color(0xFF2563EB); // Blue
          if (prefix[1] == '2') return const Color(0xFF059669); // Emerald
        }
        return const Color(0xFF2563EB);
      case 'B':
        return const Color(0xFF7C3AED); // Purple
      case 'C':
        return const Color(0xFF0EA5E9); // Cyan
      case 'D':
        return const Color(0xFFEF4444); // Red
      case 'E':
        return const Color(0xFFF59E0B); // Amber
      default:
        return const Color(0xFF2563EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefix = _getPrefix(apartment.unitNumber);
    final prefixColor = _getPrefixColor(prefix);

    // Xác định badge trạng thái khớp thiết kế
    late final StatusBadge statusBadge;
    if (apartment.unresolvedTicketCount > 0) {
      statusBadge = StatusBadge.warning('Bảo trì');
    } else if (apartment.status == 'OCCUPIED') {
      statusBadge = StatusBadge.success('Đang thuê');
    } else {
      statusBadge = StatusBadge(
        text: 'Trống',
        color: AppColors.primary,
        backgroundColor: AppColors.infoBg,
      );
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: prefixColor,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              prefix,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Căn hộ ${apartment.unitNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tầng ${apartment.floor} · ${apartment.areaSize.toStringAsFixed(0)}m²',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  apartment.status == 'EMPTY'
                      ? '— Căn trống'
                      : (apartment.ownerName ?? 'Chưa có chủ hộ'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: apartment.status == 'EMPTY' ? FontWeight.normal : FontWeight.w500,
                    color: apartment.status == 'EMPTY' ? AppColors.textTertiary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          statusBadge,
        ],
      ),
    );
  }
}
