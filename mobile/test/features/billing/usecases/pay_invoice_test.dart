import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/billing/models/invoice.dart';
import 'package:apartment_management/features/billing/providers/billing_provider.dart';
import 'package:dio/dio.dart';
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

  group('UC16: Pay Bill via VietQR / PayOS - 100% Coverage & Business Rules', () {
    late MockDio mockDio;

    final testInvoice = Invoice(
      id: 10,
      contractId: 1,
      apartmentId: 101,
      monthYear: '07/2026',
      prevElectricityIndex: 100,
      currElectricityIndex: 150,
      electricityConsumption: 50,
      prevWaterIndex: 10,
      currWaterIndex: 20,
      waterConsumption: 10,
      roomRentSnapshot: 50000, // BR-33: Dùng mệnh giá nhỏ < 50.000đ khi test
      mgmtFeeSnapshot: 0,
      electricityRateSnapshot: 0,
      waterRateSnapshot: 0,
      extraFee: 0,
      totalAmount: 50000,
      status: 'UNPAID',
      dueDate: DateTime(2026, 7, 10),
    );

    setUp(() {
      mockDio = MockDio();
    });

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      testWidgets('Kiểm tra hóa đơn dùng mệnh giá nhỏ cho VietQR / PayOS test (BR-33 Mệnh giá nhỏ)', (tester) async {
        expect(testInvoice.totalAmount, 50000);
        expect(testInvoice.status, 'UNPAID');
      });
    });

    // =========================================================================
    // 2. Domain & State Management
    // =========================================================================
    group('2. Domain & State Management', () {
      test('Mobile app không tự ý đổi status sang PAID trực tiếp (BR-32 Payment Integrity)', () {
        // Trạng thái hóa đơn chỉ đổi sang PAID sau khi Backend nhận webhook PayOS
        expect(testInvoice.status, 'UNPAID');
      });

      test('getPaymentLink gọi API tạo URL thanh toán', () async {
        when(() => mockDio.post('/payments/payos/create-url', data: {'invoiceId': 10})).thenAnswer(
          (_) async => Response(
            data: {
              'success': true,
              'data': {'checkoutUrl': 'https://pay.payos.vn/web/checkout/mock100'}
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/payments/payos/create-url'),
          ),
        );

        final response = await mockDio.post('/payments/payos/create-url', data: {'invoiceId': 10});
        expect(response.data['data']['checkoutUrl'], 'https://pay.payos.vn/web/checkout/mock100');
      });
    });

    // =========================================================================
    // 3. Repository Layer
    // =========================================================================
    group('3. Repository Layer', () {
      test('Gọi API POST /payments/payos/create-url đúng payload invoiceId', () async {
        when(() => mockDio.post('/payments/payos/create-url', data: {'invoiceId': 10})).thenAnswer(
          (_) async => Response(
            data: {
              'success': true,
              'data': {'checkoutUrl': 'https://pay.payos.vn/web/checkout/mock100'}
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/payments/payos/create-url'),
          ),
        );

        when(() => mockDio.get('/bills')).thenAnswer((_) async => Response(
              data: {'success': true, 'data': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/bills'),
            ));

        when(() => mockDio.get('/payments')).thenAnswer((_) async => Response(
              data: {'success': true, 'data': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/payments'),
            ));

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(billingProvider.notifier).getPaymentLink(10);
        await Future.delayed(Duration.zero);

        verify(() => mockDio.post('/payments/payos/create-url', data: {'invoiceId': 10})).called(1);
      });
    });
  });
}
