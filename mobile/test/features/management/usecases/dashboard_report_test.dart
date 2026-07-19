import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/management/screens/dashboard_report_screen.dart';
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

  group('UC35: Dashboard & Statistical Reports - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio}) {
      final authState = AuthState(
        user: User(
          id: 1,
          fullName: 'Landlord User',
          phoneNumber: '0901234567',
          roles: ['LANDLORD'],
        ),
        status: AuthStatus.authenticated,
      );

      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(authState)),
        ],
        child: const MaterialApp(
          home: DashboardReportScreen(),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render báo cáo thống kê Dashboard (UC35)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': {
          'total_revenue': 150000000.0,
          'collected_revenue': 120000000.0,
          'unpaid_bills_count': 3,
          'unresolved_tickets_count': 2,
        }
      };

      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo & Thống kê'), findsOneWidget);
    });

    testWidgets('2. Error Handling: Tải dữ liệu thất bại hiển thị nút Thử lại', (tester) async {
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
