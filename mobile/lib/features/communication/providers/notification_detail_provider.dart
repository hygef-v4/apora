import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../repositories/communication_repository.dart';

enum NotificationDetailStatus {
  initial,
  loading,
  success,
  notFound,
  networkError,
}

class NotificationDetailNotifier extends Notifier<NotificationDetailStatus> {
  @override
  NotificationDetailStatus build() {
    return NotificationDetailStatus.initial;
  }

  Future<void> markAsRead(int notificationId) async {
    state = NotificationDetailStatus.loading;
    try {
      await ref.read(communicationRepositoryProvider).markAsRead(notificationId);
      state = NotificationDetailStatus.success;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        state = NotificationDetailStatus.notFound;
      } else {
        state = NotificationDetailStatus.networkError;
      }
    } catch (e) {
      state = NotificationDetailStatus.networkError;
    }
  }
}

final notificationDetailProvider = NotifierProvider<NotificationDetailNotifier, NotificationDetailStatus>(
  () => NotificationDetailNotifier(),
);
