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

/// UC29 (FID-29): Apartment Directory & Statistics.
/// Search by unit number or owner name.
/// Filters: All, Empty, Occupied, Has Debt.
/// Summary Stats: Total, Occupied, Empty, Has Debt.
class ApartmentListScreen extends ConsumerStatefulWidget {
  const ApartmentListScreen({super.key, this.showBack = false});

  final bool showBack;

  @override
  ConsumerState<ApartmentListScreen> createState() => _ApartmentListScreenState();
}

class _ApartmentListScreenState extends ConsumerState<ApartmentListScreen> {
  Timer? _debounce;
  final _searchController = TextEditingController();
  String? _selectedFilter; // null = All, 'EMPTY', 'OCCUPIED', 'HAS_DEBT'
  String _searchQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String keyword) {
    setState(() {
      _searchQuery = keyword.trim().toLowerCase();
    });
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

    final list = apartmentsAsync.value ?? [];
    final totalCount = list.length;
    final occupiedCount = list.where((a) => a.status == 'OCCUPIED').length;
    final emptyCount = list.where((a) => a.status == 'EMPTY').length;
    final hasDebtCount = list.where((a) => a.unpaidInvoiceCount > 0).length;

    // Client-side filtering for smooth UI transitions
    final filteredList = list.where((apt) {
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final unitMatch = apt.unitNumber.toLowerCase().contains(_searchQuery);
        final ownerMatch = apt.ownerName?.toLowerCase().contains(_searchQuery) ?? false;
        if (!unitMatch && !ownerMatch) return false;
      }

      // Tab filter
      if (_selectedFilter == 'OCCUPIED') {
        return apt.status == 'OCCUPIED';
      } else if (_selectedFilter == 'EMPTY') {
        return apt.status == 'EMPTY';
      } else if (_selectedFilter == 'HAS_DEBT') {
        return apt.unpaidInvoiceCount > 0;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isManagement
          ? FloatingActionButton(
              onPressed: () => context.push('/manager/apartments/create'),
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              tooltip: 'Add Apartment',
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          GradientHeader(
            title: 'APARTMENT MANAGEMENT',
            showBack: widget.showBack,
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
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (_) => RefreshIndicator(
                onRefresh: notifier.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    // 1. Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border, width: 1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search room number or owner name',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Filter Pills
                    FilterPills<String?>(
                      pills: const [
                        FilterPill(value: null, label: 'All'),
                        FilterPill(value: 'EMPTY', label: 'Empty'),
                        FilterPill(value: 'OCCUPIED', label: 'Occupied'),
                        FilterPill(
                          value: 'HAS_DEBT',
                          label: 'Has Debt',
                          color: AppColors.error,
                        ),
                      ],
                      selected: _selectedFilter,
                      onSelected: (value) => setState(() => _selectedFilter = value),
                    ),
                    const SizedBox(height: 14),

                    // 3. Summary Stats 2x2 Grid
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total Apartments',
                            value: '$totalCount',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: 'Occupied',
                            value: '$occupiedCount',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Empty',
                            value: '$emptyCount',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatCard(
                            title: 'Has Debt',
                            value: '$hasDebtCount',
                            isWarning: hasDebtCount > 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 4. Apartments List
                    if (filteredList.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 36),
                        child: Center(
                          child: Text(
                            'No apartments found matching criteria.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    else
                      ...filteredList.map(
                        (apt) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
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

/// Stat card widget matching wireframe statistics block
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    this.isWarning = false,
  });

  final String title;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isWarning ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Apartment list item card matching wireframe layout
class _ApartmentCard extends StatelessWidget {
  const _ApartmentCard({required this.apartment, required this.onTap});

  final Apartment apartment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnpaid = apartment.unpaidInvoiceCount > 0;
    final unpaidText = hasUnpaid
        ? '${apartment.unpaidInvoiceCount} unpaid ${apartment.unpaidInvoiceCount == 1 ? 'bill' : 'bills'}'
        : '0 bills';

    final ticketsText =
        '${apartment.unresolvedTicketCount} ${apartment.unresolvedTicketCount == 1 ? 'ticket' : 'tickets'}';

    late final StatusBadge statusBadge;
    if (apartment.status == 'INACTIVE') {
      statusBadge = StatusBadge.warning('REPAIR');
    } else if (apartment.status == 'OCCUPIED') {
      statusBadge = const StatusBadge(
        text: 'OCCUPIED',
        color: Colors.white,
        backgroundColor: AppColors.navy,
      );
    } else {
      statusBadge = const StatusBadge(
        text: 'EMPTY',
        color: AppColors.textSecondary,
        backgroundColor: AppColors.border,
      );
    }

    final ownerDisplayName = apartment.status == 'EMPTY' ||
            apartment.ownerName == null ||
            apartment.ownerName!.trim().isEmpty
        ? 'No owner'
        : apartment.ownerName!.trim();

    final isNoOwner = ownerDisplayName == 'No owner';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Unit Number + Status Badge + Chevron Arrow
          Row(
            children: [
              Text(
                apartment.unitNumber,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              statusBadge,
              const Spacer(),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Owner Name
          Text(
            ownerDisplayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isNoOwner ? FontWeight.normal : FontWeight.w600,
              fontStyle: isNoOwner ? FontStyle.italic : FontStyle.normal,
              color: isNoOwner ? AppColors.textTertiary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),

          // Row 3: Metrics (Unpaid Bills & Repair Tickets)
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 16,
                color: hasUnpaid ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                unpaidText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: hasUnpaid ? FontWeight.w700 : FontWeight.w500,
                  color: hasUnpaid ? AppColors.error : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.confirmation_number_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                ticketsText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

