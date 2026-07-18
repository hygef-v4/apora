import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/ticket/models/ticket.dart';
import 'package:apartment_management/features/ticket/screens/assign_task_screen.dart';
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

  group('UC21: Assign Ticket Task to Operational Staff - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    final testTicket = TicketDetail(
      id: 1,
      category: 'PLUMBING',
      description: 'Rò rỉ nước vòi rửa chén',
      beforeImages: [],
      status: 'PENDING',
      unitNumber: 'P.502',
      reporterName: 'Nguyen Van A',
      residentId: 10,
      residentName: 'Nguyen Van A',
      residentPhone: '0901234567',
      createdAt: DateTime.parse('2026-06-01T10:00:00.000Z'),
      updatedAt: DateTime.parse('2026-06-01T10:00:00.000Z'),
    );

    Widget createWidget({required MockDio dio}) {
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
          home: AssignTaskScreen(ticket: testTicket),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render giao diện phân công công việc', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockStaff = {
        'data': [
          {
            'id': 101,
            'fullName': 'Nguyen Van Tech',
            'roles': ['TECHNICIAN'],
            'openTaskCount': 0,
          },
          {
            'id': 102,
            'fullName': 'Tran Van Janitor',
            'roles': ['JANITOR'],
            'openTaskCount': 2,
          }
        ]
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockStaff,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Phân Công Công Việc'), findsOneWidget);
      expect(find.text('Nguyen Van Tech'), findsOneWidget);
      expect(find.text('Tran Van Janitor'), findsOneWidget);
      expect(find.text('PHÂN CÔNG'), findsOneWidget);
    });

    testWidgets('2. Validation Tests: Chặn submit khi chưa chọn nhân viên (AT2)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockStaff = {
        'data': [
          {
            'id': 101,
            'fullName': 'Nguyen Van Tech',
            'roles': ['TECHNICIAN'],
            'openTaskCount': 0,
          }
        ]
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockStaff,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Tap PHÂN CÔNG without selecting staff
      final submitBtn = find.text('PHÂN CÔNG');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng chọn nhân viên để phân công.'), findsOneWidget);
    });

    testWidgets('3. Success Flow: Phân công sự cố thành công (POS-01)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockStaff = {
        'data': [
          {
            'id': 101,
            'fullName': 'Nguyen Van Tech',
            'roles': ['TECHNICIAN'],
            'openTaskCount': 0,
          }
        ]
      };

      final updatedTicket = {
        'data': {
          'id': 1,
          'category': 'PLUMBING',
          'description': 'Rò rỉ nước vòi rửa chén',
          'beforeImages': [],
          'status': 'ASSIGNED',
          'unitNumber': 'P.502',
          'residentId': 10,
          'residentName': 'Nguyen Van A',
          'residentPhone': '0901234567',
          'internalNotes': null,
          'assigneeName': 'Nguyen Van Tech',
          'createdAt': '2026-06-01T10:00:00.000Z',
          'updatedAt': '2026-06-01T10:00:00.000Z',
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockStaff,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: updatedTicket,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Select staff
      await tester.tap(find.text('Nguyen Van Tech'));
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.text('PHÂN CÔNG');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      verify(() => mockDio.post(any(), data: any(named: 'data'))).called(1);
    });
  });
}
