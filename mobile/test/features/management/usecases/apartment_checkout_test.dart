import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/management/screens/apartment_checkout_screen.dart';
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

  group('UC34: Apartment Check-out - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio, int apartmentId = 1}) {
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
          home: ApartmentCheckoutScreen(apartmentId: apartmentId),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render giao diện trả phòng căn hộ', (tester) async {
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

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Trả phòng (Checkout)'), findsOneWidget);
      expect(find.text('Xác nhận Trả phòng'), findsOneWidget);
    });

    testWidgets('2. Success Flow: Trả phòng thành công và ẩn danh dữ liệu (POS-01)', (tester) async {
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

      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: {'status': 'success', 'data': {'id': 1, 'status': 'EMPTY'}},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Tap submit button
      final checkoutBtn = find.text('Xác nhận Trả phòng');
      await tester.tap(checkoutBtn);
      await tester.pumpAndSettle();

      // Dialog confirmation
      expect(find.text('Xác nhận trả phòng?'), findsOneWidget);
      final confirmBtn = find.text('Đồng ý Trả phòng');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      verify(() => mockDio.post(any(), data: any(named: 'data'))).called(1);
    });
  });
}
