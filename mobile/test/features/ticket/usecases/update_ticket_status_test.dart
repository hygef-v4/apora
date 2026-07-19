import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/ticket/models/ticket.dart';
import 'package:apartment_management/features/ticket/screens/ticket_detail_screen.dart';
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

  group('UC20: Update Ticket Status - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio, int ticketId = 1}) {
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
          home: TicketDetailScreen(ticketId: ticketId),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render chi tiết sự cố và khối cập nhật cho MANAGER (BR-40)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': {
          'id': 1,
          'category': 'PLUMBING',
          'description': 'Rò rỉ nước vòi rửa chén',
          'beforeImages': [],
          'status': 'PENDING',
          'unitNumber': 'P.502',
          'residentId': 10,
          'residentName': 'Nguyen Van A',
          'residentPhone': '0901234567',
          'internalNotes': null,
          'assigneeName': null,
          'createdAt': '2026-06-01T10:00:00.000Z',
          'updatedAt': '2026-06-01T10:00:00.000Z',
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Chi Tiết Sự Cố'), findsOneWidget);
      expect(find.text('Nguyen Van A'), findsOneWidget);
      expect(find.textContaining('Rò rỉ nước'), findsOneWidget);
      expect(find.text('LƯU THAY ĐỔI'), findsOneWidget);
    });

    testWidgets('2. Validation Tests: Chặn lưu khi không có thay đổi (AT4)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': {
          'id': 1,
          'category': 'PLUMBING',
          'description': 'Rò rỉ nước vòi rửa chén',
          'beforeImages': [],
          'status': 'PENDING',
          'unitNumber': 'P.502',
          'residentId': 10,
          'residentName': 'Nguyen Van A',
          'residentPhone': '0901234567',
          'internalNotes': null,
          'assigneeName': null,
          'createdAt': '2026-06-01T10:00:00.000Z',
          'updatedAt': '2026-06-01T10:00:00.000Z',
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Tap LƯU THAY ĐỔI without changing anything
      final saveBtn = find.text('LƯU THAY ĐỔI');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Không có thay đổi để lưu.'), findsOneWidget);
    });

    testWidgets('3. Success Flow: Cập nhật ghi chú nội bộ thành công (POS-01)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': {
          'id': 1,
          'category': 'PLUMBING',
          'description': 'Rò rỉ nước vòi rửa chén',
          'beforeImages': [],
          'status': 'PENDING',
          'unitNumber': 'P.502',
          'residentId': 10,
          'residentName': 'Nguyen Van A',
          'residentPhone': '0901234567',
          'internalNotes': null,
          'assigneeName': null,
          'createdAt': '2026-06-01T10:00:00.000Z',
          'updatedAt': '2026-06-01T10:00:00.000Z',
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      when(() => mockDio.put(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: {'status': 'success', 'data': mockData['data']},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Enter internal notes
      final notesField = find.byType(TextField).first;
      await tester.enterText(notesField, 'Đã kiểm tra sơ bộ, cần cử thợ nước.');
      await tester.pumpAndSettle();

      // Tap LƯU THAY ĐỔI
      final saveBtn = find.text('LƯU THAY ĐỔI');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      verify(() => mockDio.put(any(), data: any(named: 'data'))).called(1);
    });
  });

  // Regression BR-40: dropdown đổi trạng thái THỦ CÔNG (UC20) không bao giờ
  // được chào "Đã phân công" (ASSIGNED). ASSIGNED chỉ đặt qua Phân công (UC21)
  // để luôn có task + người xử lý đi kèm. Khóa lại đúng bug đã sửa.
  group('BR-40 regression: không cho chuyển thủ công sang ASSIGNED', () {
    test('PENDING chỉ cho phép CANCELLED, KHÔNG có ASSIGNED', () {
      expect(kTicketNextStatuses['PENDING'], equals(['CANCELLED']));
      expect(kTicketNextStatuses['PENDING'], isNot(contains('ASSIGNED')));
    });

    test('Không bước THỦ CÔNG nào dẫn tới ASSIGNED', () {
      for (final entry in kTicketNextStatuses.entries) {
        expect(
          entry.value,
          isNot(contains('ASSIGNED')),
          reason: '${entry.key} không được phép chuyển thủ công sang ASSIGNED',
        );
      }
    });
  });
}
