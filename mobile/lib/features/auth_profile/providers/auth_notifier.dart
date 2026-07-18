import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../../core/constants/app_strings.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/token_storage.dart';
import '../../../core/services/phone_otp_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../models/user.dart';
import '../repositories/auth_api_service.dart';
import '../repositories/user_api_service.dart';

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
      // Refresh hồ sơ từ server ở nền: dữ liệu trong storage có thể cũ
      // (tên/avatar/role đổi từ thiết bị khác); token hết hạn thì interceptor
      // 401 tự xóa phiên. Bỏ qua khi đang bị ép đổi mật khẩu (BR-01 chặn 403).
      if (!mustChangePassword) {
        unawaited(_refreshUserFromServer());
      }
    } catch (_) {
      await _storage.clear();
    }
  }

  Future<void> _refreshUserFromServer() async {
    try {
      final fresh = await ref.read(userApiServiceProvider).getProfile();
      await updateUser(fresh);
    } catch (_) {
      // Lỗi mạng -> giữ dữ liệu local; 401 đã được interceptor xử lý riêng
    }
  }

  /// Đồng bộ user mới nhất vào state + storage (gọi sau khi UC05 cập nhật hồ sơ
  /// thành công, hoặc khi refresh từ server) - tránh tên/avatar/SĐT bị stale.
  Future<void> updateUser(User user) async {
    if (!state.isAuthenticated) return;
    final token = await _storage.readToken();
    if (token != null && token.isNotEmpty) {
      await _storage.saveSession(
        token: token,
        userJson: jsonEncode(user.toJson()),
        mustChangePassword: state.mustChangePassword,
      );
    }
    state = state.copyWith(user: user);
  }

  /// UC01: Đăng nhập. Token lưu vào flutter_secure_storage (KHÔNG SharedPreferences).
  Future<void> login(String phone, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final fcmToken = await pushNotificationService.getToken();
      final res = await _api.signIn(phone, password, fcmToken: fcmToken);
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
      final fcmToken = await pushNotificationService.getToken();
      await _api.signOut(fcmToken: fcmToken);
    } catch (_) {
      // Bỏ qua lỗi mạng - vẫn phải xóa phiên local
    } finally {
      await _storage.clear();
      state = const AuthState();
    }
  }

  /// UC03 bước 1: backend kiểm tra tài khoản (404/403 nếu không hợp lệ),
  /// sau đó Firebase Phone Auth gửi SMS OTP tới SĐT (BR-08).
  Future<void> requestOtp(String phone) async {
    await _api.checkResetAccount(phone);
    await ref.read(phoneOtpServiceProvider).sendOtp(phone);
  }

  /// UC03 bước 2: xác thực OTP với Firebase lấy ID token, gửi backend đổi
  /// mật khẩu, xong thì dọn phiên Firebase tạm. Sau đó user đăng nhập lại.
  Future<void> resetPassword(String phone, String smsCode, String newPassword) async {
    final otpService = ref.read(phoneOtpServiceProvider);
    final idToken = await otpService.confirmAndGetIdToken(smsCode);
    await _api.resetPassword(phone, idToken, newPassword);
    // Chỉ dọn khi thành công - backend từ chối (vd mật khẩu trùng) thì giữ
    // phiên Firebase để người dùng sửa và gửi lại, không phải xin OTP mới.
    await otpService.clearSession();
  }

  /// Đổi mật khẩu khi đã đăng nhập (flow BR-01). Backend trả token mới.
  /// LUÔN lưu token mới: token cũ đã bị vô hiệu (BR-07), không lưu là các
  /// request sau dính 401 và người dùng bị đá ra ngoài.
  Future<void> changePassword(String oldPassword, String newPassword) async {
    final newToken = await _api.changePassword(oldPassword, newPassword);
    final userJson = state.user != null
        ? jsonEncode(state.user!.toJson())
        : await _storage.readUserJson() ?? '{}';
    await _storage.saveSession(
      token: newToken,
      userJson: userJson,
      mustChangePassword: false,
    );
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
