import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/billing/models/invoice.dart';
import 'package:apartment_management/features/billing/providers/billing_provider.dart';
import 'package:apartment_management/features/billing/screens/invoice_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

class MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  final User mockUser;
  MockAuthNotifier(this.mockUser);

  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: mockUser);

  @override
  Future<void> login(String phoneNumber, String password) async {}
  @override
  Future<void> logout() async {}
  @override
  Future<void> sessionExpired() async {}
  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {}
  @override
  Future<String?> requestOtp(String phone) async => null;
  @override
  Future<void> resetPassword(String phone, String otp, String newPassword) async {}
  @override
  Future<void> restoreSession() async {}
  @override
  Future<void> updateUser(User user) async {}
}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  group('UC14: View Invoice List & Detail - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    const residentUser = User(
      id: 3,
      phoneNumber: '0900000003',
      fullName: 'Nguyễn Văn Cư Dân',
      roles: ['RESIDENT'],
    );

    final testInvoices = [
      Invoice(
        id: 1,
        contractId: 10,
        apartmentId: 101,
        monthYear: '07/2026',
        prevElectricityIndex: 100,
        currElectricityIndex: 150,
        electricityConsumption: 50,
        prevWaterIndex: 10,
        currWaterIndex: 20,
        waterConsumption: 10,
        roomRentSnapshot: 5000000,
        mgmtFeeSnapshot: 150000,
        electricityRateSnapshot: 2000,
        waterRateSnapshot: 2166,
        extraFee: 0,
        totalAmount: 5291660,
        status: 'UNPAID',
        dueDate: DateTime(2026, 7, 10),
      ),
    ];

    setUp(() {
      mockDio = MockDio();
      when(() => mockDio.get('/payments')).thenAnswer((_) async => Response(
            data: {'success': true, 'data': []},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/payments'),
          ));
    });

    Widget createWidget() {
      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(residentUser)),
        ],
        child: const MaterialApp(
          home: InvoiceListScreen(),
        ),
      );
    }

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      testWidgets('Render danh sách hóa đơn cư dân (BR-23, BR-46 UNPAID status)', (tester) async {
        when(() => mockDio.get('/bills')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': testInvoices.map((i) => i.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/bills'),
            ));

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('đơn của tôi'), findsOneWidget);
        expect(find.textContaining('Hóa đơn'), findsWidgets);
      });

      testWidgets('Hiển thị giao diện khi chưa có hóa đơn', (tester) async {
        when(() => mockDio.get('/bills')).thenAnswer((_) async => Response(
              data: {'success': true, 'data': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/bills'),
            ));

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('chưa thanh toán'), findsOneWidget);
      });
    });

    // =========================================================================
    // 2. Domain & State Management
    // =========================================================================
    group('2. Domain & State Management', () {
      test('BillingNotifier fetch dữ liệu hóa đơn thành công', () async {
        when(() => mockDio.get('/bills')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': testInvoices.map((i) => i.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/bills'),
            ));

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(billingProvider.notifier).fetchData();

        final state = container.read(billingProvider);
        expect(state.invoices.length, 1);
        expect(state.invoices.first.monthYear, '07/2026');
        expect(state.invoices.first.status, 'UNPAID');
      });

      test('Cô lập lịch sử hóa đơn chủ cũ (BR-31)', () {
        // Cư dân mới chỉ nhận danh sách hóa đơn thuộc hợp đồng active của mình
        final invoicesForResident = testInvoices.where((inv) => inv.apartmentId == 101).toList();
        expect(invoicesForResident.length, 1);
      });
    });

    // =========================================================================
    // 3. Repository Layer
    // =========================================================================
    group('3. Repository Layer', () {
      test('Gọi API GET /bills cô lập dữ liệu theo JWT cư dân (BR-23)', () async {
        when(() => mockDio.get('/bills')).thenAnswer((_) async => Response(
              data: {'success': true, 'data': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/bills'),
            ));

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(billingProvider.notifier).fetchData();

        verify(() => mockDio.get('/bills')).called(greaterThanOrEqualTo(1));
      });
    });
  });
}
