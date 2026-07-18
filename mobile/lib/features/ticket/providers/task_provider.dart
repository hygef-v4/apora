import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/task.dart';

class TaskListState {
  final List<TaskItem> tasks;
  final bool isLoading;
  final String? errorMessage;

  /// null = tất cả; 'ACTIVE' = đang làm (ASSIGNED + IN_PROGRESS);
  /// hoặc 1 trạng thái cụ thể (UC22 filter tabs).
  final String? statusFilter;

  TaskListState({
    required this.tasks,
    this.isLoading = false,
    this.errorMessage,
    this.statusFilter,
  });

  TaskListState copyWith({
    List<TaskItem>? tasks,
    bool? isLoading,
    String? errorMessage,
    Object? statusFilter = _unset,
  }) {
    return TaskListState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      statusFilter:
          statusFilter == _unset ? this.statusFilter : statusFilter as String?,
    );
  }
}

const Object _unset = Object();

/// UC22: danh sách công việc. Backend tự phân luồng theo vai trò (BR-42):
/// staff thấy việc của mình, MANAGER/LANDLORD thấy tất cả.
class TaskNotifier extends Notifier<TaskListState> {
  @override
  TaskListState build() => TaskListState(tasks: const []);

  Future<void> fetchTasks({String? status}) async {
    state =
        state.copyWith(isLoading: true, errorMessage: null, statusFilter: status);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        ApiConstants.tasks,
        queryParameters: status != null ? {'status': status} : null,
      );
      final raw = res.data['data'] as List;
      final list = raw
          .map((json) => TaskItem.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(tasks: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: mapDioError(e));
    }
  }
}

final taskProvider =
    NotifierProvider<TaskNotifier, TaskListState>(() => TaskNotifier());

/// UC23: chi tiết công việc - fetch tường minh theo id.
class TaskDetailNotifier extends AsyncNotifier<TaskDetail?> {
  @override
  Future<TaskDetail?> build() async => null;

  Future<void> fetch(int taskId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.taskDetail(taskId));
      return TaskDetail.fromJson(res.data['data'] as Map<String, dynamic>);
    });
  }

  /// UC23: cập nhật tiến độ (IN_PROGRESS / COMPLETED).
  /// [imageBytes] ảnh nghiệm thu đã nén < 500KB (BR-10) - bắt buộc ≥1 khi
  /// COMPLETED (BR-43, màn hình validate trước, backend chặn lần cuối).
  /// Thành công cập nhật state từ response; lỗi ném message tiếng Việt (AT4).
  Future<void> updateProgress(
    int taskId, {
    required String status,
    String? progressNotes,
    List<Uint8List> imageBytes = const [],
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final notes = progressNotes?.trim();
      final form = FormData.fromMap({
        'status': status,
        if (notes != null && notes.isNotEmpty) 'progressNotes': notes,
        'images': [
          for (var i = 0; i < imageBytes.length; i++)
            MultipartFile.fromBytes(imageBytes[i], filename: 'done_$i.jpg'),
        ],
      });
      final res = await dio.put(ApiConstants.taskProgress(taskId), data: form);
      state = AsyncData(
        TaskDetail.fromJson(res.data['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      throw mapDioError(e);
    }
  }
}

final taskDetailProvider =
    AsyncNotifierProvider<TaskDetailNotifier, TaskDetail?>(
  TaskDetailNotifier.new,
);
