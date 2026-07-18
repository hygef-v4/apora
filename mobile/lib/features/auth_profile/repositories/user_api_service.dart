import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/user.dart';

/// Kết quả UC05: hồ sơ sau cập nhật + cờ avatar upload thất bại (AT3).
class ProfileUpdateResult {
  const ProfileUpdateResult({
    required this.user,
    required this.avatarUploadFailed,
  });

  final User user;

  /// true = backend đã lưu field text nhưng upload avatar lỗi (giữ ảnh cũ).
  final bool avatarUploadFailed;
}

/// Service gọi các REST API User của backend Next.js (UC04-UC05).
class UserAPIService {
  UserAPIService(this._dio);

  final Dio _dio;

  Future<User> getProfile() async {
    final res = await _dio.get(ApiConstants.profile);
    return User.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// [avatarBytes] đã được nén < 500KB ở tầng gọi (BR-10) trước khi truyền vào.
  /// [currentPassword] bắt buộc khi đổi SĐT (backend xác nhận chủ tài khoản).
  Future<ProfileUpdateResult> updateProfile({
    required String fullName,
    required String phone,
    Uint8List? avatarBytes,
    String? currentPassword,
  }) async {
    final form = FormData.fromMap({
      'fullName': fullName,
      'phone': phone,
      'currentPassword': ?currentPassword,
      if (avatarBytes != null)
        'avatar': MultipartFile.fromBytes(avatarBytes, filename: 'avatar.jpg'),
    });
    final res = await _dio.put(ApiConstants.profile, data: form);
    final data = res.data['data'] as Map<String, dynamic>;
    return ProfileUpdateResult(
      user: User.fromJson(data),
      avatarUploadFailed: data['avatarUploadFailed'] == true,
    );
  }
}

final userApiServiceProvider =
    Provider<UserAPIService>((ref) => UserAPIService(ref.watch(dioProvider)));
