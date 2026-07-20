import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/contract/screens/contract_screen.dart';
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

  group('UC06: View Contract & Stay Duration - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required String role, required MockDio dio}) {
      final authState = AuthState(
        user: User(
          id: 1,
          fullName: 'Nguyen Van A',
          phoneNumber: '0901234567',
          roles: [role],
        ),
        status: AuthStatus.authenticated,
      );

      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(authState)),
        ],
        child: const MaterialApp(
          home: ContractScreen(),
        ),
      );
    }

    /// Bố cục theo wireframe cao hơn viewport test mặc định (800x600) nên
    /// phải nới ra, nếu không nút cuối màn nằm ngoài vùng hiển thị.
    void useTallViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('1. UI & Widget Tests: Render thông tin hợp đồng của RESIDENT (BR-23 & BR-13)', (tester) async {
      useTallViewport(tester);
      final mockData = {
        'data': {
          'apartment': {
            'id': 101,
            'unitNumber': 'P.502',
            'floor': 'Tầng 5',
            'status': 'OCCUPIED',
          },
          'contract': {
            'id': 1,
            'startDate': '2026-01-01T00:00:00.000Z',
            'endDate': '2026-12-31T00:00:00.000Z',
            'baseRent': 5000000,
            'status': 'ACTIVE',
            'remainingDays': 166,
            'pendingExtensionId': null,
          }
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(role: 'RESIDENT', dio: mockDio));
      await tester.pumpAndSettle();

      // Verify header & title
      expect(find.text('Contract Details'), findsOneWidget);
      expect(find.text('Room P.502'), findsOneWidget);
      expect(find.textContaining('5.000.000'), findsOneWidget);

      // Verify remaining days display (BR-13)
      expect(find.textContaining('166'), findsOneWidget);

      // Verify extend button for RESIDENT role with ACTIVE contract (BR-09, BR-12)
      expect(find.text('REQUEST STAY EXTENSION'), findsOneWidget);
    });

    testWidgets('2. UI & Widget Tests: Ẩn nút gia hạn cho vai trò Quản lý / Manager', (tester) async {
      // Nới viewport để findsNothing là bằng chứng thật (nút bị ẩn theo vai
      // trò), không phải do nút nằm ngoài màn hình.
      useTallViewport(tester);
      final mockData = {
        'data': {
          'apartment': {
            'id': 101,
            'unitNumber': 'P.502',
            'floor': 'Tầng 5',
            'status': 'OCCUPIED',
          },
          'contract': {
            'id': 1,
            'startDate': '2026-01-01T00:00:00.000Z',
            'endDate': '2026-12-31T00:00:00.000Z',
            'baseRent': 5000000,
            'status': 'ACTIVE',
            'remainingDays': 166,
            'pendingExtensionId': null,
          }
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(role: 'MANAGER', dio: mockDio));
      await tester.pumpAndSettle();

      // Button "YÊU CẦU GIA HẠN" should NOT be visible for MANAGER
      expect(find.text('REQUEST STAY EXTENSION'), findsNothing);
    });

    testWidgets('3. Alternative Flow (AT2): Màn hình hiển thị khi cư dân chưa có hợp đồng', (tester) async {
      final mockData = {
        'data': {
          'apartment': null,
          'contract': null,
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(role: 'RESIDENT', dio: mockDio));
      await tester.pumpAndSettle();

      // Verify empty state UI for no contract
      expect(find.text('Your account is not linked to any apartment yet.'), findsOneWidget);
    });

    testWidgets('4. Error Handling: Tải thông tin hợp đồng thất bại hiển thị lỗi & Retry', (tester) async {
      when(() => mockDio.get(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      await tester.pumpWidget(createWidget(role: 'RESIDENT', dio: mockDio));
      await tester.pumpAndSettle();

      // Verify error state & Retry button
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
