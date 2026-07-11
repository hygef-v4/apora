import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../lib/features/communication/models/notification_model.dart';
import '../../../../lib/features/communication/screens/notification_detail_screen.dart';
import '../../../../lib/features/communication/repositories/communication_repository.dart';
import '../../../../lib/features/communication/providers/notification_detail_provider.dart';

// Mocks
class MockCommunicationRepository extends Mock implements CommunicationRepository {}
class MockDio extends Mock implements Dio {}

void main() {
  group('UC26: View Notification Detail', () {
    late MockCommunicationRepository mockRepo;
    late NotificationModel testNotification;

    setUp(() {
      mockRepo = MockCommunicationRepository();
      testNotification = NotificationModel(
        id: 1,
        title: 'Test Notification',
        body: 'This is the body of the notification',
        type: 'SYSTEM',
        createdAt: DateTime.now(),
        isRead: false,
      );
    });

    Widget createTestWidget(NotificationModel notification) {
      return ProviderScope(
        overrides: [
          communicationRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: MaterialApp(
          home: NotificationDetailScreen(notification: notification),
        ),
      );
    }

    group('1. UI & Widget Tests', () {
      testWidgets('Main Flow: BR-54 & BR-56 hiển thị nội dung và gọi markAsRead không làm block UI', (tester) async {
        // Giả lập API markAsRead thành công nhưng delay 1 giây (để chứng minh BR-54 Asynchronous)
        when(() => mockRepo.markAsRead(1)).thenAnswer((_) async {
          await Future.delayed(const Duration(seconds: 1));
        });

        await tester.pumpWidget(createTestWidget(testNotification));

        // Ngay lập tức UI phải hiện nội dung (BR-54)
        expect(find.text('Test Notification'), findsOneWidget);
        expect(find.text('This is the body of the notification'), findsOneWidget);
        
        // Không có button do type là SYSTEM
        expect(find.byType(FilledButton), findsNothing);

        // Cho Future hoàn thành
        await tester.pumpAndSettle(const Duration(seconds: 2));
        verify(() => mockRepo.markAsRead(1)).called(1);
      });

      testWidgets('BR-55: Notification Immutability (Chỉ đọc, không có nút sửa)', (tester) async {
        when(() => mockRepo.markAsRead(1)).thenAnswer((_) async => {});

        await tester.pumpWidget(createTestWidget(testNotification));
        await tester.pumpAndSettle();

        // Kiểm tra không có TextField nào tồn tại
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
      });

      testWidgets('BR-56: Actionable Deep Linking (Hiển thị nút cho INVOICE và TICKET)', (tester) async {
        when(() => mockRepo.markAsRead(any())).thenAnswer((_) async => {});

        // Test INVOICE
        final invoiceNotif = testNotification.copyWith(type: 'INVOICE');
        await tester.pumpWidget(createTestWidget(invoiceNotif));
        await tester.pumpAndSettle();
        expect(find.text('Xem hóa đơn'), findsOneWidget);

        // Test TICKET
        final ticketNotif = testNotification.copyWith(type: 'TICKET');
        await tester.pumpWidget(createTestWidget(ticketNotif));
        await tester.pumpAndSettle();
        expect(find.text('Xem yêu cầu sửa chữa'), findsOneWidget);
      });

      testWidgets('AT1: Bị Manager thu hồi/xóa (API trả 404) -> Báo lỗi & hiện nút Go Back', (tester) async {
        when(() => mockRepo.markAsRead(1)).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(
              requestOptions: RequestOptions(path: ''),
              statusCode: 404, // 404 Not Found
            ),
          ),
        );

        await tester.pumpWidget(createTestWidget(testNotification));
        // Pump để đợi async logic cập nhật UI
        await tester.pumpAndSettle();

        // Kiểm tra UI hiển thị lỗi theo yêu cầu AT1
        expect(find.text('This notification is no longer available or has been removed by the management.'), findsOneWidget);
        expect(find.text('Go Back'), findsOneWidget);
        
        // Đảm bảo không hiển thị nội dung thông báo nữa
        expect(find.text('This is the body of the notification'), findsNothing);
      });

      testWidgets('AT2: Lỗi mạng (Offline mode) -> Hiện cảnh báo Offline nhưng vẫn giữ nguyên dữ liệu đệm', (tester) async {
        when(() => mockRepo.markAsRead(1)).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout, // Lỗi mạng
          ),
        );

        await tester.pumpWidget(createTestWidget(testNotification));
        await tester.pumpAndSettle();

        // Kiểm tra UI hiển thị banner cảnh báo
        expect(find.text('Offline mode: Cannot load full details or mark as read. Please check your connection.'), findsOneWidget);
        
        // Vẫn giữ lại nội dung để xem (cache data)
        expect(find.text('This is the body of the notification'), findsOneWidget);
      });
    });

    group('2. Domain & State Management', () {
      late ProviderContainer container;

      setUp(() {
        container = ProviderContainer(
          overrides: [
            communicationRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );
      });

      tearDown(() {
        container.dispose();
      });

      test('Initial State phải là initial', () {
        final state = container.read(notificationDetailProvider);
        expect(state, NotificationDetailStatus.initial);
      });

      test('Happy Path: markAsRead thành công chuyển state sang loading rồi success', () async {
        when(() => mockRepo.markAsRead(1)).thenAnswer((_) async => {});

        final notifier = container.read(notificationDetailProvider.notifier);
        
        final states = <NotificationDetailStatus>[];
        container.listen<NotificationDetailStatus>(
          notificationDetailProvider,
          (previous, next) => states.add(next),
          fireImmediately: false,
        );

        await notifier.markAsRead(1);
        expect(states, [NotificationDetailStatus.loading, NotificationDetailStatus.success]);
      });

      test('Error Path AT1: markAsRead bị lỗi 404 chuyển state sang notFound', () async {
        when(() => mockRepo.markAsRead(1)).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            response: Response(requestOptions: RequestOptions(path: ''), statusCode: 404),
          ),
        );

        final notifier = container.read(notificationDetailProvider.notifier);
        
        final states = <NotificationDetailStatus>[];
        container.listen<NotificationDetailStatus>(
          notificationDetailProvider,
          (previous, next) => states.add(next),
          fireImmediately: false,
        );

        await notifier.markAsRead(1);
        expect(states, [NotificationDetailStatus.loading, NotificationDetailStatus.notFound]);
      });

      test('Error Path AT2: markAsRead bị lỗi mạng chuyển state sang networkError', () async {
        when(() => mockRepo.markAsRead(1)).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        final notifier = container.read(notificationDetailProvider.notifier);
        
        final states = <NotificationDetailStatus>[];
        container.listen<NotificationDetailStatus>(
          notificationDetailProvider,
          (previous, next) => states.add(next),
          fireImmediately: false,
        );

        await notifier.markAsRead(1);
        expect(states, [NotificationDetailStatus.loading, NotificationDetailStatus.networkError]);
      });
    });

    group('3. Repository Layer', () {
      late MockDio mockDio;
      late CommunicationRepository repo;

      setUp(() {
        mockDio = MockDio();
        repo = CommunicationRepository(mockDio);
      });

      test('Repository: gọi đúng method PATCH và đúng path', () async {
        when(() => mockDio.patch(any())).thenAnswer(
          (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 200),
        );

        await repo.markAsRead(1);
        verify(() => mockDio.patch('/notifications/1/read')).called(1);
      });
      
      test('Repository: ném DioException nếu API lỗi', () async {
        when(() => mockDio.patch(any())).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
          ),
        );

        expect(() => repo.markAsRead(1), throwsA(isA<DioException>()));
      });
    });
  });
}
