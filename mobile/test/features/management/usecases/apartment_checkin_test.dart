import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/management/screens/apartment_checkin_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockAuthNotifier extends Notifier<AuthState> with Mock implements AuthNotifier {
  final AuthState _initialState;
  MockAuthNotifier(this._initialState);
  @override
  AuthState build() => _initialState;
}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  group('UC33: Apartment Check-in - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio, int apartmentId = 1}) {
      final authState = AuthState(
        user: User(
          id: 1,
          fullName: 'Manager User',
          phoneNumber: '0901234567',
          roles: ['MANAGER'],
        ),
        status: AuthStatus.authenticated,
      );

      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(authState)),
        ],
        child: MaterialApp(
          home: ApartmentCheckinScreen(apartmentId: apartmentId),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render màn hình nhận phòng căn hộ', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Nhận phòng (Check-in)'), findsOneWidget);
      expect(find.text('Xác nhận Check-in'), findsOneWidget);
    });

    testWidgets('2. Validation Tests: Bắt buộc nhập họ tên và số điện thoại chủ hộ', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      final submitBtn = find.text('Xác nhận Check-in');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập họ tên cư dân.'), findsOneWidget);
      expect(find.text('Vui lòng nhập số điện thoại.'), findsOneWidget);
    });

    testWidgets('3. Success Flow: Nhận phòng thành công và tạo tài khoản cư dân (BR-01)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: {
            'status': 'success',
            'data': {'id': 1, 'status': 'OCCUPIED'}
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: {'data': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Enter fields
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Nguyen Van Resident');
      await tester.enterText(fields.at(1), '0912345678');
      await tester.pumpAndSettle();

      // Tap start date field and confirm date picker
      await tester.tap(fields.at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.text('Xác nhận Check-in');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      verify(() => mockDio.post(any(), data: any(named: 'data'))).called(1);
    });
  });
}
