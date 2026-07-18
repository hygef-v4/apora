import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/ticket/screens/task_list_screen.dart';
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

  group('UC22: Staff View Task List & Detail - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio}) {
      final authState = AuthState(
        user: User(
          id: 101,
          fullName: 'Staff User',
          phoneNumber: '0901234567',
          roles: ['TECHNICIAN'],
        ),
        status: AuthStatus.authenticated,
      );

      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(authState)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TaskListBody(),
          ),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render danh sách công việc của nhân viên (BR-42)', (tester) async {
      final mockTasks = {
        'data': [
          {
            'id': 1,
            'ticketId': 10,
            'title': 'Sửa ống nước P.502',
            'description': 'Mô tả chi tiết',
            'status': 'ASSIGNED',
            'category': 'PLUMBING',
            'unitNumber': '502',
            'assignedByName': 'Manager B',
            'assignedAt': '2026-06-01T10:00:00.000Z',
            'completedAt': null,
          },
          {
            'id': 2,
            'ticketId': 11,
            'title': 'Sửa ổ cắm P.301',
            'description': null,
            'status': 'COMPLETED',
            'category': 'ELECTRICAL',
            'unitNumber': '301',
            'assignedByName': 'Manager B',
            'assignedAt': '2026-05-01T10:00:00.000Z',
            'completedAt': '2026-05-02T10:00:00.000Z',
          }
        ]
      };

      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: mockTasks,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Sửa ống nước P.502'), findsOneWidget);
      expect(find.text('Sửa ổ cắm P.301'), findsOneWidget);

      // Filter tab 'Đang làm'
      final activeChip = find.textContaining('Đang làm');
      await tester.tap(activeChip);
      await tester.pumpAndSettle();

      expect(find.text('Sửa ống nước P.502'), findsOneWidget);
      expect(find.text('Sửa ổ cắm P.301'), findsNothing);
    });

    testWidgets('2. Alternative Flow (AT1): Màn hình hiển thị khi chưa có công việc nào', (tester) async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: {'data': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có công việc nào được giao cho bạn.'), findsOneWidget);
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
