import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/communication/models/notification_model.dart';
import 'package:apartment_management/features/communication/providers/notification_list_provider.dart';
import 'package:apartment_management/features/communication/repositories/communication_repository.dart';
import 'package:apartment_management/features/communication/screens/notification_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart' as go_router;
import 'dart:async';

class MockDio extends Mock implements Dio {}
class MockCommunicationRepository extends Mock implements CommunicationRepository {}
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

  group('UC25: View Notifications - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    late MockCommunicationRepository mockRepo;
    late NotificationModel mockNotifRead;
    late NotificationModel mockNotifUnread;

    setUp(() {
      mockDio = MockDio();
      mockRepo = MockCommunicationRepository();
      
      mockNotifRead = NotificationModel(
        id: 1,
        title: 'Thông báo đã đọc',
        body: 'Nội dung 1',
        type: 'SYSTEM',
        createdAt: DateTime(2023, 1, 1, 10, 0),
        isRead: true,
      );
      
      mockNotifUnread = NotificationModel(
        id: 2,
        title: 'Thông báo chưa đọc',
        body: 'Nội dung 2',
        type: 'INVOICE',
        createdAt: DateTime(2023, 1, 2, 10, 0),
        isRead: false,
      );
    });

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {


      Widget createWidgetWithRepo({
        required MockCommunicationRepository repo,
        bool isManager = true,
      }) {
        final router = go_router.GoRouter(
          initialLocation: '/notifications',
          routes: [
            go_router.GoRoute(
              path: '/notifications',
              builder: (context, state) => const NotificationListScreen(),
            ),
            go_router.GoRoute(
              path: '/manager/announce',
              builder: (context, state) => const Scaffold(body: Text('Announce Screen')),
            ),
            go_router.GoRoute(
              path: '/notifications/detail',
              builder: (context, state) => const Scaffold(body: Text('Detail Screen')),
            ),
          ],
        );

        final authState = AuthState(
          user: User(
            id: 1,
            fullName: 'Test',
            phoneNumber: '0123',
            roles: [isManager ? 'MANAGER' : 'RESIDENT'],
          ),
          status: AuthStatus.authenticated,
        );

        return ProviderScope(
          overrides: [
            communicationRepositoryProvider.overrideWithValue(repo),
            authNotifierProvider.overrideWith(() => MockAuthNotifier(authState)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        );
      }

      testWidgets('Hiển thị Loading Indicator khi đang tải', (tester) async {
        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 500));
          return [];
        });

        await tester.pumpWidget(createWidgetWithRepo(repo: mockRepo));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.pumpAndSettle();
      });

      testWidgets('Hiển thị thông báo lỗi khi API thất bại và test Retry button (AT2)', (tester) async {
        bool shouldThrow = true;
        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async {
          if (shouldThrow) { 
            throw DioException(
              requestOptions: RequestOptions(path: '/notifications'),
              response: Response(
                requestOptions: RequestOptions(path: '/notifications'),
                statusCode: 500,
                data: {'message': 'Lỗi mạng'},
              ),
              type: DioExceptionType.badResponse,
            );
          }
          return [];
        });

        await tester.pumpWidget(createWidgetWithRepo(repo: mockRepo));
        await tester.pumpAndSettle();
        
        // Assert error UI and Retry button
        expect(find.text('Thử lại'), findsOneWidget);
        
        // Test retry behavior
        shouldThrow = false; // Now allow it to succeed
        await tester.tap(find.text('Thử lại'));
        await tester.pumpAndSettle(); // Settle the successful load
        
        expect(find.text('Chưa có thông báo nào'), findsOneWidget);
      });

      testWidgets('Hiển thị Empty State khi danh sách rỗng', (tester) async {
        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => []);

        await tester.pumpWidget(createWidgetWithRepo(repo: mockRepo));
        await tester.pumpAndSettle();
        
        expect(find.text('Chưa có thông báo nào'), findsOneWidget);
        expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
      });

      testWidgets('Hiển thị danh sách thông báo và phân biệt chưa đọc', (tester) async {
        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => [mockNotifRead, mockNotifUnread]);

        await tester.pumpWidget(createWidgetWithRepo(repo: mockRepo));
        await tester.pumpAndSettle();

        expect(find.text('Thông báo đã đọc'), findsOneWidget);
        expect(find.text('Thông báo chưa đọc'), findsOneWidget);
        expect(find.byType(GestureDetector), findsWidgets);
      });
      
      testWidgets('Pagination: Cuộn xuống cuối tải thêm dữ liệu (BR-51)', (tester) async {
        final firstPage = List.generate(20, (i) => NotificationModel(
          id: i, title: 'Notif $i', body: 'Body $i', type: 'SYSTEM', createdAt: DateTime.now().subtract(Duration(minutes: i)), isRead: true,
        ));
        final secondPage = List.generate(5, (i) => NotificationModel(
          id: 20 + i, title: 'Notif ${20 + i}', body: 'Body ${20 + i}', type: 'SYSTEM', createdAt: DateTime.now().subtract(Duration(minutes: 20 + i)), isRead: true,
        ));

        final completer = Completer<List<NotificationModel>>();

        when(() => mockRepo.getNotifications(limit: 20, offset: 0))
            .thenAnswer((_) async => firstPage);
        when(() => mockRepo.getNotifications(limit: 20, offset: 20))
            .thenAnswer((_) => completer.future);

        await tester.pumpWidget(createWidgetWithRepo(repo: mockRepo));
        await tester.pumpAndSettle();

        // Đang hiển thị trang 1
        expect(find.text('Notif 0'), findsOneWidget);
        
        // Cuộn xuống cuối
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump();
        
        // Cuộn xuống cuối
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump();
        
        // Vuốt thêm để hiện loading indicator
        for (int i = 0; i < 5; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pump();
          if (tester.any(find.byType(CircularProgressIndicator))) {
            break;
          }
        }

        // Phải hiển thị loading indicator ở bottom (isLoadingMore = true)
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        // Hoàn thành future
        completer.complete(secondPage);
        await tester.pumpAndSettle();
        
        // Vuốt xuống để xem item mới
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pumpAndSettle();

        // Kiểm tra đã load trang 2
        expect(find.text('Notif 24'), findsOneWidget);
        
        // Repo phải được gọi đúng limit/offset
        verify(() => mockRepo.getNotifications(limit: 20, offset: 0)).called(1);
        verify(() => mockRepo.getNotifications(limit: 20, offset: 20)).called(1);
      });

      testWidgets('FAB hiển thị cho Manager và điều hướng sang Tạo thông báo', (tester) async {
        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => []);

        await tester.pumpWidget(createWidgetWithRepo(isManager: true, repo: mockRepo));
        await tester.pumpAndSettle();

        final fab = find.byType(FloatingActionButton);
        expect(fab, findsOneWidget);

        await tester.tap(fab);
        await tester.pumpAndSettle();

        expect(find.text('Announce Screen'), findsOneWidget);
      });

      testWidgets('FAB ẨN đối với Resident', (tester) async {
        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => []);

        await tester.pumpWidget(createWidgetWithRepo(isManager: false, repo: mockRepo));
        await tester.pumpAndSettle();
        expect(find.byType(FloatingActionButton), findsNothing);
      });

      testWidgets('Nhấn vào thông báo điều hướng sang Chi tiết', (tester) async {
        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => [mockNotifRead]);

        await tester.pumpWidget(createWidgetWithRepo(repo: mockRepo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Thông báo đã đọc'));
        await tester.pumpAndSettle();

        expect(find.text('Detail Screen'), findsOneWidget);
      });

      testWidgets('BR: Icon thay đổi dựa theo loại thông báo (INVOICE, TICKET, SYSTEM)', (tester) async {
        final mockNotifInvoice = NotificationModel(
          id: 3, title: 'Hóa đơn', body: 'Nội dung', type: 'INVOICE', createdAt: DateTime.now(), isRead: true,
        );
        final mockNotifTicket = NotificationModel(
          id: 4, title: 'Sự cố', body: 'Nội dung', type: 'TICKET', createdAt: DateTime.now(), isRead: true,
        );
        final mockNotifSystem = NotificationModel(
          id: 5, title: 'Hệ thống', body: 'Nội dung', type: 'SYSTEM', createdAt: DateTime.now(), isRead: true,
        );

        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => [mockNotifInvoice, mockNotifTicket, mockNotifSystem]);

        await tester.pumpWidget(createWidgetWithRepo(repo: mockRepo));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.credit_card_outlined), findsOneWidget);
        expect(find.byIcon(Icons.build_outlined), findsOneWidget);
        expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
      });
    });

    group('2. Domain & State Management (NotificationListProvider)', () {
      test('notificationListProvider trả về dữ liệu đúng từ Repository', () async {
        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => [mockNotifUnread]);

        final container = ProviderContainer(
          overrides: [
            communicationRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );

        final future = container.read(notificationListProvider.future);
        final result = await future;

        expect(result.length, 1);
        expect(result.first.id, 2);
        
        container.dispose();
      });

      test('BR-52: Notification Sorting Priority (Notifications always sorted by createdAt descending)', () async {
        final olderNotif = NotificationModel(
          id: 10, title: 'Older', body: 'body', type: 'SYSTEM', 
          createdAt: DateTime.now().subtract(const Duration(days: 2)), isRead: false
        );
        final newerNotif = NotificationModel(
          id: 11, title: 'Newer', body: 'body', type: 'SYSTEM', 
          createdAt: DateTime.now().subtract(const Duration(days: 1)), isRead: false
        );
        // Repository trả về không đúng thứ tự (cũ trước, mới sau)
        when(() => mockRepo.getNotifications(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => [olderNotif, newerNotif]);

        final container = ProviderContainer(
          overrides: [
            communicationRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );

        final future = container.read(notificationListProvider.future);
        final result = await future;

        // Provider phải tự sort lại (mới nhất lên đầu)
        expect(result.length, 2);
        expect(result[0].id, 11); // Newer phải ở index 0
        expect(result[1].id, 10); // Older phải ở index 1
        
        container.dispose();
      });
    });

    // =========================================================================
    // 3. Repository Layer (CommunicationRepository)
    // =========================================================================
    group('3. Repository Layer (CommunicationRepository)', () {
      test('BR-53: Notification Data Isolation (Repository không truyền user_id vào params để bảo mật)', () async {
        final apiResponse = {
          'status': 'success',
          'data': []
        };

        when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
            .thenAnswer((_) async => Response(
                  requestOptions: RequestOptions(path: ''),
                  statusCode: 200,
                  data: apiResponse,
                ));

        final repo = CommunicationRepository(mockDio);
        await repo.getNotifications();

        // Xác minh queryParameters chỉ chứa limit và offset, KHÔNG chứa user_id để tránh cross-user querying
        final captured = verify(() => mockDio.get(any(), queryParameters: captureAny(named: 'queryParameters'))).captured;
        final queryParams = captured.first as Map<String, dynamic>;
        
        expect(queryParams.containsKey('limit'), true);
        expect(queryParams.containsKey('offset'), true);
        expect(queryParams.containsKey('user_id'), false);
      });
      test('Repository: Alternative Flow ném Exception nếu status là error', () async {
        final apiResponse = {
          'status': 'error',
          'message': 'Lỗi từ máy chủ',
        };

        when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
            .thenAnswer((_) async => Response(
                  requestOptions: RequestOptions(path: ''),
                  statusCode: 200, // Status HTTP 200 nhưng logic API lỗi
                  data: apiResponse,
                ));

        final repo = CommunicationRepository(mockDio);
        
        expect(() => repo.getNotifications(), throwsA(isA<Exception>()));
      });
      test('Repository: getNotifications parse đúng JSON list từ API', () async {
        final apiResponse = {
          'data': [
            {
              'id': 999,
              'title': 'Test Title',
              'body': 'Test Body',
              'type': 'SYSTEM',
              'createdAt': '2023-01-01T10:00:00Z',
              'isRead': false,
            }
          ]
        };

        when(() => mockDio.get(any(), queryParameters: any(named: 'queryParameters')))
            .thenAnswer((_) async => Response(
                  requestOptions: RequestOptions(path: ''),
                  statusCode: 200,
                  data: apiResponse,
                ));

        final repo = CommunicationRepository(mockDio);
        final result = await repo.getNotifications();

        verify(() => mockDio.get('/notifications', queryParameters: any(named: 'queryParameters'))).called(1);
        expect(result.length, 1);
        expect(result.first.id, 999);
        expect(result.first.title, 'Test Title');
        expect(result.first.isRead, false);
      });
    });
  });
}
