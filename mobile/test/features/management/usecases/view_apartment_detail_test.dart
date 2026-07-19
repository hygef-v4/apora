import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/management/screens/apartment_detail_screen.dart';
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

  group('UC30: View Apartment Detail - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio, required String role, int apartmentId = 1}) {
      final authState = AuthState(
        user: User(
          id: 1,
          fullName: 'Test User',
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
        child: MaterialApp(
          home: ApartmentDetailScreen(apartmentId: apartmentId),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render chi tiết căn hộ cho LANDLORD (UC30)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockData = {
        'data': {
          'id': 1,
          'unit_number': 'P.502',
          'floor': '5',
          'status': 'OCCUPIED',
          'area_size': 45.0,
          'base_rent': 5000000,
          'owner_id': 10,
          'owner_name': 'Nguyen Van A',
          'owner_phone': '0901234567',
          'roommates': [],
          'recent_bills': [],
          'recent_tickets': [],
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'LANDLORD'));
      await tester.pumpAndSettle();

      expect(find.text('Chi tiết căn hộ'), findsOneWidget);
      expect(find.textContaining('P.502'), findsWidgets);
      expect(find.text('Nguyen Van A'), findsWidgets);
    });

    testWidgets('2. Role Check: Nút chỉnh sửa icon chỉ xuất hiện cho LANDLORD', (tester) async {
      final mockData = {
        'data': {
          'id': 1,
          'unit_number': 'P.502',
          'floor': '5',
          'status': 'OCCUPIED',
          'area_size': 45.0,
          'base_rent': 5000000,
          'owner_id': 10,
          'owner_name': 'Nguyen Van A',
          'owner_phone': '0901234567',
          'roommates': [],
          'recent_bills': [],
          'recent_tickets': [],
        }
      };

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: mockData,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, role: 'MANAGER'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_note), findsNothing);
    });

    testWidgets('3. Error Handling: Tải dữ liệu thất bại hiển thị nút Thử lại', (tester) async {
      when(() => mockDio.get(any())).thenThrow(
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
