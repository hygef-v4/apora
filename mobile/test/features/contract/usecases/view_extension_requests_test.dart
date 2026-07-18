import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/contract/providers/contract_provider.dart';
import 'package:apartment_management/features/contract/screens/extension_list_screen.dart';
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

  group('UC08: View Stay Extension Requests - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

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
        child: const MaterialApp(
          home: ExtensionListScreen(),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render danh sách yêu cầu gia hạn và filter chip (BR-16)', (tester) async {
      final mockData = {
        'data': [
          {
            'id': 1,
            'contractId': 10,
            'unitNumber': 'P.502',
            'floor': 'Tầng 5',
            'residentName': 'Nguyen Van A',
            'currentEndDate': '2026-12-31T00:00:00.000Z',
            'requestedEndDate': '2027-06-30T00:00:00.000Z',
            'reason': 'Gia hạn hợp đồng công việc',
            'status': 'PENDING',
            'createdAt': '2026-06-01T10:00:00.000Z',
          },
          {
            'id': 2,
            'contractId': 11,
            'unitNumber': 'P.301',
            'floor': 'Tầng 3',
            'residentName': 'Tran Van B',
            'currentEndDate': '2026-10-31T00:00:00.000Z',
            'requestedEndDate': '2027-04-30T00:00:00.000Z',
            'reason': 'Gia hạn dài hạn',
            'status': 'APPROVED',
            'createdAt': '2026-05-01T10:00:00.000Z',
          }
        ]
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

      // Verify Screen Header
      expect(find.text('Yêu Cầu Gia Hạn'), findsOneWidget);
      expect(find.text('Nguyen Van A'), findsOneWidget);
      expect(find.text('Tran Van B'), findsOneWidget);

      // Filter by PENDING chip
      final pendingFilterChip = find.textContaining('Chờ duyệt (1)');
      await tester.tap(pendingFilterChip);
      await tester.pumpAndSettle();

      expect(find.text('Nguyen Van A'), findsOneWidget);
      expect(find.text('Tran Van B'), findsNothing);
    });

    testWidgets('2. Alternative Flow (AT1): Màn hình hiển thị khi chưa có yêu cầu gia hạn nào', (tester) async {
      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: {'data': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có yêu cầu gia hạn nào.'), findsOneWidget);
    });

    testWidgets('3. Error Handling: Tải danh sách thất bại hiển thị nút Thử lại', (tester) async {
      when(() => mockDio.get(any())).thenThrow(
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
