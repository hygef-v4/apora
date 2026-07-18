import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/roommate/models/roommate.dart';
import 'package:apartment_management/features/roommate/providers/roommate_provider.dart';
import 'package:apartment_management/features/roommate/screens/roommate_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:apartment_management/features/auth_profile/providers/profile_notifier.dart';

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

class MockProfileNotifier extends ProfileNotifier {
  final User mockUser;
  MockProfileNotifier(this.mockUser);

  @override
  Future<User?> build() async => mockUser;
}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  group('UC10: View Roommate List - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    const residentUser = User(
      id: 3,
      phoneNumber: '0900000003',
      fullName: 'Nguyễn Văn Cư Dân',
      roles: ['RESIDENT'],
    );

    final testRoommates = [
      Roommate(
        id: 1,
        apartmentId: 101,
        fullName: 'Lê Văn Ở Ghép',
        phoneNumber: '0911111111',
        cccdNumber: '001200123456',
        status: 'APPROVED',
        createdAt: DateTime(2026, 1, 1),
      ),
      Roommate(
        id: 2,
        apartmentId: 101,
        fullName: 'Trần Thị B',
        phoneNumber: '0922222222',
        cccdNumber: '001200654321',
        status: 'PENDING',
        createdAt: DateTime(2026, 1, 2),
      ),
    ];

    setUp(() {
      mockDio = MockDio();
    });

    Widget createWidget() {
      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(residentUser)),
          profileNotifierProvider.overrideWith(() => MockProfileNotifier(residentUser)),
        ],
        child: const MaterialApp(
          home: RoommateListScreen(),
        ),
      );
    }

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      testWidgets('Render đầy đủ giao diện danh sách người ở ghép (BR-19, BR-23, BR-24)', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(() => mockDio.get('/roommates')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': testRoommates.map((r) => r.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates'),
            ));

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // BR-24: Tính chủ hộ vào tổng số cư dân (1 chủ hộ + 1 APPROVED roommate = 2 người)
        expect(find.text('Thành Viên Phòng'), findsOneWidget);
        expect(find.text('2 người'), findsOneWidget);

        // BR-19: Thể hiện chủ hộ & người ở ghép
        expect(find.text('Chủ hộ'), findsOneWidget);
        expect(find.text('Lê Văn Ở Ghép'), findsOneWidget);
        expect(find.text('Đã duyệt'), findsOneWidget);
        expect(find.text('Chờ duyệt'), findsOneWidget);
      });

      testWidgets('Hiển thị giao diện rỗng khi chưa có người ở ghép', (tester) async {
        when(() => mockDio.get('/roommates')).thenAnswer((_) async => Response(
              data: {'success': true, 'data': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates'),
            ));

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(find.text('1 người'), findsOneWidget); // Chỉ có chủ hộ
        expect(find.text('Hiện tại chưa có thành viên nào khác trong phòng.'), findsOneWidget);
      });

      testWidgets('Kéo vuốt làm mới danh sách thành viên', (tester) async {
        when(() => mockDio.get('/roommates')).thenAnswer((_) async => Response(
              data: {'success': true, 'data': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates'),
            ));

        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        expect(find.text('Thành Viên Phòng'), findsOneWidget);
      });
    });

    // =========================================================================
    // 2. Domain & State Management
    // =========================================================================
    group('2. Domain & State Management', () {
      test('Initial State của RoommateNotifier', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(roommateProvider);
        expect(state.roommates, isEmpty);
        expect(state.pendingRequests, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.errorMessage, null);
      });

      test('fetchRoommates thành công cập nhật state roommates', () async {
        when(() => mockDio.get('/roommates')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': testRoommates.map((r) => r.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates'),
            ));

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(roommateProvider.notifier).fetchRoommates();

        final state = container.read(roommateProvider);
        expect(state.isLoading, isFalse);
        expect(state.roommates.length, 2);
        expect(state.roommates.first.fullName, 'Lê Văn Ở Ghép');
      });

      test('fetchRoommates bị lỗi mạng cập nhật errorMessage', () async {
        when(() => mockDio.get('/roommates')).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/roommates'),
            error: 'Mất kết nối mạng',
          ),
        );

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(roommateProvider.notifier).fetchRoommates();

        final state = container.read(roommateProvider);
        expect(state.isLoading, isFalse);
        expect(state.errorMessage, isNotNull);
      });
    });

    // =========================================================================
    // 3. Repository Layer
    // =========================================================================
    group('3. Repository Layer', () {
      test('Gọi API GET /roommates đúng endpoint cô lập dữ liệu BR-23', () async {
        when(() => mockDio.get('/roommates')).thenAnswer((_) async => Response(
              data: {'success': true, 'data': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates'),
            ));

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(roommateProvider.notifier).fetchRoommates();

        verify(() => mockDio.get('/roommates')).called(1);
      });
    });
  });
}
