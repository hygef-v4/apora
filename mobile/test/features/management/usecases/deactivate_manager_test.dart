import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:apartment_management/features/management/providers/manager_notifier.dart';
import 'package:apartment_management/features/management/repositories/manager_api_service.dart';
import 'package:apartment_management/features/management/models/manager_stats.dart';
import 'package:apartment_management/features/management/models/manager_member.dart';
import 'package:apartment_management/features/management/models/manager_detail.dart';
import 'package:apartment_management/features/management/screens/manager_detail_screen.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';

// --- Mocks ---
class MockManagerAPIService extends Mock implements ManagerAPIService {}
class MockDio extends Mock implements Dio {}

// Mock AuthNotifier to provide different user states
class MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  final int currentUserId;
  MockAuthNotifier(this.currentUserId);

  @override
  AuthState build() {
    return AuthState(
      status: AuthStatus.authenticated,
      user: User(
        id: currentUserId,
        phoneNumber: '0123456789',
        fullName: 'Current User',
        roles: ['LANDLORD'],
      ),
    );
  }

  // Need to implement the other methods even with empty bodies to satisfy implements
  @override
  Future<void> login(String phone, String password) async {}
  @override
  Future<void> logout() async {}
  @override
  void checkAuthStatus() {}
  @override
  void clearError() {}
  @override
  Future<void> updatePassword(String oldPass, String newPass) async {}
  @override
  Future<void> registerResidentToken(String deviceToken) async {}
  @override
  Future<void> changePassword(String oldPassword, String newPassword) async {}
  @override
  Future<String?> requestOtp(String phone) async => null;
  @override
  Future<void> resetPassword(String phone, String otp, String newPassword) async {}
  @override
  Future<void> restoreSession() async {}
  @override
  Future<void> sessionExpired() async {}
  @override
  Future<void> updateUser(User user) async {}
}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  group('UC45: Deactivate / Reactivate Manager Account', () {
    late MockManagerAPIService mockApi;
    final testManagerActive = ManagerDetail(
      member: ManagerMember(
        id: 1,
        fullName: 'Test Manager',
        phoneNumber: '0987654321',
        avatarUrl: null,
        status: 'ACTIVE',
        createdAt: DateTime(2023, 1, 1),
      ),
      managementHistory: [
        ManagementHistoryItem(
          id: 1,
          action: 'Some Action',
          createdAt: DateTime(2023, 1, 2),
        ),
      ],
    );
    final testManagerInactive = ManagerDetail(
      member: ManagerMember(
        id: 2,
        fullName: 'Inactive Manager',
        phoneNumber: '0987654321',
        avatarUrl: null,
        status: 'INACTIVE',
        createdAt: DateTime(2023, 1, 1),
      ),
      managementHistory: [
        ManagementHistoryItem(
          id: 2,
          action: 'Past Action',
          createdAt: DateTime(2023, 1, 2),
        ),
      ],
    );

    setUp(() {
      mockApi = MockManagerAPIService();
      
      // Mock fetch detail
      when(() => mockApi.getManagerDetail(1)).thenAnswer((_) async => testManagerActive);
      when(() => mockApi.getManagerDetail(2)).thenAnswer((_) async => testManagerInactive);
      
      // Mock list refresh
      when(() => mockApi.getManagerList(
        status: any(named: 'status'),
        search: any(named: 'search'),
      )).thenAnswer((_) async => const ManagerListResult(managers: [], stats: ManagerStats.empty));
    });

    group('1. UI & Widget Tests (AT & Specific BRs)', () {
      testWidgets('AT1: Hiển thị Dialog xác nhận và nút Hủy không gọi API', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              managerApiServiceProvider.overrideWithValue(mockApi),
              authNotifierProvider.overrideWith(() => MockAuthNotifier(999)), // Khác ID manager
            ],
            child: const MaterialApp(
              home: ManagerDetailScreen(managerId: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final buttonFinder = find.text('Vô hiệu hóa tài khoản', skipOffstage: false);
        expect(buttonFinder, findsOneWidget);

        await tester.ensureVisible(buttonFinder);
        await tester.pumpAndSettle();
        await tester.tap(buttonFinder);
        await tester.pumpAndSettle(); 

        // Check dialog
        expect(find.text('Vô hiệu hóa tài khoản'), findsWidgets);
        
        // Tap Cancel (Alternative Flow AT1)
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();

        expect(find.text('Vô hiệu hóa tài khoản'), findsOneWidget); // Nút vẫn còn ở đó nhưng dialog đóng
        verifyNever(() => mockApi.updateManagerStatus(id: 1, status: any(named: 'status')));
      });

      testWidgets('BR-58: Tự động ẩn nút Vô hiệu hóa nếu người dùng đang xem profile của chính họ', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              managerApiServiceProvider.overrideWithValue(mockApi),
              // Giả lập currentUser.id = 1 (trùng với managerId đang xem)
              authNotifierProvider.overrideWith(() => MockAuthNotifier(1)), 
            ],
            child: const MaterialApp(
              home: ManagerDetailScreen(managerId: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nút Vô hiệu hóa tài khoản phải BỊ ẨN theo BR-58
        final buttonFinder = find.text('Vô hiệu hóa tài khoản', skipOffstage: false);
        expect(buttonFinder, findsNothing);
      });

      testWidgets('BR-59: Tài khoản Inactive vẫn hiển thị nguyên vẹn Lịch sử thao tác', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              managerApiServiceProvider.overrideWithValue(mockApi),
              authNotifierProvider.overrideWith(() => MockAuthNotifier(999)),
            ],
            child: const MaterialApp(
              home: ManagerDetailScreen(managerId: 2), // Tài khoản đang Inactive
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Dù tài khoản bị vô hiệu hóa, thông tin lịch sử không được xóa (Hard deletion is prohibited)
        // Lịch sử quản lý phải được hiển thị.
        expect(find.text('Lịch sử quản lý', skipOffstage: false), findsOneWidget);
        expect(find.text('Past Action', skipOffstage: false), findsOneWidget); // Kiểm tra item lịch sử đã render
      });
    });

    group('2. Domain & State Management', () {
      test('BR-04: Gửi yêu cầu vô hiệu hóa để Backend ngăn chặn đăng nhập (Only ACTIVE accounts can log in)', () async {
        final container = ProviderContainer(
          overrides: [
            managerApiServiceProvider.overrideWithValue(mockApi),
          ],
        );
        
        when(() => mockApi.updateManagerStatus(
              id: 1,
              status: 'INACTIVE',
            )).thenAnswer((_) async => {});

        final notifier = container.read(managerDetailProvider.notifier);
        await notifier.fetch(1);
        await notifier.toggleManagerStatus();

        // Kiểm tra gọi API update status = INACTIVE (Đây là hành động để trigger Backend thực hiện BR-04)
        verify(() => mockApi.updateManagerStatus(
              id: 1,
              status: 'INACTIVE',
            )).called(1);
      });

      test('BR-05: Thu hồi phiên đăng nhập JWT của tài khoản bị vô hiệu hóa (Backend triggers)', () async {
        final container = ProviderContainer(
          overrides: [
            managerApiServiceProvider.overrideWithValue(mockApi),
          ],
        );
        
        when(() => mockApi.updateManagerStatus(
              id: 1,
              status: 'INACTIVE',
            )).thenAnswer((_) async => {});

        final notifier = container.read(managerDetailProvider.notifier);
        await notifier.fetch(1);
        
        // Reset the mock to clear previous call counts
        clearInteractions(mockApi);
        when(() => mockApi.updateManagerStatus(id: 1, status: 'INACTIVE')).thenAnswer((_) async => {});

        await notifier.toggleManagerStatus();

        // Kiểm tra việc gọi API thành công để đảm bảo backend nhận lệnh vô hiệu hóa và thu hồi session
        verify(() => mockApi.updateManagerStatus(
              id: 1,
              status: 'INACTIVE',
            )).called(1);
      });

      test('BR-11: Ghi nhận Audit Log cho hành động quản trị (Backend triggers)', () async {
        final container = ProviderContainer(
          overrides: [
            managerApiServiceProvider.overrideWithValue(mockApi),
          ],
        );
        
        when(() => mockApi.updateManagerStatus(
              id: 1,
              status: 'INACTIVE',
            )).thenAnswer((_) async => {});

        final notifier = container.read(managerDetailProvider.notifier);
        await notifier.fetch(1);
        
        clearInteractions(mockApi);
        when(() => mockApi.updateManagerStatus(id: 1, status: 'INACTIVE')).thenAnswer((_) async => {});

        await notifier.toggleManagerStatus();

        // Hành động gửi API thay đổi status sẽ sinh ra Audit Log tại Backend theo yêu cầu BR-11
        verify(() => mockApi.updateManagerStatus(
              id: 1,
              status: 'INACTIVE',
            )).called(1);
      });
    });

    group('3. API Repository Layer', () {
      late MockDio mockDio;
      late ManagerAPIService apiService;

      setUp(() {
        mockDio = MockDio();
        apiService = ManagerAPIService(mockDio);
      });

      test('updateManagerStatus() calls PATCH /managers/:id/status with correct payload', () async {
        when(() => mockDio.patch(
              '/managers/1/status',
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/managers/1/status'),
            statusCode: 200,
            data: {'success': true},
          ),
        );

        await apiService.updateManagerStatus(
          id: 1,
          status: 'INACTIVE',
        );

        verify(() => mockDio.patch(
              '/managers/1/status',
              data: {
                'status': 'INACTIVE',
              },
            )).called(1);
      });
    });
  });
}
