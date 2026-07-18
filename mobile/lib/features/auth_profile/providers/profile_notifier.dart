import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../repositories/user_api_service.dart';
import 'auth_notifier.dart';

/// Notifier quản lý hồ sơ cá nhân (UC04-UC05).
class ProfileNotifier extends AsyncNotifier<User?> {
  UserAPIService get _api => ref.read(userApiServiceProvider);

  @override
  Future<User?> build() async => null;

  /// UC04: Tải hồ sơ từ server.
  Future<void> fetchProfile() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _api.getProfile());
  }

  /// UC05: Cập nhật hồ sơ. [avatarBytes] đã nén < 500KB (BR-10).
  /// [currentPassword] bắt buộc khi đổi SĐT.
  /// @returns true nếu backend báo avatar upload thất bại (AT3 - text đã lưu).
  Future<bool> updateProfile({
    required String fullName,
    required String phone,
    Uint8List? avatarBytes,
    String? currentPassword,
  }) async {
    final result = await _api.updateProfile(
      fullName: fullName,
      phone: phone,
      avatarBytes: avatarBytes,
      currentPassword: currentPassword,
    );
    state = AsyncData(result.user);
    // Đồng bộ về AuthNotifier + secure storage - các màn đọc authState.user
    // (home header, workspace select) không bị hiển thị tên/SĐT cũ
    await ref.read(authNotifierProvider.notifier).updateUser(result.user);
    return result.avatarUploadFailed;
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, User?>(ProfileNotifier.new);
