import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/task.dart';
import '../models/ticket.dart';

class TicketState {
  final List<Ticket> tickets;
  final bool isLoading;
  final String? errorMessage;
  /// null = tất cả; ngược lại lọc theo 1 trạng thái (UC18).
  final String? statusFilter;

  TicketState({
    required this.tickets,
    this.isLoading = false,
    this.errorMessage,
    this.statusFilter,
  });

  TicketState copyWith({
    List<Ticket>? tickets,
    bool? isLoading,
    String? errorMessage,
    Object? statusFilter = _unset,
  }) {
    return TicketState(
      tickets: tickets ?? this.tickets,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      statusFilter:
          statusFilter == _unset ? this.statusFilter : statusFilter as String?,
    );
  }
}

/// Sentinel để phân biệt "không truyền" với "truyền null" khi copyWith statusFilter.
const Object _unset = Object();

/// Danh sách sự cố (UC18). Backend tự phân luồng theo vai trò:
/// RESIDENT thấy của mình, MANAGER/LANDLORD thấy tất cả.
class TicketNotifier extends Notifier<TicketState> {
  @override
  TicketState build() => TicketState(tickets: const []);

  Future<void> fetchTickets({String? status}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, statusFilter: status);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        ApiConstants.tickets,
        queryParameters: status != null ? {'status': status} : null,
      );
      final raw = res.data['data'] as List;
      final list = raw
          .map((json) => Ticket.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(tickets: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: mapDioError(e));
    }
  }

  /// UC19: tạo sự cố mới. [imageBytes] đã được nén < 500KB tại nơi gọi (BR-10),
  /// tối đa 3 ảnh (BR-37). Ném lỗi (đã map tiếng Việt) để màn hình hiển thị.
  Future<void> createTicket({
    required String category,
    required String description,
    List<Uint8List> imageBytes = const [],
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final form = FormData.fromMap({
        'category': category,
        'description': description,
        'images': [
          for (var i = 0; i < imageBytes.length; i++)
            MultipartFile.fromBytes(imageBytes[i], filename: 'ticket_$i.jpg'),
        ],
      });
      await dio.post(ApiConstants.tickets, data: form);
      await fetchTickets(); // làm mới danh sách (bỏ lọc, thấy ngay cái vừa tạo)
    } catch (e) {
      throw mapDioError(e);
    }
  }
}

final ticketProvider =
    NotifierProvider<TicketNotifier, TicketState>(() => TicketNotifier());

/// Chi tiết 1 sự cố (UC20) - fetch tường minh theo id
/// (cùng pattern với StaffDetailNotifier của Module 8).
class TicketDetailNotifier extends AsyncNotifier<TicketDetail?> {
  @override
  Future<TicketDetail?> build() async => null;

  Future<void> fetch(int ticketId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.ticketDetail(ticketId));
      return TicketDetail.fromJson(res.data['data'] as Map<String, dynamic>);
    });
  }

  /// UC20: Manager/Landlord đổi trạng thái + ghi chú nội bộ (BR-40).
  /// Thành công thì cập nhật luôn state từ response; lỗi ném ra
  /// (đã map tiếng Việt) để màn hình hiển thị SnackBar (AT2).
  Future<void> updateStatus(
    int ticketId, {
    required String status,
    String? internalNotes,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final notes = internalNotes?.trim();
      final res = await dio.put(
        ApiConstants.ticketStatus(ticketId),
        data: {
          'status': status,
          if (notes != null && notes.isNotEmpty) 'internalNotes': notes,
        },
      );
      state = AsyncData(
        TicketDetail.fromJson(res.data['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      throw mapDioError(e);
    }
  }
}

final ticketDetailProvider =
    AsyncNotifierProvider<TicketDetailNotifier, TicketDetail?>(
  TicketDetailNotifier.new,
);

/// UC21 (BR-41): bảng tải việc nhân viên cho màn phân công.
/// Fetch tường minh mỗi lần mở màn để số liệu luôn realtime.
class StaffWorkloadNotifier extends AsyncNotifier<List<StaffWorkload>> {
  @override
  Future<List<StaffWorkload>> build() async => const [];

  Future<void> fetch() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.staffWorkload);
      final raw = res.data['data'] as List;
      return raw
          .map((json) => StaffWorkload.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }

  /// UC21: phân công sự cố. Thành công trả TicketDetail mới (đã ASSIGNED
  /// kèm task); lỗi ném message tiếng Việt (AT3/AT4) cho màn hình.
  Future<TicketDetail> assignTicket(
    int ticketId, {
    required int assignedTo,
    required String title,
    String? description,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final desc = description?.trim();
      final res = await dio.post(
        ApiConstants.ticketAssign(ticketId),
        data: {
          'assignedTo': assignedTo,
          'title': title.trim(),
          if (desc != null && desc.isNotEmpty) 'description': desc,
        },
      );
      return TicketDetail.fromJson(res.data['data'] as Map<String, dynamic>);
    } catch (e) {
      throw mapDioError(e);
    }
  }
}

final staffWorkloadProvider =
    AsyncNotifierProvider<StaffWorkloadNotifier, List<StaffWorkload>>(
  StaffWorkloadNotifier.new,
);
