import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/ticket/screens/ticket_create_screen.dart';
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

  group('UC19: Create Incident / Repair Ticket - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio}) {
      final authState = AuthState(
        user: User(
          id: 1,
          fullName: 'Resident User',
          phoneNumber: '0901234567',
          roles: ['RESIDENT'],
        ),
        status: AuthStatus.authenticated,
      );

      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(authState)),
        ],
        child: const MaterialApp(
          home: TicketCreateScreen(),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render form báo sự cố', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Report Issue'), findsOneWidget);
      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);

      final submitBtn = find.text('SUBMIT TICKET');
      expect(submitBtn, findsOneWidget);
    });

    testWidgets('2. Validation Tests: Chặn submit khi thiếu danh mục hoặc mô tả (AT1)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Submit with empty description (category is pre-selected)
      final submitBtn = find.text('SUBMIT TICKET');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Expect inline error for missing description
      expect(find.text('Please enter an issue description.'), findsOneWidget);

      // Enter short description (< 10 chars)
      final descField = find.byType(TextFormField);
      await tester.enterText(descField, 'Ngan');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Expect inline error for short description
      expect(find.text('Description must be at least 10 characters.'), findsOneWidget);
    });

    testWidgets('3. Success Flow: Gửi báo cáo sự cố thành công (POS-01)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: {'status': 'success', 'data': {'id': 1}},
          statusCode: 201,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: {'data': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Select category 'Nước'
      await tester.tap(find.text('Water'));
      await tester.pumpAndSettle();

      // Enter valid description
      final descField = find.byType(TextFormField);
      await tester.enterText(descField, 'Vòi nước rửa chén bị rò rỉ chảy liên tục.');
      await tester.pumpAndSettle();

      // Submit form
      final submitBtn = find.text('SUBMIT TICKET');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      verify(() => mockDio.post(any(), data: any(named: 'data'))).called(1);
    });
  });
}
