import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/ticket/screens/ticket_list_screen.dart';
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

  group('UC18: View Ticket List & Details - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio, required String role}) {
      final authState = AuthState(
        user: User(
          id: 1,
          fullName: 'Test User',
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
          home: TicketListScreen(showBack: false),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render danh sách sự cố và FAB Tạo Báo Cáo cho RESIDENT', (tester) async {
      final mockData = {
        'data': [
          {
            'id': 1,
            'category': 'PLUMBING',
            'description': 'Rò rỉ nước vòi rửa chén',
            'beforeImages': [],
            'status': 'PENDING',
            'unitNumber': 'P.502',
            'residentName': 'Nguyen Van A',
            'assigneeName': null,
            'createdAt': '2026-06-01T10:00:00.000Z',
            'updatedAt': '2026-06-01T10:00:00.000Z',
          },
          {
            'id': 2,
            'category': 'ELECTRICAL',
            'description': 'Hỏng ổ cắm điện phòng khách',
            'beforeImages': [],
            'status': 'RESOLVED',
            'unitNumber': 'P.301',
            'residentName': 'Tran Van B',
            'assigneeName': 'Kỹ thuật C',
            'createdAt': '2026-05-01T10:00:00.000Z',
            'updatedAt': '2026-05-02T10:00:00.000Z',
          }
        ]
      };

      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'RESIDENT'));
      await tester.pumpAndSettle();

      // Verify Header and List Items
      expect(find.text('Bảo trì'), findsOneWidget);
      expect(find.textContaining('Rò rỉ nước'), findsOneWidget);
      expect(find.textContaining('Hỏng ổ cắm'), findsOneWidget);

      // UC19: nút "Báo sự cố" chỉ hiển thị cho RESIDENT
      expect(find.byTooltip('Báo sự cố'), findsOneWidget);
    });

    testWidgets('2. UI & Widget Tests: Ẩn FAB Tạo Báo Cáo đối với Quản lý / MANAGER', (tester) async {
      final mockData = {'data': []};

      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'MANAGER'));
      await tester.pumpAndSettle();

      // UC19: MANAGER không được thấy nút "Báo sự cố"
      expect(find.byTooltip('Báo sự cố'), findsNothing);
    });

    testWidgets('3. Alternative Flow (AT1): Màn hình hiển thị khi danh sách sự cố trống', (tester) async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: {'data': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'RESIDENT'));
      await tester.pumpAndSettle();

      expect(find.text('Không có sự cố nào.'), findsOneWidget);
    });

    testWidgets('4. Error Handling: Tải danh sách thất bại hiển thị nút Thử lại', (tester) async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'RESIDENT'));
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
