import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../repositories/communication_repository.dart';

final notificationListProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final repo = ref.read(communicationRepositoryProvider);
  return repo.getNotifications();
});
