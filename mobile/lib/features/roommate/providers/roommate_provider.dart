import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../models/roommate.dart';

class RoommateState {
  final List<Roommate> roommates;
  final List<Roommate> pendingRequests;
  final bool isLoading;
  final String? errorMessage;

  RoommateState({
    required this.roommates,
    required this.pendingRequests,
    this.isLoading = false,
    this.errorMessage,
  });

  RoommateState copyWith({
    List<Roommate>? roommates,
    List<Roommate>? pendingRequests,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RoommateState(
      roommates: roommates ?? this.roommates,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class RoommateNotifier extends Notifier<RoommateState> {
  @override
  RoommateState build() {
    return RoommateState(
      roommates: const [],
      pendingRequests: const [],
    );
  }

  /// Lấy danh sách thành viên cùng căn hộ (dành cho Cư dân)
  Future<void> fetchRoommates() async {
    state = state.copyWith(isLoading: true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/roommates');
      final raw = res.data['data'] as List;
      final list = raw.map((json) => Roommate.fromJson(json as Map<String, dynamic>)).toList();
      state = state.copyWith(roommates: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Lấy danh sách yêu cầu tạm trú chờ duyệt (dành cho Quản lý)
  Future<void> fetchPendingRequests() async {
    state = state.copyWith(isLoading: true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/roommates/pending');
      final raw = res.data['data'] as List;
      final list = raw.map((json) => Roommate.fromJson(json as Map<String, dynamic>)).toList();
      state = state.copyWith(pendingRequests: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Đăng ký thành viên phòng mới
  /// [cccdFrontBytes] và [cccdBackBytes] đã được nén < 500KB tại nơi gọi (BR-10)
  Future<void> registerRoommate({
    required String fullName,
    String? phoneNumber,
    required String cccdNumber,
    Uint8List? cccdFrontBytes,
    Uint8List? cccdBackBytes,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final dio = ref.read(dioProvider);
      final form = FormData.fromMap({
        'fullName': fullName,
        if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
          'phoneNumber': phoneNumber,
        'cccdNumber': cccdNumber,
        if (cccdFrontBytes != null)
          'cccdFront': MultipartFile.fromBytes(cccdFrontBytes, filename: 'cccd_front.jpg'),
        if (cccdBackBytes != null)
          'cccdBack': MultipartFile.fromBytes(cccdBackBytes, filename: 'cccd_back.jpg'),
      });

      await dio.post('/roommates', data: form);
      await fetchRoommates();
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Cập nhật trạng thái duyệt thành viên (APPROVED / REJECTED)
  Future<void> updateRequestStatus({
    required int roommateId,
    required String status,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/roommates/$roommateId/status', data: {
        'status': status,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
      });
      await fetchPendingRequests();
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}

final roommateProvider = NotifierProvider<RoommateNotifier, RoommateState>(
  () => RoommateNotifier(),
);
