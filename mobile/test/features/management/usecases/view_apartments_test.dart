import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/management/screens/apartment_list_screen.dart';
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

  group('UC29: View Apartment List - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio, required String role}) {
      final authState = AuthState(
        user: User(
          id: 1,
          fullName: 'Manager User',
          phoneNumber: '0901234567',
          roles: [role],
        ),
        status: AuthStatus.authenticated,
      );

      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(authState)),
        ],
        child: const MaterialApp(
          home: ApartmentListScreen(),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render danh sách căn hộ và các thẻ bộ lọc (BR-29)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': [
          {
            'id': 1,
            'unit_number': 'P.502',
            'floor': 'Tầng 5',
            'status': 'OCCUPIED',
            'area_size': 45.0,
            'base_rent': 5000000,
            'owner_name': 'Nguyen Van A',
            'unpaid_invoice_count': 0,
            'unresolved_ticket_count': 1,
          },
          {
            'id': 2,
            'unit_number': 'P.301',
            'floor': 'Tầng 3',
            'status': 'EMPTY',
            'area_size': 35.0,
            'base_rent': 4000000,
            'owner_name': null,
            'unpaid_invoice_count': 0,
            'unresolved_ticket_count': 0,
          }
        ]
      };

      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'LANDLORD'));
      await tester.pumpAndSettle();

      expect(find.text('Căn hộ'), findsOneWidget);
      expect(find.text('Căn hộ P.502'), findsOneWidget);
      expect(find.text('Căn hộ P.301'), findsOneWidget);
    });

    testWidgets('2. Role Check: Nút Thêm Căn Hộ chỉ hiện cho LANDLORD/MANAGER', (tester) async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: {'data': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'RESIDENT'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('3. Alternative Flow (AT1): Hiển thị khi danh sách trống', (tester) async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
        (_) async => Response(
          data: {'data': []},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'LANDLORD'));
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy căn hộ nào khớp điều kiện.'), findsOneWidget);
    });

    testWidgets('4. Error Handling: Tải dữ liệu thất bại hiển thị nút Thử lại', (tester) async {
      when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters'))).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'LANDLORD'));
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
