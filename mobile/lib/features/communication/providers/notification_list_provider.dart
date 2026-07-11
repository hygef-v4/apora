import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../repositories/communication_repository.dart';

class NotificationListNotifier extends AsyncNotifier<List<NotificationModel>> {
  int _offset = 0;
  final int _limit = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<NotificationModel>> build() async {
    _offset = 0;
    _hasMore = true;
    _isLoadingMore = false;
    final repo = ref.read(communicationRepositoryProvider);
    final data = await repo.getNotifications(limit: _limit, offset: _offset);
    if (data.length < _limit) {
      _hasMore = false;
    }
    data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return data;
  }

  Future<void> fetchMore() async {
    if (!_hasMore || _isLoadingMore || state.isLoading || state.hasError) return;

    _isLoadingMore = true;
    // Cập nhật lại UI để hiển thị spinner ở cuối trang (phải clone list để Riverpod nhận diện thay đổi)
    state = AsyncData(List.from(state.value ?? []));

    try {
      _offset += _limit;
      final repo = ref.read(communicationRepositoryProvider);
      final newData = await repo.getNotifications(limit: _limit, offset: _offset);
      
      if (newData.length < _limit) {
        _hasMore = false;
      }
      
      final currentList = state.value ?? [];
      final combinedList = [...currentList, ...newData];
      combinedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = AsyncData(combinedList);
    } catch (e, st) {
      _offset -= _limit; // Revert offset
      state = AsyncError(e, st);
    } finally {
      _isLoadingMore = false;
    }
  }
}

final notificationListProvider =
    AsyncNotifierProvider<NotificationListNotifier, List<NotificationModel>>(
  () => NotificationListNotifier(),
);
