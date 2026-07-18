import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../management/providers/apartment_notifier.dart';
import '../../management/models/apartment.dart';
import '../providers/chat_provider.dart';
import '../../../core/network/dio_client.dart';

/// UC41 - Danh sách tin nhắn hỗ trợ của Quản lý.
/// Đã được thiết kế lại:
/// - Danh sách căn hộ dạng lưới danh mục căn hộ (nhãn phòng, màu block, thông tin tầng/diện tích/cư dân).
/// - Hiển thị badge đỏ báo số lượng tin nhắn chưa đọc đối với các phòng đang hoạt động.
/// - Bấm vào sẽ mở màn hình tin nhắn chat trực tiếp của cư dân ở căn hộ đó.
class ManagerChatListScreen extends ConsumerStatefulWidget {
  const ManagerChatListScreen({super.key});

  @override
  ConsumerState<ManagerChatListScreen> createState() => _ManagerChatListScreenState();
}

class _ManagerChatListScreenState extends ConsumerState<ManagerChatListScreen> {
  bool _searchOpen = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  List<Apartment> _applySearch(List<Apartment> list) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((apt) {
      return apt.unitNumber.toLowerCase().contains(q) ||
          (apt.ownerName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentDirectoryProvider);
    final sessionsAsync = ref.watch(chatSessionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          GradientHeader(
            title: 'Hỗ trợ',
            subtitle: 'Nhắn tin hỗ trợ theo căn hộ',
            showBack: false,
            actions: [
              HeaderIconButton(
                icon: _searchOpen ? Icons.search_off : Icons.search,
                tooltip: 'Tìm kiếm',
                onTap: () => setState(() {
                  _searchOpen = !_searchOpen;
                  if (!_searchOpen) _searchController.clear();
                }),
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
                  hintText: 'Tìm theo số phòng, tên cư dân...',
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
                        onPressed: () {
                          ref.read(apartmentDirectoryProvider.notifier).refresh();
                          ref.read(chatSessionsProvider.notifier).refresh();
                        },
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (apartments) {
                final occupiedOnly = apartments.where((apt) => apt.status != 'EMPTY').toList();
                final visibleApartments = _applySearch(occupiedOnly);

                if (visibleApartments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: 16),
                        Text(
                          'Không tìm thấy căn hộ nào.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // Lấy danh sách tin nhắn hoạt động
                final sessions = sessionsAsync.value ?? [];

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(apartmentDirectoryProvider.notifier).refresh();
                    await ref.read(chatSessionsProvider.notifier).refresh();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: visibleApartments.length,
                    itemBuilder: (context, index) {
                      final apt = visibleApartments[index];
                      
                      // Tìm tin nhắn tương ứng với số phòng này
                      final roomSessions = sessions.where((s) => s.unitNumber == apt.unitNumber).toList();
                      // Ưu tiên tin có tin chưa đọc hoặc mới nhất
                      roomSessions.sort((a, b) {
                        final unreadCompare = b.unreadCount.compareTo(a.unreadCount);
                        if (unreadCompare != 0) return unreadCompare;
                        return b.updatedAt.compareTo(a.updatedAt);
                      });
                      final activeSession = roomSessions.isNotEmpty ? roomSessions.first : null;

                      // Phân giải các giá trị hiển thị & điều hướng từ chat_room.resident_id
                      final int targetResidentId = activeSession != null ? activeSession.residentId : (apt.ownerId ?? 0);
                      final String targetResidentName = activeSession != null ? activeSession.residentName : (apt.ownerName ?? 'Chưa có chủ hộ');
                      final int unreadCount = activeSession != null ? activeSession.unreadCount : 0;

                      final prefix = _getPrefix(apt.unitNumber);
                      final prefixColor = _getPrefixColor(prefix);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          onTap: () {
                            if (targetResidentId == 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Căn hộ hiện đang trống, chưa có cư dân nhận phòng.'),
                                ),
                              );
                              return;
                            }
                            // Mở màn chat trực tiếp với cư dân được phân giải
                            context.push(
                              AppRoutes.chatDetailPath(targetResidentId),
                              extra: targetResidentName,
                            );
                          },
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
                                      'Căn hộ ${apt.unitNumber}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      targetResidentName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.all(Radius.circular(10)),
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  color: Color(0xFF94A3B8),
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
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
