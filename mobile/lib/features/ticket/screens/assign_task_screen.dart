import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/task.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';

/// UC21 - Màn phân công sự cố (theo màn FID-21). Chỉ MANAGER/LANDLORD.
/// Nhận TicketDetail (đang PENDING) từ màn chi tiết, chọn nhân viên theo
/// bảng tải việc realtime (BR-41), tạo task trong 1 transaction ở backend.
class AssignTaskScreen extends ConsumerStatefulWidget {
  const AssignTaskScreen({super.key, required this.ticket});

  final TicketDetail ticket;

  @override
  ConsumerState<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends ConsumerState<AssignTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  final _descController = TextEditingController();
  int? _selectedStaffId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Gợi ý sẵn tiêu đề từ ticket (FID-21 field 3: pre-filled suggestion)
    _titleController = TextEditingController(
      text: 'Xử lý sự cố ${widget.ticket.category.toLowerCase()} '
          'phòng ${widget.ticket.unitNumber}',
    );
    Future.microtask(() => ref.read(staffWorkloadProvider.notifier).fetch());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    // AT1: title bắt buộc (validator); AT2: phải chọn nhân viên
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStaffId == null) {
      _showSnack('Vui lòng chọn nhân viên để phân công.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(staffWorkloadProvider.notifier).assignTicket(
            widget.ticket.id,
            assignedTo: _selectedStaffId!,
            title: _titleController.text,
            description: _descController.text,
          );
      _showSnack('Phân công sự cố thành công.');
      if (mounted) context.pop(true); // true = đã phân công, màn trước refresh
    } catch (e) {
      // AT3 (ticket không còn PENDING) / AT4 (lỗi mạng): giữ nguyên dữ liệu
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workload = ref.watch(staffWorkloadProvider);
    final ticket = widget.ticket;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          const GradientHeader(
            title: 'Phân Công Công Việc',
            subtitle: 'Giao sự cố cho nhân viên vận hành',
            showBack: true,
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // 1. Thẻ tóm tắt ticket (read-only - FID-21 field 1)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#TK-${ticket.id} · ${ticket.category}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            StatusBadge.warning(
                              kTicketStatusLabels[ticket.status] ?? ticket.status,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ticket.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Phòng ${ticket.unitNumber} · ${ticket.residentName}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Tiêu đề + mô tả công việc
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. Tiêu đề công việc *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _titleController,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: 'VD: Sửa ổ điện phòng 101...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if ((val ?? '').trim().isEmpty) {
                              return 'Vui lòng nhập tiêu đề công việc.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text('2. Hướng dẫn chi tiết (tùy chọn)',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary)),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _descController,
                          maxLines: 3,
                          maxLength: 500,
                          decoration: InputDecoration(
                            hintText:
                                'Ghi chú cho nhân viên: dụng cụ cần mang, lưu ý an toàn...',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Chọn nhân viên theo tải việc (BR-41)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('3. Chọn nhân viên *',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary)),
                        const SizedBox(height: 10),
                        workload.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.primary)),
                          ),
                          error: (e, _) => Column(
                            children: [
                              Text(e.toString(),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: () => ref
                                    .read(staffWorkloadProvider.notifier)
                                    .fetch(),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                          data: (staffList) {
                            if (staffList.isEmpty) {
                              return const Text(
                                'Chưa có nhân viên vận hành nào đang hoạt động.',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary),
                              );
                            }
                            return Column(
                              children: [
                                for (final s in staffList)
                                  _StaffTile(
                                    staff: s,
                                    selected: _selectedStaffId == s.id,
                                    onTap: _isSubmitting
                                        ? null
                                        : () => setState(
                                            () => _selectedStaffId = s.id),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('PHÂN CÔNG',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1 dòng nhân viên: avatar chữ cái + tên + role + badge tải việc (FID-21).
class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.staff,
    required this.selected,
    required this.onTap,
  });

  final StaffWorkload staff;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final roleLabel = staff.roles
        .map((r) => kStaffRoleLabels[r] ?? r)
        .join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
          color: selected ? AppColors.infoBg : Colors.white,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.primary : AppColors.inactive,
            ),
            const SizedBox(width: 10),
            InitialsAvatar(name: staff.fullName, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.fullName,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary),
                  ),
                  Text(
                    roleLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            staff.isAvailable
                ? StatusBadge.success('RẢNH')
                : StatusBadge.warning('BẬN (${staff.openTaskCount} VIỆC)'),
          ],
        ),
      ),
    );
  }
}
