import 'package:apartment_management/core/constants/app_strings.dart';
import 'package:apartment_management/core/network/token_storage.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/repositories/auth_api_service.dart';
import 'package:apartment_management/features/auth_profile/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthAPIService extends Mock implements AuthAPIService {}

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

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        authApiServiceProvider.overrideWithValue(mockApi),
        tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );
  }

  setUp(() {
    mockApi = MockAuthAPIService();
  });

  group('LoginScreen - UC01 (FID-01)', () {
    testWidgets('bỏ trống Số điện thoại -> hiện lỗi inline MSG01, chặn submit',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      await tester.tap(find.text('Đăng nhập'));
      await tester.pump();

      expect(find.text(AppStrings.msgPhoneRequired), findsOneWidget);
      expect(find.text(AppStrings.msgPasswordRequired), findsOneWidget);
      verifyNever(() => mockApi.signIn(any(), any()));
    });

    testWidgets('nhập đủ thông tin -> gọi API đăng nhập', (tester) async {
      when(() => mockApi.signIn('0900000003', 'Apora@123')).thenAnswer(
        (_) async => const AuthResponse(
          token: 'jwt-token-abc',
          mustChangePassword: false,
          user: User(
            id: 1,
            phoneNumber: '0900000003',
            fullName: 'Nguyễn Văn Cư Dân',
            roles: ['RESIDENT'],
          ),
        ),
      );

      await tester.pumpWidget(buildTestApp());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại'),
        '0900000003',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu'),
        'Apora@123',
      );
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      verify(() => mockApi.signIn('0900000003', 'Apora@123')).called(1);
    });
  });
}
