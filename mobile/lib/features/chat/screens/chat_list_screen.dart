import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../providers/chat_provider.dart';
import '../../../core/network/dio_client.dart';

class ManagerChatListScreen extends ConsumerStatefulWidget {
  const ManagerChatListScreen({super.key});

  @override
  ConsumerState<ManagerChatListScreen> createState() => _ManagerChatListScreenState();
}

class _ManagerChatListScreenState extends ConsumerState<ManagerChatListScreen> {
  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(chatSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hỗ trợ Resident'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có yêu cầu hỗ trợ nào.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(chatSessionsProvider.notifier).refresh();
            },
            child: ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isUnread = session.unreadCount > 0;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      session.residentName.isNotEmpty ? session.residentName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          session.residentName,
                          style: TextStyle(
                            fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(session.updatedAt),
                        style: TextStyle(
                          color: isUnread ? AppColors.primary : Colors.grey[500],
                          fontSize: 12,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.isLastMessageImage ? '[Hình ảnh]' : session.lastMessage,
                          style: TextStyle(
                            color: isUnread ? Colors.black87 : Colors.grey[600],
                            fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${session.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    // Navigate to individual chat screen
                    context.push('/chat/${session.residentId}', extra: session.residentName);
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(mapDioError(err), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    ref.read(chatSessionsProvider.notifier).refresh();
                  },
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
