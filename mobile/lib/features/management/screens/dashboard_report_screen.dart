import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/dashboard_stats.dart';
import '../providers/dashboard_notifier.dart';

/// UC35 (FID-40): Manager Dashboard & Statistics Report.
class DashboardReportScreen extends ConsumerStatefulWidget {
  const DashboardReportScreen({super.key});

  @override
  ConsumerState<DashboardReportScreen> createState() => _DashboardReportScreenState();
}

class _DashboardReportScreenState extends ConsumerState<DashboardReportScreen> {
  List<DateTime> _getFilterMonths() {
    final now = DateTime.now();
    return List.generate(12, (index) {
      return DateTime(now.year, now.month - index, 1);
    });
  }

  void _showMonthPicker(String currentFilter) {
    final months = _getFilterMonths();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 12),
                child: Text(
                  'Select Report Month',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: months.length,
                  itemBuilder: (context, index) {
                    final date = months[index];
                    final valStr =
                        '${date.month.toString().padLeft(2, '0')}/${date.year}';
                    final labelStr =
                        '${DateFormat('MMMM').format(date)} ${date.year}';
                    final isSelected = valStr == currentFilter;

                    return ListTile(
                      title: Text(
                        labelStr,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        ref.read(dashboardProvider.notifier).changeMonth(valStr);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDisplayMonth(String monthYearStr) {
    final parts = monthYearStr.split('/');
    if (parts.length == 2) {
      final month = int.tryParse(parts[0]);
      final year = parts[1];
      if (month != null && month >= 1 && month <= 12) {
        const monthNames = [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        return '${monthNames[month - 1]} $year';
      }
    }
    return monthYearStr;
  }

  String _formatNumber(double val) {
    final formatter = NumberFormat('#,###', 'en_US');
    return formatter.format(val);
  }

  @override
  Widget build(BuildContext context) {
    final asyncStats = ref.watch(dashboardProvider);
    final currentMonthStr = ref.watch(dashboardProvider.notifier).monthYear;
    final user = ref.watch(authNotifierProvider).user;
    final userName = user?.fullName ?? 'Admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header matching wireframe top bar with APORA gradient
          GradientHeader(
            title: 'Apartment Manager',
            showBack: false,
            actions: [
              HeaderIconButton(
                icon: Icons.account_circle_outlined,
                tooltip: 'Profile',
                onTap: () => context.push(AppRoutes.profile),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
              child: asyncStats.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          mapDioError(err),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (stats) {
                  final rate = stats.collectionRate;
                  final ratePercent = (rate * 100).toStringAsFixed(0);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                    children: [
                      // Title & Month Dropdown Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Manager Dashboard',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Welcome back, $userName',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => _showMonthPicker(currentMonthStr),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _formatDisplayMonth(currentMonthStr),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 1. Key Metrics 2x2 Grid (Stat Cards with Theme Tints & Icons)
                      Row(
                        children: [
                          Expanded(
                            child: _DashMetricCard(
                              label: 'Total Revenue',
                              value: _formatNumber(stats.totalRevenue),
                              unit: 'VND',
                              icon: Icons.account_balance_wallet_outlined,
                              iconColor: AppColors.primary,
                              bgColor: AppColors.infoBg.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DashMetricCard(
                              label: 'Collected Revenue',
                              value: _formatNumber(stats.collectedRevenue),
                              unit: 'VND',
                              icon: Icons.task_alt_outlined,
                              iconColor: AppColors.success,
                              bgColor: AppColors.successBg.withValues(alpha: 0.6),
                              valueColor: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _DashMetricCard(
                              label: 'Unpaid Bills',
                              value: '${stats.unpaidBillsCount}',
                              icon: Icons.error_outline,
                              iconColor: AppColors.warning,
                              bgColor: AppColors.warningBg.withValues(alpha: 0.6),
                              valueColor: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DashMetricCard(
                              label: 'Unresolved Tickets',
                              value: '${stats.unresolvedTicketsCount}',
                              icon: Icons.build_outlined,
                              iconColor: AppColors.purple,
                              bgColor: AppColors.purpleBg.withValues(alpha: 0.6),
                              valueColor: AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 2. Revenue Collection Donut Chart Card (Theme Colors)
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Revenue Collection',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 100,
                                  width: 100,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        height: 90,
                                        width: 90,
                                        child: CircularProgressIndicator(
                                          value: rate,
                                          strokeWidth: 10,
                                          backgroundColor: AppColors.border,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Text(
                                        '$ratePercent%',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Paid',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(
                                              color: AppColors.border,
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Unpaid',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Ticket Status Overview Bar Chart Card (Vibrant Status Colors)
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ticket Status Overview',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildTicketBarChart(stats.ticketStatusCounts),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Quick Actions Section (Tinted Theme Icons)
                      const Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionButton(
                              icon: Icons.apartment,
                              iconColor: AppColors.primary,
                              badgeBg: AppColors.infoBg,
                              title: 'Manage\nApartments',
                              onTap: () => context.push(AppRoutes.apartmentList),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _QuickActionButton(
                              icon: Icons.manage_accounts_outlined,
                              iconColor: AppColors.purple,
                              badgeBg: AppColors.purpleBg,
                              title: 'Manage\nStaff',
                              onTap: () => context.push(AppRoutes.staffList),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionButton(
                              icon: Icons.receipt_long_outlined,
                              iconColor: AppColors.success,
                              badgeBg: AppColors.successBg,
                              title: 'Generate Bills',
                              onTap: () => context.push(AppRoutes.managerInvoiceList),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 5. Recent Activity Card (Dynamic Data from DB with Tinted Badges)
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Recent Activity',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                InkWell(
                                  onTap: () => context.push(AppRoutes.tickets),
                                  child: const Text(
                                    'VIEW ALL',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (stats.recentActivities.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'No recent activity recorded.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            else
                              ...stats.recentActivities.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final act = entry.value;
                                final isTicket = act.type == 'TICKET';
                                return Column(
                                  children: [
                                    if (idx > 0)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Divider(height: 1, color: AppColors.divider),
                                      ),
                                    _buildActivityItem(
                                      icon: isTicket
                                          ? Icons.assignment_ind_outlined
                                          : Icons.payments_outlined,
                                      iconColor: isTicket ? AppColors.purple : AppColors.success,
                                      badgeBg: isTicket ? AppColors.purpleBg : AppColors.successBg,
                                      title: act.title,
                                      subtitle: act.subtitle,
                                    ),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketBarChart(TicketStatusCounts counts) {
    final pendingVal = counts.pending;
    final processingVal = counts.processing;
    final waitingVal = counts.waitingRating;
    final closedVal = counts.closed;

    final maxVal = [pendingVal, processingVal, waitingVal, closedVal]
        .reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1 : maxVal;

    return Container(
      height: 135,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar(pendingVal / safeMax, pendingVal, AppColors.warning),
                _buildBar(processingVal / safeMax, processingVal, AppColors.primary),
                _buildBar(waitingVal / safeMax, waitingVal, AppColors.purple),
                _buildBar(closedVal / safeMax, closedVal, AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Text('PENDING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.warning)),
              Text('PROCESSING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('WAITING RATING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.purple)),
              Text('CLOSED', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double factor, int count, Color color) {
    final height = (factor * 70).clamp(8.0, 70.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 38,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color iconColor,
    required Color badgeBg,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashMetricCard extends StatelessWidget {
  const _DashMetricCard({
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          if (unit != null) ...[
            const SizedBox(height: 2),
            Text(
              unit!,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.iconColor,
    required this.badgeBg,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color badgeBg;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}



