import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
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

    testWidgets('1. UI & Widget Tests: Render danh sách hợp đồng và filter chip (BR-16)', (tester) async {
      // Dùng ngày tương đối theo hiện tại để trạng thái ảo (Hiệu lực/Sắp HH) ổn định:
      // - P.502: còn 200 ngày -> "Hiệu lực" (ACTIVE)
      // - P.301: còn 15 ngày  -> "Sắp HH" (EXPIRING)
      final now = DateTime.now();
      final activeEnd = now.add(const Duration(days: 200));
      final expiringEnd = now.add(const Duration(days: 15));

      final mockData = {
        'data': [
          {
            'id': 1,
            'contractId': 10,
            'unitNumber': 'P.502',
            'floor': 'Tầng 5',
            'residentName': 'Nguyen Van A',
            'currentEndDate': activeEnd.toIso8601String(),
            'requestedEndDate': activeEnd.add(const Duration(days: 180)).toIso8601String(),
            'reason': 'Gia hạn hợp đồng công việc',
            'status': 'PENDING',
            'createdAt': now.toIso8601String(),
          },
          {
            'id': 2,
            'contractId': 11,
            'unitNumber': 'P.301',
            'floor': 'Tầng 3',
            'residentName': 'Tran Van B',
            'currentEndDate': expiringEnd.toIso8601String(),
            'requestedEndDate': expiringEnd.add(const Duration(days: 180)).toIso8601String(),
            'reason': 'Gia hạn dài hạn',
            'status': 'APPROVED',
            'createdAt': now.toIso8601String(),
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
      expect(find.text('Extension Requests'), findsOneWidget);
      expect(find.text('Nguyen Van A'), findsOneWidget);
      expect(find.text('Tran Van B'), findsOneWidget);

      // Lọc tab "Pending" -> chỉ còn đơn đang chờ duyệt (Nguyen Van A)
      final activeFilterChip = find.text('Pending');
      await tester.tap(activeFilterChip);
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

      expect(find.text('No extension requests found.'), findsOneWidget);
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

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
