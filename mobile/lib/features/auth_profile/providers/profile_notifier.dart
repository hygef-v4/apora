import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user.dart';
import '../repositories/user_api_service.dart';

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
  Future<void> updateProfile({
    required String fullName,
    required String phone,
    Uint8List? avatarBytes,
  }) async {
    final updated = await _api.updateProfile(
      fullName: fullName,
      phone: phone,
      avatarBytes: avatarBytes,
    );
    state = AsyncData(updated);
  }
}

final profileNotifierProvider =
    AsyncNotifierProvider<ProfileNotifier, User?>(ProfileNotifier.new);
