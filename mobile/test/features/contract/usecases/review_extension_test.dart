import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/contract/providers/contract_provider.dart';
import 'package:apartment_management/features/contract/screens/extension_review_screen.dart';
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

  group('UC09: Review Stay Extension Request - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio, int extensionId = 1}) {
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
          home: ExtensionReviewScreen(extensionId: extensionId),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render chi tiết yêu cầu gia hạn (BR-16)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': {
          'id': 1,
          'contractId': 10,
          'unitNumber': 'P.502',
          'floor': 'Tầng 5',
          'residentName': 'Nguyen Van A',
          'residentPhone': '0901234567',
          'contractStartDate': '2026-01-01T00:00:00.000Z',
          'contractEndDate': '2026-12-31T00:00:00.000Z',
          'contractStatus': 'ACTIVE',
          'currentEndDate': '2026-12-31T00:00:00.000Z',
          'requestedEndDate': '2027-06-30T00:00:00.000Z',
          'reason': 'Lý do xin gia hạn',
          'status': 'PENDING',
          'createdAt': '2026-06-01T10:00:00.000Z',
          'reviewedAt': null,
          'baseRent': 5000000,
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

      expect(find.text('Duyệt Yêu Cầu Gia Hạn'), findsOneWidget);
      expect(find.text('Nguyen Van A'), findsOneWidget);
      expect(find.text('Lý do xin gia hạn'), findsOneWidget);

      final approveBtn = find.text('DUYỆT');
      expect(approveBtn, findsOneWidget);
      expect(find.text('TỪ CHỐI'), findsOneWidget);
    });

    testWidgets('2. Validation Tests: Từ chối yêu cầu bắt buộc phải nhập lý do (AT2)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': {
          'id': 1,
          'contractId': 10,
          'unitNumber': 'P.502',
          'floor': 'Tầng 5',
          'residentName': 'Nguyen Van A',
          'residentPhone': '0901234567',
          'contractStartDate': '2026-01-01T00:00:00.000Z',
          'contractEndDate': '2026-12-31T00:00:00.000Z',
          'contractStatus': 'ACTIVE',
          'currentEndDate': '2026-12-31T00:00:00.000Z',
          'requestedEndDate': '2027-06-30T00:00:00.000Z',
          'reason': 'Lý do xin gia hạn',
          'status': 'PENDING',
          'createdAt': '2026-06-01T10:00:00.000Z',
          'reviewedAt': null,
          'baseRent': 5000000,
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

      // Tap TỪ CHỐI without entering reason
      final rejectBtn = find.text('TỪ CHỐI');
      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      // Confirm dialog should NOT appear, reject error message shown
      expect(find.text('(!) Cần nhập lý do từ chối.'), findsOneWidget);
    });

    testWidgets('3. Success Flow: Duyệt gia hạn thành công (BR-17 & POS-01)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': {
          'id': 1,
          'contractId': 10,
          'unitNumber': 'P.502',
          'floor': 'Tầng 5',
          'residentName': 'Nguyen Van A',
          'residentPhone': '0901234567',
          'contractStartDate': '2026-01-01T00:00:00.000Z',
          'contractEndDate': '2026-12-31T00:00:00.000Z',
          'contractStatus': 'ACTIVE',
          'currentEndDate': '2026-12-31T00:00:00.000Z',
          'requestedEndDate': '2027-06-30T00:00:00.000Z',
          'reason': 'Lý do xin gia hạn',
          'status': 'PENDING',
          'createdAt': '2026-06-01T10:00:00.000Z',
          'reviewedAt': null,
          'baseRent': 5000000,
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
          data: {'status': 'success', 'data': {}},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Tap DUYỆT button
      final approveBtn = find.text('DUYỆT');
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.text('Duyệt yêu cầu?'), findsOneWidget);
      await tester.tap(find.text('Duyệt'));
      await tester.pumpAndSettle();

      verify(() => mockDio.put(any(), data: any(named: 'data'))).called(1);
    });
  });
}
