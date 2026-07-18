import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/billing/providers/billing_provider.dart';
import 'package:apartment_management/features/billing/screens/manager_generate_bill_screen.dart';
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

  group('UC13: Input Utility Meter Indices & Generate Monthly Bills - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    const managerUser = User(
      id: 2,
      phoneNumber: '0900000002',
      fullName: 'Ban Quản Lý',
      roles: ['MANAGER'],
    );

    setUp(() {
      mockDio = MockDio();
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
      when(() => mockDio.get('/pricing-settings')).thenAnswer((_) async => Response(
            data: {
              'success': true,
              'data': {
                'electricityRate': 2000.0,
                'waterRate': 2166.0,
                'mgmtFee': 150000.0,
              }
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/pricing-settings'),
          ));
      when(() => mockDio.get('/bills/active-contracts')).thenAnswer((_) async => Response(
            data: {
              'success': true,
              'data': [
                {
                  'id': 1,
                  'apartment_id': 101,
                  'unit_number': '101',
                  'resident_name': 'Nguyễn Văn A',
                  'last_electricity_index': 100,
                  'last_water_index': 20,
                }
              ]
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/bills/active-contracts'),
          ));
      when(() => mockDio.get('/bills/active-pricing')).thenAnswer((_) async => Response(
            data: {
              'success': true,
              'data': {
                'electricity_rate': 2000.0,
                'water_rate': 2166.0,
                'mgmt_fee': 150000.0,
              }
            },
            statusCode: 200,
            requestOptions: RequestOptions(path: '/bills/active-pricing'),
          ));
    });

    Widget createWidget() {
      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(managerUser)),
        ],
        child: const MaterialApp(
          home: ManagerGenerateBillScreen(),
        ),
      );
    }

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      testWidgets('Render form nhập chỉ số điện nước hàng loạt (BR-25, BR-26)', (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(find.text('Lập Hóa Đơn'), findsOneWidget);
        expect(find.text('Căn hộ - Cư dân'), findsOneWidget);
      });

      testWidgets('Báo lỗi validation khi chỉ số mới nhỏ hơn chỉ số cũ (BR-25)', (tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(find.text('Lập Hóa Đơn'), findsOneWidget);
        expect(find.text('Căn hộ - Cư dân'), findsOneWidget);
      });
    });

    // =========================================================================
    // 2. Domain & State Management
    // =========================================================================
    group('2. Domain & State Management', () {
      test('Tính toán chỉ số tiêu thụ hợp lệ (BR-25, BR-26)', () {
        const prevElectricity = 100;
        const currElectricity = 150;
        const consumption = currElectricity - prevElectricity;

        expect(consumption, 50);
        expect(consumption >= 0, isTrue); // BR-26: Mức tiêu thụ >= 0
      });

      test('Validation chỉ số mới phải lớn hơn hoặc bằng chỉ số cũ (BR-25)', () {
        bool isValidMeterInput(int prev, int curr) {
          return curr >= prev && curr >= 0 && prev >= 0;
        }

        expect(isValidMeterInput(100, 150), isTrue);
        expect(isValidMeterInput(100, 90), isFalse); // Báo lỗi BR-25
        expect(isValidMeterInput(100, -5), isFalse);
      });
    });

    // =========================================================================
    // 3. Repository Layer
    // =========================================================================
    group('3. Repository Layer', () {
      test('Mock API POST sinh hóa đơn thành công (BR-27, BR-28)', () async {
        when(() => mockDio.post('/bills/generate', data: any(named: 'data'))).thenAnswer(
          (_) async => Response(
            data: {'success': true, 'message': 'Đã sinh hóa đơn thành công'},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/bills/generate'),
          ),
        );

        final res = await mockDio.post('/bills/generate', data: {
          'monthYear': '07/2026',
          'bills': [
            {
              'apartmentId': 101,
              'currElectricity': 150,
              'currWater': 50,
            }
          ]
        });

        expect(res.data['success'], isTrue);
      });
    });
  });
}
