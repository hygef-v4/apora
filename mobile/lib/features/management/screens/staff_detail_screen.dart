import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/router/app_router.dart';
import '../models/staff_member.dart';
import '../providers/staff_notifier.dart';

/// UC37 (FID-36): Chi tiết nhân viên - read-only (BR-03 UC37).
/// UC40 (FID-39): nút Vô hiệu hóa + confirm dialog; disabled khi còn task mở (BR-50).
class StaffDetailScreen extends ConsumerStatefulWidget {
  const StaffDetailScreen({super.key, required this.staffId});

  final int staffId;

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(staffDetailProvider.notifier).fetch(widget.staffId),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// UC40: confirm dialog + lý do (optional, <=250 ký tự) -> gọi API.
  Future<void> _confirmDeactivate() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vô hiệu hóa tài khoản'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppStrings.msgStaffDeactivateConfirm),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLength: 250,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Lý do (không bắt buộc)',
                hintText: 'VD: Nghỉ việc, chấm dứt hợp đồng...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận vô hiệu hóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final reason = reasonController.text.trim();
      await ref.read(staffDirectoryProvider.notifier).deactivateStaff(
            widget.staffId,
            reason: reason.isEmpty ? null : reason,
          );
      _showMessage('Đã vô hiệu hóa tài khoản nhân viên.');
      await ref.read(staffDetailProvider.notifier).fetch(widget.staffId);
    } catch (e) {
      // 409 khi vi phạm BR-50 - message từ backend
      _showMessage(mapDioError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(staffDetailProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết nhân viên')),
      body: detail.when(
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
                  onPressed: () => ref
                      .read(staffDetailProvider.notifier)
                      .fetch(widget.staffId),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final member = data.member;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile summary (read-only)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundImage: member.avatarUrl != null
                            ? NetworkImage(member.avatarUrl!)
                            : null,
                        child: member.avatarUrl == null
                            ? const Icon(Icons.person, size: 32)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member.fullName,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            Text(member.phoneNumber),
                            const SizedBox(height: 4),
                            Text(
                              '${staffRoleLabel(member.role)} · '
                              '${member.isActive ? "Đang làm việc" : "Đã nghỉ"}',
                              style: TextStyle(
                                color:
                                    member.isActive ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (data.createdAt != null)
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Ngày vào hệ thống'),
                  subtitle: Text(
                    '${data.createdAt!.day.toString().padLeft(2, '0')}/'
                    '${data.createdAt!.month.toString().padLeft(2, '0')}/'
                    '${data.createdAt!.year}',
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text('Công việc đang mở'),
                subtitle: Text('${member.openTaskCount} công việc'),
              ),

              // UC37: list task đang mở (hiện khi > 0)
              if (data.openTasks.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Công việc được giao',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...data.openTasks.map(
                  (task) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.build),
                      title: Text(task.title),
                      subtitle: Text([
                        if (task.category != null) task.category!,
                        task.status == 'ASSIGNED' ? 'Đã giao' : 'Đang xử lý',
                      ].join(' · ')),
                    ),
                  ),
                ),
                // Cảnh báo BR-50
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(child: Text(AppStrings.msgStaffHasOpenTasks)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Chỉnh sửa hồ sơ'),
                onPressed: member.isActive
                    ? () => context.push(AppRoutes.staffEditPath(member.id))
                    : null,
              ),
              const SizedBox(height: 8),
              // UC40: disabled khi !canDeactivate (còn task mở hoặc đã INACTIVE)
              OutlinedButton.icon(
                icon: const Icon(Icons.block),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                label: Text(member.isActive
                    ? 'Vô hiệu hóa tài khoản'
                    : 'Tài khoản đã vô hiệu hóa'),
                onPressed: data.canDeactivate ? _confirmDeactivate : null,
              ),
            ],
          );
        },
      ),
    );
  }
}
