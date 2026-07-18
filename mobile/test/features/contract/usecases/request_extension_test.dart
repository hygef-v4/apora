import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/contract/models/contract.dart';
import 'package:apartment_management/features/contract/screens/request_extension_screen.dart';
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

  group('UC07: Request Stay Extension - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    late MyContract mockContract;

    setUp(() {
      mockDio = MockDio();
      mockContract = MyContract(
        apartment: ApartmentSummary(
          id: 101,
          unitNumber: 'P.502',
          floor: 'Tầng 5',
          status: 'OCCUPIED',
        ),
        contract: ContractInfo(
          id: 1,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          baseRent: 5000000,
          status: 'ACTIVE',
          remainingDays: 166,
        ),
      );
    });

    Widget createWidget({required MockDio dio}) {
      final authState = AuthState(
        user: User(
          id: 1,
          fullName: 'Nguyen Van A',
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
        child: MaterialApp(
          home: RequestExtensionScreen(myContract: mockContract),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render form gửi yêu cầu gia hạn', (tester) async {
      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Yêu Cầu Gia Hạn'), findsOneWidget);
      expect(find.text('31/12/2026'), findsOneWidget);
      
      await tester.scrollUntilVisible(find.text('GỬI YÊU CẦU'), 100, scrollable: find.byType(Scrollable).first);
      expect(find.text('GỬI YÊU CẦU'), findsOneWidget);
    });

    testWidgets('2. Validation Tests: Chặn submit khi chưa nhập lý do hợp lệ (BR-15 & AT2)', (tester) async {
      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Enter short reason (< 10 chars)
      final reasonField = find.byType(TextFormField);
      await tester.ensureVisible(reasonField);
      await tester.enterText(reasonField, 'Ngắn');
      
      final submitBtn = find.text('GỬI YÊU CẦU');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify inline error for reason
      expect(find.text('(!) Lý do phải có ít nhất 10 ký tự.'), findsOneWidget);
    });

    testWidgets('3. Success Flow: Gửi yêu cầu gia hạn thành công (POS-01)', (tester) async {
      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: {'status': 'success', 'data': {}},
          statusCode: 201,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      // Mock refetch in MyContractNotifier
      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: {
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
                'pendingExtensionId': 10,
              }
            }
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Enter valid reason (>= 10 chars)
      final reasonField = find.byType(TextFormField);
      await tester.ensureVisible(reasonField);
      await tester.enterText(reasonField, 'Tôi muốn gia hạn thêm hợp đồng 6 tháng nữa.');

      // Tap to pick date button
      final calendarBtn = find.byIcon(Icons.calendar_month);
      await tester.ensureVisible(calendarBtn);
      await tester.tap(calendarBtn);
      await tester.pumpAndSettle();

      // Select OK in date picker dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Submit form
      final submitBtn = find.text('GỬI YÊU CẦU');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      verify(() => mockDio.post(any(), data: any(named: 'data'))).called(1);
    });
  });
}
