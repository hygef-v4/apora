import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth_profile/providers/profile_notifier.dart';
import '../providers/roommate_provider.dart';

class RoommateListScreen extends ConsumerStatefulWidget {
  const RoommateListScreen({super.key});

  @override
  ConsumerState<RoommateListScreen> createState() => _RoommateListScreenState();
}

class _RoommateListScreenState extends ConsumerState<RoommateListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(roommateProvider.notifier).fetchRoommates());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roommateProvider);
    final profile = ref.watch(profileNotifierProvider).value;

    final totalOccupants = state.roommates.where((r) => r.status == 'APPROVED').length + 1; // BR-24: Primary Owner counted

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          GradientHeader(
            title: 'Thành Viên Phòng',
            subtitle: 'Quản lý thông tin tạm trú',
            showBack: true,
            actions: [
              HeaderIconButton(
                icon: Icons.refresh,
                tooltip: 'Làm mới',
                onTap: () => ref.read(roommateProvider.notifier).fetchRoommates(),
              ),
            ],
          ),
          Expanded(
            child: state.isLoading && state.roommates.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Thẻ tóm tắt tổng số thành viên
                      AppCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.group, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tổng số người đăng ký lưu trú',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$totalOccupants người',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Danh sách thành viên (Chủ hộ trước)
                      const Text(
                        'Danh sách thành viên',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 10),

                      // Card của chủ hộ
                      if (profile != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    profile.fullName[0].toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        profile.phoneNumber,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge.success('Chủ hộ'),
                              ],
                            ),
                          ),
                        ),

                      // Roommates khác
                      if (state.roommates.isEmpty) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.people_outline, size: 48, color: AppColors.textTertiary),
                              const SizedBox(height: 8),
                              const Text(
                                'Hiện tại chưa có thành viên nào khác trong phòng.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ] else
                        ...state.roommates.map((roommate) {
                          Widget statusBadge;
                          if (roommate.status == 'APPROVED') {
                            statusBadge = StatusBadge.success('Đã duyệt');
                          } else if (roommate.status == 'PENDING') {
                            statusBadge = StatusBadge.warning('Chờ duyệt');
                          } else {
                            statusBadge = const StatusBadge(
                              text: 'Từ chối',
                              color: AppColors.error,
                              backgroundColor: AppColors.errorBg,
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: roommate.status == 'APPROVED'
                                            ? Colors.green.withValues(alpha: 0.1)
                                            : roommate.status == 'PENDING'
                                                ? Colors.orange.withValues(alpha: 0.1)
                                                : Colors.red.withValues(alpha: 0.1),
                                        child: Text(
                                          roommate.fullName[0].toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: roommate.status == 'APPROVED'
                                                ? Colors.green
                                                : roommate.status == 'PENDING'
                                                    ? Colors.orange
                                                    : Colors.red,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              roommate.fullName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              roommate.phoneNumber ?? 'Không có SĐT',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ),
                                      statusBadge,
                                    ],
                                  ),

                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.roommateRegister),
        backgroundColor: AppColors.navy,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('ĐĂNG KÝ THÀNH VIÊN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
