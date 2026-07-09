import 'package:apartment_management/core/constants/app_strings.dart';
import 'package:apartment_management/core/network/token_storage.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/auth_profile/repositories/auth_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthAPIService extends Mock implements AuthAPIService {}

/// Bản in-memory thay flutter_secure_storage trong unit test
/// (plugin không chạy được ngoài thiết bị thật/emulator).
class FakeTokenStorage implements TokenStorage {
  String? token;
  String? userJson;
  bool mustChangePassword = false;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readUserJson() async => userJson;

  @override
  Future<bool> readMustChangePassword() async => mustChangePassword;

  @override
  Future<void> saveSession({
    required String token,
    required String userJson,
    required bool mustChangePassword,
  }) async {
    this.token = token;
    this.userJson = userJson;
    this.mustChangePassword = mustChangePassword;
  }

  @override
  Future<void> clear() async {
    token = null;
    userJson = null;
    mustChangePassword = false;
  }
}

void main() {
  late MockAuthAPIService mockApi;
  late FakeTokenStorage fakeStorage;
  late ProviderContainer container;

  const testUser = User(
    id: 1,
    phoneNumber: '0900000003',
    fullName: 'Nguyễn Văn Cư Dân',
    roles: ['RESIDENT'],
  );

  setUp(() {
    mockApi = MockAuthAPIService();
    fakeStorage = FakeTokenStorage();
    container = ProviderContainer(
      overrides: [
        authApiServiceProvider.overrideWithValue(mockApi),
        tokenStorageProvider.overrideWithValue(fakeStorage),
      ],
    );
    addTearDown(container.dispose);
  });

  group('AuthNotifier - UC01 Login', () {
    test('đăng nhập thành công: state authenticated, đúng roles, token được lưu',
        () async {
      when(() => mockApi.signIn('0900000003', 'Apora@123')).thenAnswer(
        (_) async => const AuthResponse(
          token: 'jwt-token-abc',
          mustChangePassword: true,
          user: testUser,
        ),
      );

      await container
          .read(authNotifierProvider.notifier)
          .login('0900000003', 'Apora@123');

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.roles, ['RESIDENT']);
      expect(state.mustChangePassword, isTrue); // BR-01
      expect(fakeStorage.token, 'jwt-token-abc'); // lưu secure storage
    });

    test('đăng nhập sai: state unauthenticated + errorMessage MSG02', () async {
      when(() => mockApi.signIn(any(), any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 401,
            data: {'status': 'error', 'message': AppStrings.msgLoginFailed},
          ),
        ),
      );

      await container
          .read(authNotifierProvider.notifier)
          .login('0900000003', 'sai-mat-khau');

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.errorMessage, AppStrings.msgLoginFailed);
      expect(fakeStorage.token, isNull);
    });
  });

  group('AuthNotifier - UC02 Logout', () {
    test('logout xóa state và secure storage, kể cả khi API lỗi', () async {
      // Đăng nhập trước
      when(() => mockApi.signIn(any(), any())).thenAnswer(
        (_) async => const AuthResponse(
          token: 'jwt-token-abc',
          mustChangePassword: false,
          user: testUser,
        ),
      );
      await container
          .read(authNotifierProvider.notifier)
          .login('0900000003', 'Apora@123');

      // API logout lỗi mạng -> vẫn phải xóa phiên local (UC02 alternative flow)
      when(() => mockApi.signOut()).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/logout'),
          type: DioExceptionType.connectionError,
        ),
      );

      await container.read(authNotifierProvider.notifier).logout();

      final state = container.read(authNotifierProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.user, isNull);
      expect(fakeStorage.token, isNull);
      expect(fakeStorage.userJson, isNull);
    });
  });
}
