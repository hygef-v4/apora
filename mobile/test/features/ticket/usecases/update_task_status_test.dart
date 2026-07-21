import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/ticket/screens/task_detail_screen.dart';
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

  group('UC23: Staff Update Task Progress & Complete - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio, int taskId = 1}) {
      final authState = AuthState(
        user: User(
          id: 101,
          fullName: 'Staff Tech',
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
        child: MaterialApp(
          home: TaskDetailScreen(taskId: taskId),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render chi tiết công việc cho nhân viên', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockTaskDetail = {
        'data': {
          'id': 1,
          'ticketId': 10,
          'title': 'Sửa ống nước P.502',
          'description': 'Kiểm tra đường ống',
          'status': 'ASSIGNED',
          'category': 'PLUMBING',
          'unitNumber': '502',
          'assignedByName': 'Manager B',
          'assignedAt': '2026-06-01T10:00:00.000Z',
          'completedAt': null,
          'ticketDescription': 'Rò rỉ nước vòi rửa chén',
          'ticketBeforeImages': [],
          'residentName': 'Nguyen Van A',
          'progressNotes': null,
          'completionImages': [],
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockTaskDetail,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Task Detail'), findsOneWidget);
      expect(find.text('Sửa ống nước P.502'), findsOneWidget);
      expect(find.text('START TASK'), findsOneWidget);
      expect(find.text('MARK AS COMPLETE'), findsOneWidget);
    });

    testWidgets('2. Validation Tests: Nghiệm thu công việc bắt buộc phải có ít nhất 1 ảnh (AT1/BR-43)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockTaskDetail = {
        'data': {
          'id': 1,
          'ticketId': 10,
          'title': 'Sửa ống nước P.502',
          'description': 'Kiểm tra đường ống',
          'status': 'IN_PROGRESS',
          'category': 'PLUMBING',
          'unitNumber': '502',
          'assignedByName': 'Manager B',
          'assignedAt': '2026-06-01T10:00:00.000Z',
          'completedAt': null,
          'ticketDescription': 'Rò rỉ nước vòi rửa chén',
          'ticketBeforeImages': [],
          'residentName': 'Nguyen Van A',
          'progressNotes': null,
          'completionImages': [],
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockTaskDetail,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Tap ĐÁNH DẤU HOÀN THÀNH without attaching photo
      final completeBtn = find.text('MARK AS COMPLETE');
      await tester.tap(completeBtn);
      await tester.pumpAndSettle();

      expect(find.text('At least 1 completion photo is required to finish the task.'), findsOneWidget);
    });

    testWidgets('3. Success Flow: Bắt đầu làm công việc chuyển trạng thái sang IN_PROGRESS (POS-01)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockTaskDetail = {
        'data': {
          'id': 1,
          'ticketId': 10,
          'title': 'Sửa ống nước P.502',
          'description': 'Kiểm tra đường ống',
          'status': 'ASSIGNED',
          'category': 'PLUMBING',
          'unitNumber': '502',
          'assignedByName': 'Manager B',
          'assignedAt': '2026-06-01T10:00:00.000Z',
          'completedAt': null,
          'ticketDescription': 'Rò rỉ nước vòi rửa chén',
          'ticketBeforeImages': [],
          'residentName': 'Nguyen Van A',
          'progressNotes': null,
          'completionImages': [],
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockTaskDetail,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      when(() => mockDio.put(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: {
            'data': {
              ...mockTaskDetail['data']!,
              'status': 'IN_PROGRESS',
            }
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Tap BẮT ĐẦU LÀM
      final startBtn = find.text('START TASK');
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      verify(() => mockDio.put(any(), data: any(named: 'data'))).called(1);
    });
  });
}
