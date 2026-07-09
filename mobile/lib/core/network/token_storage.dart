import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';

/// Interface lưu trữ phiên đăng nhập.
/// Tách interface để unit test override bằng bản in-memory (không cần plugin).
abstract class TokenStorage {
  Future<String?> readToken();
  Future<void> saveSession({
    required String token,
    required String userJson,
    required bool mustChangePassword,
  });
  Future<String?> readUserJson();

  /// BR-01: cờ "phải đổi mật khẩu" phải được lưu lại - nếu chỉ giữ trong state,
  /// kill app rồi mở lại là thoát được màn ép đổi mật khẩu.
  Future<bool> readMustChangePassword();
  Future<void> clear();
}

/// Bản chính thức: flutter_secure_storage (BẮT BUỘC - không dùng SharedPreferences).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: StorageKeys.jwtToken);

  @override
  Future<void> saveSession({
    required String token,
    required String userJson,
    required bool mustChangePassword,
  }) async {
    await _storage.write(key: StorageKeys.jwtToken, value: token);
    await _storage.write(key: StorageKeys.userJson, value: userJson);
    await _storage.write(
      key: StorageKeys.mustChangePassword,
      value: mustChangePassword.toString(),
    );
  }

  @override
  Future<String?> readUserJson() => _storage.read(key: StorageKeys.userJson);

  @override
  Future<bool> readMustChangePassword() async {
    final value = await _storage.read(key: StorageKeys.mustChangePassword);
    return value == 'true';
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: StorageKeys.jwtToken);
    await _storage.delete(key: StorageKeys.userJson);
    await _storage.delete(key: StorageKeys.mustChangePassword);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());
