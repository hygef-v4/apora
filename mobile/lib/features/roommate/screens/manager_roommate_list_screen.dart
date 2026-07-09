import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../providers/roommate_provider.dart';

class RoommateApprovalListScreen extends ConsumerStatefulWidget {
  const RoommateApprovalListScreen({super.key});

  @override
  ConsumerState<RoommateApprovalListScreen> createState() => _RoommateApprovalListScreenState();
}

class _RoommateApprovalListScreenState extends ConsumerState<RoommateApprovalListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(roommateProvider.notifier).fetchPendingRequests());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roommateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          GradientHeader(
            title: 'Duyệt Thành Viên',
            subtitle: 'Phê duyệt yêu cầu tạm trú mới',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: 'Làm mới',
                onTap: () => ref.read(roommateProvider.notifier).fetchPendingRequests(),
              ),
            ],
          ),
          Expanded(
            child: state.isLoading && state.pendingRequests.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : state.pendingRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.mark_email_read, size: 48, color: AppColors.textTertiary),
                            const SizedBox(height: 8),
                            const Text(
                              'Không có yêu cầu tạm trú nào đang chờ duyệt.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.pendingRequests.length,
                        itemBuilder: (context, index) {
                          final roommate = state.pendingRequests[index];
                          final formattedDate = '${roommate.createdAt.day}/${roommate.createdAt.month}/${roommate.createdAt.year}';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              onTap: () async {
                                // Đi tới màn hình duyệt chi tiết
                                await context.push('/manager/roommates/${roommate.id}');
                                ref.read(roommateProvider.notifier).fetchPendingRequests();
                              },
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.assignment_ind, color: AppColors.warning, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          roommate.fullName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Căn hộ: Căn ${roommate.unitNumber ?? "N/A"}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Ngày gửi: $formattedDate',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
