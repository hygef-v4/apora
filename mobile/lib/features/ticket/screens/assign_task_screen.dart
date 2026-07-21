import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/spec_layout.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/task.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../widgets/ticket_category.dart';

/// UC21 - Assign Task (bố cục theo wireframe FID-21 trong SRS). Chỉ MANAGER/
/// LANDLORD. Nhận TicketDetail (đang PENDING) từ màn chi tiết, chọn nhân viên
/// theo bảng tải việc realtime (BR-41), tạo task trong 1 transaction ở backend.
class AssignTaskScreen extends ConsumerStatefulWidget {
  const AssignTaskScreen({super.key, required this.ticket});

  final TicketDetail ticket;

  @override
  ConsumerState<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

/// Nhãn tiếng Anh cho vai trò nhân viên (hiển thị theo wireframe).
const Map<String, String> _staffRoleLabelsEn = {
  'SECURITY_GUARD': 'Security Guard',
  'JANITOR': 'Janitor',
  'TECHNICIAN': 'Technician',
};

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
      text: 'Fix ${ticketCategoryLabel(widget.ticket.category).toLowerCase()} '
          'issue in Room ${widget.ticket.unitNumber}',
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
      _showSnack('Please select a staff member to assign.');
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
      _showSnack('Task assigned successfully.');
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
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          const GradientHeader(title: 'Assign Task', showBack: true),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  // TICKET SUMMARY - khối viền chỉ đọc (FID-21 field 1)
                  const SpecSectionHeader('Ticket Summary'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summaryField(
                          'TICKET',
                          '#TK-${ticket.id.toString().padLeft(3, '0')} — '
                              '${ticket.description}',
                        ),
                        const SizedBox(height: 10),
                        _summaryField(
                          'CATEGORY',
                          ticketCategoryLabel(ticket.category),
                        ),
                        const SizedBox(height: 10),
                        _summaryField('APARTMENT', 'Room ${ticket.unitNumber}'),
                        const SizedBox(height: 10),
                        StatusBadge.warning('PENDING'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // TASK DETAILS
                  const SpecSectionHeader('Task Details'),
                  const SizedBox(height: 8),
                  const SpecFieldLabel('Task Title', required: true),
                  TextFormField(
                    controller: _titleController,
                    maxLength: 100,
                    enabled: !_isSubmitting,
                    style: const TextStyle(fontSize: 13),
                    decoration: _inputDecoration(
                      'e.g. Fix hallway light on 4th floor',
                    ),
                    validator: (val) {
                      if ((val ?? '').trim().isEmpty) {
                        return 'Please enter a task title.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  const SpecFieldLabel('Task Description'),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    maxLength: 500,
                    enabled: !_isSubmitting,
                    style: const TextStyle(fontSize: 13),
                    decoration: _inputDecoration(
                      'Provide detailed instructions for the assigned staff...',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // SELECT STAFF MEMBER (BR-41)
                  const SpecSectionHeader('Select Staff Member'),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose a security guard or technician to assign this task',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  workload.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    ),
                    error: (e, _) => Column(
                      children: [
                        Text(
                          e.toString(),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () =>
                              ref.read(staffWorkloadProvider.notifier).fetch(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                    data: (staffList) {
                      if (staffList.isEmpty) {
                        return const Text(
                          'No active operations staff available.',
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
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'ASSIGN TASK',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: .5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  Widget _summaryField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
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
    final roleLabel =
        staff.roles.map((r) => _staffRoleLabelsEn[r] ?? r).join(' · ');
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
          color: selected ? AppColors.infoBg : AppColors.surface,
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
                ? StatusBadge.success('AVAILABLE')
                : StatusBadge.warning('BUSY (${staff.openTaskCount} TASKS)'),
          ],
        ),
      ),
    );
  }
}
