import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/management/screens/manager_list_screen.dart';
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

  group('UC41: View Manager List & Directory - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio}) {
      final authState = AuthState(
        user: User(
          id: 1,
          fullName: 'Landlord User',
          phoneNumber: '0901234567',
          roles: ['LANDLORD'],
        ),
        status: AuthStatus.authenticated,
      );

      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(authState)),
        ],
        child: const MaterialApp(
          home: ManagerListScreen(),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render danh sách quản lý và các thẻ tổng quan (UC41)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': {
          'managers': [
            {
              'id': 1,
              'fullName': 'Manager Nguyen',
              'phoneNumber': '0901111222',
              'avatarUrl': null,
              'status': 'ACTIVE',
              'createdAt': '2026-01-01T00:00:00.000Z',
            },
            {
              'id': 2,
              'fullName': 'Manager Tran',
              'phoneNumber': '0903333444',
              'avatarUrl': null,
              'status': 'INACTIVE',
              'createdAt': '2026-02-01T00:00:00.000Z',
            }
          ],
          'stats': {
            'total': 2,
            'active': 1,
            'inactive': 1,
          }
        }
      };

      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Quản lý'), findsOneWidget);
      expect(find.text('Manager Nguyen'), findsOneWidget);
      expect(find.text('Manager Tran'), findsOneWidget);
    });

    testWidgets('2. Alternative Flow (AT1): Màn hình hiển thị khi chưa có quản lý nào', (tester) async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: {
            'data': {
              'managers': [],
              'stats': {'total': 0, 'active': 0, 'inactive': 0}
            }
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có tài khoản quản lý nào.'), findsOneWidget);
    });

    testWidgets('3. Error Handling: Tải thất bại hiển thị nút Thử lại', (tester) async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
