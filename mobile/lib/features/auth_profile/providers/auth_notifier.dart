import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/token_storage.dart';
import '../models/user.dart';
import '../repositories/auth_api_service.dart';

enum AuthStatus { unauthenticated, loading, authenticated }

/// State phiên đăng nhập (theo Software Design: AuthState).
class AuthState {
  const AuthState({
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.mustChangePassword = false,
    this.errorMessage,
  });

  final AuthStatus status;
  final User? user;

  /// BR-01: true khi đang dùng mật khẩu mặc định -> router ép vào màn đổi mật khẩu.
  final bool mustChangePassword;
  final String? errorMessage;

  List<String> get roles => user?.roles ?? const [];
  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? mustChangePassword,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier quản lý luồng đăng nhập/đăng xuất/OTP (UC01-UC03) + đổi mật khẩu.
class AuthNotifier extends Notifier<AuthState> {
  AuthAPIService get _api => ref.read(authApiServiceProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  @override
  AuthState build() => const AuthState();

  /// Khôi phục phiên từ secure storage khi mở app.
  /// Token hết hạn/bị vô hiệu -> API trả 401, Dio interceptor gọi sessionExpired().
  Future<void> restoreSession() async {
    final token = await _storage.readToken();
    final userJson = await _storage.readUserJson();
    if (token == null || userJson == null) return;
    try {
      final user = User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      // BR-01: đọc lại cờ từ storage - kill app không thoát được màn ép đổi mật khẩu
      final mustChangePassword = await _storage.readMustChangePassword();
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
        mustChangePassword: mustChangePassword,
      );
    } catch (_) {
      await _storage.clear();
    }
  }

  /// UC01: Đăng nhập. Token lưu vào flutter_secure_storage (KHÔNG SharedPreferences).
  Future<void> login(String phone, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      // TODO(Module 5): truyền fcmToken khi đã setup Firebase Messaging (BR-44)
      final res = await _api.signIn(phone, password);
      await _storage.saveSession(
        token: res.token,
        userJson: jsonEncode(res.user.toJson()),
        mustChangePassword: res.mustChangePassword,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: res.user,
        mustChangePassword: res.mustChangePassword,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: mapDioError(e),
      );
    }
  }

  /// UC02: Đăng xuất. Luôn xóa local + về Login kể cả khi API lỗi
  /// (theo alternative flow trong SRS).
  Future<void> logout() async {
    try {
      await _api.signOut();
    } catch (_) {
      // Bỏ qua lỗi mạng - vẫn phải xóa phiên local
    } finally {
      await _storage.clear();
      state = const AuthState();
    }
  }

  /// UC03 bước 1: Yêu cầu OTP. Trả về devOtp nếu backend chạy dev mode.
  Future<String?> requestOtp(String phone) async {
    return _api.requestOtp(phone);
  }

  /// UC03 bước 2: Xác thực OTP + đặt mật khẩu mới, sau đó user đăng nhập lại.
  Future<void> resetPassword(String phone, String otp, String newPassword) async {
    await _api.resetPassword(phone, otp, newPassword);
  }

  /// Đổi mật khẩu khi đã đăng nhập (flow BR-01). Backend trả token mới.
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final newToken = await _api.changePassword(oldPassword, newPassword);
    final user = state.user;
    if (user != null) {
      await _storage.saveSession(
        token: newToken,
        userJson: jsonEncode(user.toJson()),
        mustChangePassword: false,
      );
    }
    state = state.copyWith(mustChangePassword: false);
  }

  /// Gọi từ Dio interceptor khi backend trả 401 (token hết hạn / bị vô hiệu - BR-07).
  /// Chỉ xóa phiên local, KHÔNG gọi API logout (token đã mất hiệu lực sẵn);
  /// router sẽ tự đưa về màn Login.
  Future<void> sessionExpired() async {
    if (!state.isAuthenticated) return;
    await _storage.clear();
    state = const AuthState(errorMessage: AppStrings.msgSessionExpired);
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
