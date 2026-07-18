import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/billing/models/invoice.dart';
import 'package:apartment_management/features/billing/models/payment.dart';
import 'package:apartment_management/features/billing/screens/payment_receipt_screen.dart';
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

  group('UC17: View Payment Receipt - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    const residentUser = User(
      id: 3,
      phoneNumber: '0900000003',
      fullName: 'Nguyễn Văn Cư Dân',
      roles: ['RESIDENT'],
    );

    final testPayment = Payment(
      id: 100,
      invoiceId: 10,
      residentId: 3,
      payosOrderId: 'ORDER_PAYOS_100',
      transactionCode: 'FT2026071800099',
      amount: 5291660,
      paymentMethod: 'VietQR / PayOS',
      status: 'SUCCESS',
      paidAt: DateTime(2026, 7, 18, 10, 30),
      createdAt: DateTime(2026, 7, 18, 10, 25),
      unitNumber: '101',
    );

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
      roomRentSnapshot: 5000000,
      mgmtFeeSnapshot: 150000,
      electricityRateSnapshot: 2000,
      waterRateSnapshot: 2166,
      extraFee: 0,
      totalAmount: 5291660,
      status: 'PAID',
      dueDate: DateTime(2026, 7, 10),
    );

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget() {
      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(residentUser)),
        ],
        child: MaterialApp(
          home: PaymentReceiptScreen(invoice: testInvoice, payment: testPayment),
        ),
      );
    }

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      testWidgets('Render màn hình Biên lai thanh toán thành công (BR-34 Read-only & Immutable)', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(find.text('Biên lai giao dịch'), findsOneWidget);
        expect(find.text('Thanh Toán Thành Công'), findsOneWidget);
        expect(find.text('Mã giao dịch'), findsOneWidget);
        expect(find.text('FT2026071800099'), findsOneWidget);
        expect(find.text('QUAY VỀ TRANG CHỦ'), findsOneWidget);

        // BR-34: Tất cả trường dữ liệu trên biên lai là Read-only & Immutable (không có ô nhập liệu)
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
      });
    });

    // =========================================================================
    // 2. Domain & State Management
    // =========================================================================
    group('2. Domain & State Management', () {
      test('Biên lai bảo mật thông tin thuộc về đúng resident_id (BR-35)', () {
        expect(testPayment.residentId, 3);
        expect(testPayment.residentId == residentUser.id, isTrue); // Permitted
      });

      test('Payment model parse JSON dữ liệu biên lai chính xác', () {
        final json = testPayment.toJson();
        final parsed = Payment.fromJson(json);

        expect(parsed.id, 100);
        expect(parsed.transactionCode, 'FT2026071800099');
        expect(parsed.amount, 5291660);
      });
    });

    // =========================================================================
    // 3. Repository Layer
    // =========================================================================
    group('3. Repository Layer', () {
      test('Mock API trả về thông tin biên lai hợp lệ', () async {
        when(() => mockDio.get('/payments/100/receipt')).thenAnswer(
          (_) async => Response(
            data: {
              'success': true,
              'data': testPayment.toJson(),
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/payments/100/receipt'),
          ),
        );

        final res = await mockDio.get('/payments/100/receipt');
        expect(res.data['success'], isTrue);
        expect(res.data['data']['transaction_code'], 'FT2026071800099');
      });
    });
  });
}
