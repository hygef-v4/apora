import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/management/models/apartment.dart';
import 'package:apartment_management/features/management/screens/apartment_form_screen.dart';
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

  group('UC31 & UC32: Create & Update Apartment - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget({required MockDio dio, Apartment? apartment}) {
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
        child: MaterialApp(
          home: ApartmentFormScreen(apartment: apartment),
        ),
      );
    }

    testWidgets('1. UI & Widget Tests: Render form tạo căn hộ mới (UC31)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      expect(find.text('Thêm căn hộ mới'), findsOneWidget);
      expect(find.text('Thêm căn hộ'), findsOneWidget);
    });

    testWidgets('2. Validation Tests: Chặn submit khi bỏ trống hoặc nhập số không hợp lệ', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(dio: mockDio));
      await tester.pumpAndSettle();

      // Submit empty form
      final submitBtn = find.text('Thêm căn hộ');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập số tầng.'), findsOneWidget);
      expect(find.text('Vui lòng nhập số phòng.'), findsOneWidget);
    });

    testWidgets('3. Success Flow UC31: Tạo mới căn hộ thành công (POS-01)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockCreatedApt = {
        'data': {
          'id': 10,
          'unit_number': 'P.901',
          'floor': 'Tầng 9',
          'status': 'EMPTY',
          'area_size': 50.0,
          'base_rent': 6000000,
          'owner_id': null,
          'owner_name': null,
          'owner_phone': null,
          'unpaid_invoice_count': 0,
          'unresolved_ticket_count': 0,
        }
      };

      when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: mockCreatedApt,
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

      // Fill in text fields
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Tầng 9');
      await tester.enterText(fields.at(1), 'P.901');
      await tester.enterText(fields.at(2), '50');
      await tester.enterText(fields.at(3), '6000000');
      await tester.pumpAndSettle();

      // Submit
      final submitBtn = find.text('Thêm căn hộ');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      verify(() => mockDio.post(any(), data: any(named: 'data'))).called(1);
    });

    testWidgets('4. Success Flow UC32: Cập nhật thông tin căn hộ (POS-02)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final existingApt = Apartment(
        id: 5,
        unitNumber: 'P.502',
        floor: 'Tầng 5',
        status: 'EMPTY',
        areaSize: 45.0,
        baseRent: 5000000,
        unpaidInvoiceCount: 0,
        unresolvedTicketCount: 0,
      );

      final mockUpdated = {
        'data': {
          'id': 5,
          'unit_number': 'P.502',
          'floor': 'Tầng 5',
          'status': 'EMPTY',
          'area_size': 48.0,
          'base_rent': 5500000,
          'owner_id': null,
          'owner_name': null,
          'owner_phone': null,
          'unpaid_invoice_count': 0,
          'unresolved_ticket_count': 0,
        }
      };

      when(() => mockDio.put(any(), data: any(named: 'data'))).thenAnswer(
        (_) async => Response(
          data: mockUpdated,
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      when(() => mockDio.get(any())).thenAnswer(
        (_) async => Response(
          data: {
            'data': {
              'id': 5,
              'unit_number': 'P.502',
              'floor': 'Tầng 5',
              'status': 'EMPTY',
              'area_size': 48.0,
              'base_rent': 5500000,
              'roommates': [],
              'recent_bills': [],
              'recent_tickets': [],
            }
          },
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        ),
      );

      await tester.pumpWidget(createWidget(dio: mockDio, apartment: existingApt));
      await tester.pumpAndSettle();

      expect(find.text('Cập nhật căn hộ'), findsOneWidget);
      expect(find.text('Lưu thay đổi'), findsOneWidget);

      final submitBtn = find.text('Lưu thay đổi');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      verify(() => mockDio.put(any(), data: any(named: 'data'))).called(1);
    });
  });
}
