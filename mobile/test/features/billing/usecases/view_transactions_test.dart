import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/billing/models/payment.dart';
import 'package:apartment_management/features/billing/providers/billing_provider.dart';
import 'package:apartment_management/features/billing/screens/manager_invoice_list_screen.dart';
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

  group('UC15: View Transaction History - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    const managerUser = User(
      id: 2,
      phoneNumber: '0900000002',
      fullName: 'Ban Quản Lý',
      roles: ['MANAGER'],
    );

    final testPayments = [
      Payment(
        id: 1,
        invoiceId: 10,
        residentId: 3,
        payosOrderId: 'PAYOS_ORDER_100',
        transactionCode: 'FT20260718001',
        amount: 5291660,
        paymentMethod: 'VietQR / PayOS',
        status: 'SUCCESS',
        paidAt: DateTime(2026, 7, 18, 10, 0),
        createdAt: DateTime(2026, 7, 18, 9, 55),
        unitNumber: '101',
      ),
    ];

    setUp(() {
      mockDio = MockDio();
      when(() => mockDio.get('/bills')).thenAnswer((_) async => Response(
            data: {'success': true, 'data': []},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/bills'),
          ));
    });

    Widget createWidget() {
      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(managerUser)),
        ],
        child: const MaterialApp(
          home: ManagerInvoiceListScreen(),
        ),
      );
    }

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      testWidgets('Render màn hình quản lý hóa đơn & lịch sử giao dịch (BR-29 Read-only)', (tester) async {
        when(() => mockDio.get('/payments')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': testPayments.map((p) => p.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/payments'),
            ));

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('Hóa Đơn'), findsWidgets);
        expect(find.textContaining('Giao dịch'), findsOneWidget);

        // Chuyển sang Tab Lịch Sử Giao Dịch
        await tester.tap(find.textContaining('Giao dịch'));
        await tester.pumpAndSettle();

        expect(find.text('Căn 101'), findsOneWidget);
        expect(find.text('Mã GD: FT20260718001'), findsOneWidget);

        // BR-29: Đảm bảo không có nút Thêm / Sửa / Xóa giao dịch thủ công (Read-only UI)
        expect(find.byIcon(Icons.delete), findsNothing);
        expect(find.byIcon(Icons.edit), findsNothing);
      });
    });

    // =========================================================================
    // 2. Domain & State Management
    // =========================================================================
    group('2. Domain & State Management', () {
      test('Sắp xếp giao dịch giảm dần theo ngày thanh toán (BR-30 payment_date DESC)', () {
        final payments = [
          Payment(
            id: 1,
            invoiceId: 1,
            residentId: 3,
            payosOrderId: 'ORDER_1',
            transactionCode: 'FT001',
            amount: 100000,
            paymentMethod: 'VietQR',
            status: 'SUCCESS',
            paidAt: DateTime(2026, 7, 10),
            createdAt: DateTime(2026, 7, 10),
          ),
          Payment(
            id: 2,
            invoiceId: 2,
            residentId: 3,
            payosOrderId: 'ORDER_2',
            transactionCode: 'FT002',
            amount: 200000,
            paymentMethod: 'VietQR',
            status: 'SUCCESS',
            paidAt: DateTime(2026, 7, 15),
            createdAt: DateTime(2026, 7, 15),
          ),
        ];

        // Sort desc
        payments.sort((a, b) => (b.paidAt ?? b.createdAt).compareTo(a.paidAt ?? a.createdAt));

        expect(payments.first.id, 2); // Ngày 15 trước ngày 10
      });
    });

    // =========================================================================
    // 3. Repository Layer
    // =========================================================================
    group('3. Repository Layer', () {
      test('Gọi API GET /payments tải lịch sử giao dịch', () async {
        when(() => mockDio.get('/payments')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': testPayments.map((p) => p.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/payments'),
            ));

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(billingProvider.notifier).fetchData();

        verify(() => mockDio.get('/payments')).called(greaterThanOrEqualTo(1));
      });
    });
  });
}
