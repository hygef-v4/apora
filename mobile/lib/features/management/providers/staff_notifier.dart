import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/staff_detail.dart';
import '../repositories/staff_api_service.dart';

/// Notifier danh mục nhân viên (UC36) + các thao tác CRUD (UC38-UC40).
/// Filter tab (All/Active/Inactive) và search gọi lại API server-side.
class StaffDirectoryNotifier extends AsyncNotifier<StaffListResult> {
  StaffAPIService get _api => ref.read(staffApiServiceProvider);

  /// null = All, 'ACTIVE', 'INACTIVE'
  String? statusFilter;
  String? searchKeyword;

  @override
  Future<StaffListResult> build() =>
      _api.getStaffList(status: statusFilter, search: searchKeyword);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _api.getStaffList(status: statusFilter, search: searchKeyword),
    );
  }

  Future<void> setStatusFilter(String? status) {
    statusFilter = status;
    return refresh();
  }

  Future<void> setSearch(String keyword) {
    searchKeyword = keyword.trim().isEmpty ? null : keyword.trim();
    return refresh();
  }

  /// UC38: tạo tài khoản rồi tải lại danh sách.
  Future<void> createStaff({
    required String fullName,
    required String phone,
    required String password,
    required String role,
  }) async {
    await _api.createStaff(
      fullName: fullName,
      phone: phone,
      password: password,
      role: role,
    );
    await refresh();
  }

  /// UC40: vô hiệu hóa (backend 409 nếu vi phạm BR-50 - ném lỗi cho UI xử lý).
  Future<void> deactivateStaff(int id, {String? reason}) async {
    await _api.deactivateStaff(id, reason: reason);
    await refresh();
  }
}

final staffDirectoryProvider =
    AsyncNotifierProvider<StaffDirectoryNotifier, StaffListResult>(
  StaffDirectoryNotifier.new,
);

/// Notifier chi tiết 1 nhân viên (UC37) - fetch tường minh theo id
/// (cùng pattern với ProfileNotifier của Module 1).
class StaffDetailNotifier extends AsyncNotifier<StaffDetail?> {
  StaffAPIService get _api => ref.read(staffApiServiceProvider);

  @override
  Future<StaffDetail?> build() async => null;

  Future<void> fetch(int staffId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _api.getStaffDetail(staffId));
  }

  /// UC39: cập nhật hồ sơ rồi tải lại chi tiết.
  /// @returns true nếu backend báo avatar upload thất bại (AT3 - text đã lưu).
  Future<bool> updateStaff(
    int id, {
    required String fullName,
    required String phone,
    required String role,
    Uint8List? avatarBytes,
  }) async {
    final avatarUploadFailed = await _api.updateStaff(
      id,
      fullName: fullName,
      phone: phone,
      role: role,
      avatarBytes: avatarBytes,
    );
    await fetch(id);
    return avatarUploadFailed;
  }

  Future<void> resetPassword(int id, String newPassword) =>
      _api.resetPassword(id, newPassword);
}

final staffDetailProvider =
    AsyncNotifierProvider<StaffDetailNotifier, StaffDetail?>(
  StaffDetailNotifier.new,
);
