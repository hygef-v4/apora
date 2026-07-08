import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/user.dart';

/// Service gọi các REST API User của backend Next.js (UC04-UC05).
class UserAPIService {
  UserAPIService(this._dio);

  final Dio _dio;

  Future<User> getProfile() async {
    final res = await _dio.get(ApiConstants.profile);
    return User.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// [avatarBytes] đã được nén < 500KB ở tầng gọi (BR-10) trước khi truyền vào.
  Future<User> updateProfile({
    required String fullName,
    required String phone,
    Uint8List? avatarBytes,
  }) async {
    final form = FormData.fromMap({
      'fullName': fullName,
      'phone': phone,
      if (avatarBytes != null)
        'avatar': MultipartFile.fromBytes(avatarBytes, filename: 'avatar.jpg'),
    });
    final res = await _dio.put(ApiConstants.profile, data: form);
    return User.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}

final userApiServiceProvider =
    Provider<UserAPIService>((ref) => UserAPIService(ref.watch(dioProvider)));
