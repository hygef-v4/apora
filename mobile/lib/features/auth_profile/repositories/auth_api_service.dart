import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/user.dart';

/// Kết quả đăng nhập từ POST /api/auth/login.
class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.mustChangePassword,
    required this.user,
  });

  final String token;
  final bool mustChangePassword;
  final User user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      mustChangePassword: json['mustChangePassword'] as bool,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Service gọi các REST API Auth của backend Next.js (UC01-UC03).
class AuthAPIService {
  AuthAPIService(this._dio);

  final Dio _dio;

  Future<AuthResponse> signIn(String phone, String password, {String? fcmToken}) async {
    final res = await _dio.post(ApiConstants.login, data: {
      'phone': phone,
      'password': password,
      'fcmToken': ?fcmToken,
    });
    return AuthResponse.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<void> signOut({String? fcmToken}) async {
    await _dio.post(ApiConstants.logout, data: {
      'fcmToken': ?fcmToken,
    });
  }

  /// UC03 bước 1: kiểm tra SĐT có tài khoản hợp lệ (404/403 nếu không)
  /// TRƯỚC khi app nhờ Firebase gửi SMS - tránh tốn SMS vô ích.
  Future<void> checkResetAccount(String phone) async {
    await _dio.post(ApiConstants.forgotPassword, data: {'phone': phone});
  }

  /// UC03 bước 2: gửi Firebase ID token (đã xác thực OTP với Firebase)
  /// để backend verify và đặt mật khẩu mới.
  Future<void> resetPassword(
    String phone,
    String firebaseIdToken,
    String newPassword,
  ) async {
    await _dio.post(ApiConstants.resetPassword, data: {
      'phone': phone,
      'firebaseIdToken': firebaseIdToken,
      'newPassword': newPassword,
    });
  }

  /// Trả về JWT mới (token cũ bị vô hiệu sau khi đổi mật khẩu - BR-07).
  Future<String> changePassword(String oldPassword, String newPassword) async {
    final res = await _dio.post(ApiConstants.changePassword, data: {
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
    return res.data['data']['token'] as String;
  }
}

final authApiServiceProvider =
    Provider<AuthAPIService>((ref) => AuthAPIService(ref.watch(dioProvider)));
