import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/roommate/models/roommate.dart';
import 'package:apartment_management/features/roommate/providers/roommate_provider.dart';
import 'package:apartment_management/features/roommate/screens/manager_roommate_detail_screen.dart';
import 'package:apartment_management/features/roommate/screens/manager_roommate_list_screen.dart';
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

  group('UC11: Review Roommate Registration - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    const managerUser = User(
      id: 2,
      phoneNumber: '0900000002',
      fullName: 'Ban Quản Lý',
      roles: ['MANAGER'],
    );

    final pendingRoommates = [
      Roommate(
        id: 10,
        apartmentId: 101,
        fullName: 'Nguyễn Văn Đăng Ký',
        phoneNumber: '0988888888',
        cccdNumber: '001200999888',
        cccdFrontUrl: 'https://cloudinary.com/front.jpg',
        cccdBackUrl: 'https://cloudinary.com/back.jpg',
        status: 'PENDING',
        createdAt: DateTime(2026, 1, 10),
        unitNumber: '101',
      ),
    ];

    setUp(() {
      mockDio = MockDio();
    });

    Widget createListWidget() {
      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(managerUser)),
        ],
        child: const MaterialApp(
          home: RoommateApprovalListScreen(),
        ),
      );
    }

    Widget createDetailWidget(int roommateId) {
      return ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(mockDio),
          authNotifierProvider.overrideWith(() => MockAuthNotifier(managerUser)),
        ],
        child: MaterialApp(
          home: RoommateApprovalDetailScreen(roommateId: roommateId),
        ),
      );
    }

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      testWidgets('Render danh sách yêu cầu chờ duyệt (BR-21 PENDING state)', (tester) async {
        when(() => mockDio.get('/roommates/pending')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': pendingRoommates.map((r) => r.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates/pending'),
            ));

        await tester.pumpWidget(createListWidget());
        await tester.pumpAndSettle();

        expect(find.text('Duyệt Thành Viên'), findsOneWidget);
        expect(find.text('Nguyễn Văn Đăng Ký'), findsOneWidget);
        expect(find.text('Căn hộ: Căn 101'), findsOneWidget);
      });

      testWidgets('Render màn hình đối soát CCCD với số CCCD đã mask (BR-08, BR-22)', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(() => mockDio.get('/roommates/pending')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': pendingRoommates.map((r) => r.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates/pending'),
            ));

        await tester.pumpWidget(createDetailWidget(10));
        await tester.pumpAndSettle();

        expect(find.text('Đối Soát CCCD'), findsOneWidget);
        expect(find.text('Nguyễn Văn Đăng Ký'), findsOneWidget);
        // BR-08: Số CCCD phải được mask trên UI
        expect(find.text('********9888'), findsOneWidget);
        expect(find.text('PHÊ DUYỆT'), findsOneWidget);
        expect(find.text('TỪ CHỐI'), findsOneWidget);
      });

      testWidgets('Phê duyệt thành công gọi API PATCH status APPROVED (BR-18, BR-21)', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(() => mockDio.get('/roommates/pending')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': pendingRoommates.map((r) => r.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates/pending'),
            ));

        when(() => mockDio.patch('/roommates/10/status', data: {'status': 'APPROVED'})).thenAnswer(
          (_) async => Response(
            data: {'success': true},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/roommates/10/status'),
          ),
        );

        await tester.pumpWidget(createDetailWidget(10));
        await tester.pumpAndSettle();

        await tester.tap(find.text('PHÊ DUYỆT'));
        await tester.pumpAndSettle();

        // Xử lý dialog xác nhận
        await tester.tap(find.text('Xác Nhận'));
        await tester.pumpAndSettle();

        verify(() => mockDio.patch('/roommates/10/status', data: {'status': 'APPROVED'})).called(1);
      });

      testWidgets('Từ chối mở dialog nhập lý do và gửi status REJECTED (BR-21)', (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(() => mockDio.get('/roommates/pending')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': pendingRoommates.map((r) => r.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates/pending'),
            ));

        when(() => mockDio.patch(
              '/roommates/10/status',
              data: {'status': 'REJECTED', 'reason': 'Ảnh CCCD bị mờ'},
            )).thenAnswer(
          (_) async => Response(
            data: {'success': true},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/roommates/10/status'),
          ),
        );

        await tester.pumpWidget(createDetailWidget(10));
        await tester.pumpAndSettle();

        await tester.tap(find.text('TỪ CHỐI'));
        await tester.pumpAndSettle();

        expect(find.text('Lý do từ chối'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), 'Ảnh CCCD bị mờ');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Từ Chối'));
        await tester.pumpAndSettle();

        verify(() => mockDio.patch(
              '/roommates/10/status',
              data: {'status': 'REJECTED', 'reason': 'Ảnh CCCD bị mờ'},
            )).called(1);
      });
    });

    // =========================================================================
    // 2. Domain & State Management
    // =========================================================================
    group('2. Domain & State Management', () {
      test('fetchPendingRequests cập nhật state pendingRequests', () async {
        when(() => mockDio.get('/roommates/pending')).thenAnswer((_) async => Response(
              data: {
                'success': true,
                'data': pendingRoommates.map((r) => r.toJson()).toList(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates/pending'),
            ));

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(roommateProvider.notifier).fetchPendingRequests();

        final state = container.read(roommateProvider);
        expect(state.pendingRequests.length, 1);
        expect(state.pendingRequests.first.fullName, 'Nguyễn Văn Đăng Ký');
      });

      test('updateRequestStatus gọi API patch và refresh danh sách', () async {
        when(() => mockDio.patch('/roommates/10/status', data: {'status': 'APPROVED'})).thenAnswer(
          (_) async => Response(
            data: {'success': true},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/roommates/10/status'),
          ),
        );

        when(() => mockDio.get('/roommates/pending')).thenAnswer((_) async => Response(
              data: {'success': true, 'data': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates/pending'),
            ));

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(roommateProvider.notifier).updateRequestStatus(
              roommateId: 10,
              status: 'APPROVED',
            );

        final state = container.read(roommateProvider);
        expect(state.pendingRequests, isEmpty);
      });
    });

    // =========================================================================
    // 3. Repository Layer
    // =========================================================================
    group('3. Repository Layer', () {
      test('Gọi API PATCH /roommates/:id/status với payload chuẩn (BR-21)', () async {
        when(() => mockDio.patch(
              '/roommates/10/status',
              data: {'status': 'REJECTED', 'reason': 'Sai số CCCD'},
            )).thenAnswer(
          (_) async => Response(
            data: {'success': true},
            statusCode: 200,
            requestOptions: RequestOptions(path: '/roommates/10/status'),
          ),
        );

        when(() => mockDio.get('/roommates/pending')).thenAnswer((_) async => Response(
              data: {'success': true, 'data': []},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/roommates/pending'),
            ));

        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        addTearDown(container.dispose);

        await container.read(roommateProvider.notifier).updateRequestStatus(
              roommateId: 10,
              status: 'REJECTED',
              reason: 'Sai số CCCD',
            );

        verify(() => mockDio.patch(
              '/roommates/10/status',
              data: {'status': 'REJECTED', 'reason': 'Sai số CCCD'},
            )).called(1);
      });
    });
  });
}
