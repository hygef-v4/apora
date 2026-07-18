import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth_profile/providers/auth_notifier.dart';
import '../models/chat_message_model.dart';
import '../models/chat_session_model.dart';
import '../repositories/chat_repository.dart';
import '../services/pusher_service.dart';

// Provides the list of active chat sessions for Managers
final chatSessionsProvider = AsyncNotifierProvider.autoDispose<ChatSessionsNotifier, List<ChatSessionModel>>(
  ChatSessionsNotifier.new,
);

class ChatSessionsNotifier extends AsyncNotifier<List<ChatSessionModel>> {
  @override
  Future<List<ChatSessionModel>> build() async {
    final repo = ref.watch(chatRepositoryProvider);
    return repo.getChatSessions();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(chatRepositoryProvider).getChatSessions());
  }

  void markSessionAsRead(int? partnerId) {
    if (partnerId == null || !state.hasValue) return;
    
    final currentState = state.value!;
    final updatedList = currentState.map((session) {
      if (session.residentId == partnerId) {
        return session.copyWith(unreadCount: 0);
      }
      return session;
    }).toList();
    
    state = AsyncData(updatedList);
  }
}

// Provides the messages for the currently open chat
final chatMessagesProvider = AsyncNotifierProvider.autoDispose<ChatMessagesNotifier, List<ChatMessageModel>>(
  ChatMessagesNotifier.new,
);

class ChatMessagesNotifier extends AsyncNotifier<List<ChatMessageModel>> {
  int? _partnerId;
  bool _pusherInitialized = false;

  @override
  Future<List<ChatMessageModel>> build() async {
    return [];
  }

  Future<void> loadChat(int? partnerId) async {
    _partnerId = partnerId;
    state = const AsyncLoading();
    
    final repo = ref.read(chatRepositoryProvider);
    final user = ref.read(authNotifierProvider).user;

    // Initialize pusher
    if (user != null && !_pusherInitialized) {
      PusherService().init(
        currentUserId: user.id,
        onMessageReceived: (message) {
          final isForManagerChattingWithResident = _partnerId != null && 
              (message.senderId == _partnerId || message.receiverId == _partnerId);
              
          final isForResidentChattingWithManagement = _partnerId == null;
              
          if (isForManagerChattingWithResident || isForResidentChattingWithManagement) {
            final currentState = state.value ?? [];
            state = AsyncData([message, ...currentState]);
          }
        },
      );

      if (user.roles.contains('MANAGER') || user.roles.contains('LANDLORD')) {
        PusherService().subscribeToManagementChannel();
      }
      _pusherInitialized = true;
    }

    try {
      final messages = await repo.getMessages(partnerId);
      state = AsyncData(messages);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> sendMessage({String? content, File? image}) async {
    final repo = ref.read(chatRepositoryProvider);
    final user = ref.read(authNotifierProvider).user;
    if (user == null) return;

    // Optimistic UI
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMsg = ChatMessageModel(
      id: tempId,
      senderId: user.id,
      receiverId: _partnerId,
      content: (content != null && content.isNotEmpty) ? content : (image?.path ?? ''),
      isImage: image != null,
      createdAt: DateTime.now(),
      senderName: user.fullName,
      senderRole: user.roles.first,
    );

    final previousState = state.value ?? [];
    state = AsyncData([tempMsg, ...previousState]);

    try {
      final realMsg = await repo.sendMessage(
        receiverId: _partnerId,
        content: content,
        image: image,
      );
      
      // Replace tempMsg with realMsg
      final currentState = state.value ?? [];
      final updatedList = currentState.map((m) => m.id == tempId ? realMsg : m).toList();
      state = AsyncData(updatedList);
    } catch (e) {
      // Revert if failed
      state = AsyncData(previousState);
      throw Exception('Gửi tin nhắn thất bại: $e');
    }
  }

  Future<void> markAsRead() async {
    try {
      await ref.read(chatRepositoryProvider).markAsRead(_partnerId);
      // Update local state to mark all as read
      final currentState = state.value;
      if (currentState != null) {
        final updatedList = currentState.map((m) => m.copyWith(isRead: true)).toList();
        state = AsyncData(updatedList);
      }
      
      // Update the chat session list unread count
      ref.read(chatSessionsProvider.notifier).markSessionAsRead(_partnerId);
    } catch (e) {
      // ignore
    }
  }
}
