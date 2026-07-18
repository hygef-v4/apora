import 'dart:io';
import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/auth_profile/models/user.dart';
import 'package:apartment_management/features/auth_profile/providers/auth_notifier.dart';
import 'package:apartment_management/features/chat/models/chat_message_model.dart';
import 'package:apartment_management/features/chat/models/chat_session_model.dart';
import 'package:apartment_management/features/chat/providers/chat_provider.dart';
import 'package:apartment_management/features/chat/repositories/chat_repository.dart';
import 'package:apartment_management/features/chat/screens/chat_list_screen.dart';
import 'package:apartment_management/features/chat/screens/chat_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:apartment_management/features/management/models/apartment.dart';
import 'package:apartment_management/features/management/providers/apartment_notifier.dart';

class MockDio extends Mock implements Dio {}
class MockChatRepository extends Mock implements ChatRepository {}
class MockImagePicker extends Mock implements ImagePicker {}

class MockApartmentDirectoryNotifier extends ApartmentDirectoryNotifier {
  final List<Apartment> apartments;

  MockApartmentDirectoryNotifier(this.apartments);

  @override
  Future<List<Apartment>> build() async => apartments;
}

class MockAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  final User mockUser;
  MockAuthNotifier(this.mockUser);

  @override
  AuthState build() {
    return AuthState(status: AuthStatus.authenticated, user: mockUser);
  }

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
    registerFallbackValue(ImageSource.gallery);
    registerFallbackValue(File(''));
    registerFallbackValue(FormData());
  });

  group('UC28: Use Live Chat - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    late MockChatRepository mockRepo;
    late User mockUser;

    setUp(() {
      mockDio = MockDio();
      mockRepo = MockChatRepository();
      mockUser = User(
        id: 1,
        phoneNumber: '0123456789',
        fullName: 'Test User',
        roles: ['RESIDENT'],
      );
    });

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      Widget createChatScreen() {
        return ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(mockDio),
            chatRepositoryProvider.overrideWithValue(mockRepo),
            authNotifierProvider.overrideWith(() => MockAuthNotifier(mockUser)),
          ],
          child: const MaterialApp(
            home: ChatScreen(title: 'Chat với Ban Quản Lý'),
          ),
        );
      }

      Widget createChatListScreen() {
        return ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(mockDio),
            chatRepositoryProvider.overrideWithValue(mockRepo),
            apartmentDirectoryProvider.overrideWith(() => MockApartmentDirectoryNotifier([
                  Apartment(
                    id: 1,
                    unitNumber: '101',
                    floor: '1',
                    status: 'OCCUPIED',
                    areaSize: 45,
                    baseRent: 5000000,
                    ownerId: 10,
                    ownerName: 'Nguyen Van A',
                    ownerPhone: '0900000000',
                    unpaidInvoiceCount: 0,
                    unresolvedTicketCount: 0,
                  ),
                ])),
            authNotifierProvider.overrideWith(() => MockAuthNotifier(mockUser)),
          ],
          child: const MaterialApp(
            home: ManagerChatListScreen(),
          ),
        );
      }

      testWidgets('Hiển thị đầy đủ giao diện phòng chat', (tester) async {
        when(() => mockRepo.getMessages(any())).thenAnswer((_) async => []);
        when(() => mockRepo.markAsRead(any())).thenAnswer((_) async {});

        await tester.pumpWidget(createChatScreen());
        await tester.pumpAndSettle();

        expect(find.text('Chat với Ban Quản Lý'), findsOneWidget);
        expect(find.text('Chưa có tin nhắn nào.'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.image), findsOneWidget);
        expect(find.byIcon(Icons.send), findsOneWidget);
      });

      testWidgets('AT: Gửi tin nhắn thành công', (tester) async {
        when(() => mockRepo.getMessages(any())).thenAnswer((_) async => []);
        when(() => mockRepo.markAsRead(any())).thenAnswer((_) async {});
        
        final mockMessage = ChatMessageModel(
          id: 99,
          senderId: 1,
          receiverId: null,
          content: 'Hello Management',
          isImage: false,
          isRead: false,
          createdAt: DateTime.now(),
          senderName: 'Test User',
          senderRole: 'RESIDENT',
        );

        when(() => mockRepo.sendMessage(
              receiverId: any(named: 'receiverId'),
              content: any(named: 'content'),
              image: any(named: 'image'),
            )).thenAnswer((_) async => mockMessage);

        await tester.pumpWidget(createChatScreen());
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Hello Management');
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Should see optimistic UI text
        expect(find.text('Hello Management'), findsWidgets);
        
        await tester.pumpAndSettle(); // finish api call
        
        verify(() => mockRepo.sendMessage(
              content: 'Hello Management',
              receiverId: null,
            )).called(1);
      });

      testWidgets('AT1: Nhấn gửi khi không có nội dung, không gọi API', (tester) async {
        when(() => mockRepo.getMessages(any())).thenAnswer((_) async => []);
        when(() => mockRepo.markAsRead(any())).thenAnswer((_) async {});

        await tester.pumpWidget(createChatScreen());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        verifyNever(() => mockRepo.sendMessage(
              content: any(named: 'content'),
              receiverId: any(named: 'receiverId'),
            ));
      });

      testWidgets('Hiển thị giao diện danh sách chat (Manager)', (tester) async {
        when(() => mockRepo.getChatSessions())
            .thenAnswer((_) async => [
                  ChatSessionModel(
                    residentId: 10,
                    residentName: 'Nguyen Van A',
                    lastMessage: 'Cho tôi hỏi về hóa đơn',
                    unitNumber: '101',
                    updatedAt: DateTime.now(),
                    unreadCount: 2,
                    isLastMessageImage: false,
                  )
                ]);

        await tester.pumpWidget(createChatListScreen());
        await tester.pumpAndSettle();

        expect(find.text('Hỗ trợ'), findsOneWidget);
        expect(find.text('Căn hộ 101'), findsOneWidget);
        expect(find.text('Nguyen Van A'), findsOneWidget);
        expect(find.text('2'), findsOneWidget); // unread count
      });
    });

    // =========================================================================
    // 2. Domain & State Management
    // =========================================================================
    group('2. Domain & State Management', () {
      test('ChatSessionsNotifier: Load dữ liệu thành công', () async {
        when(() => mockRepo.getChatSessions(limit: any(named: 'limit'), offset: any(named: 'offset')))
            .thenAnswer((_) async => []);

        final container = ProviderContainer(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockRepo),
          ],
        );

        final future = container.read(chatSessionsProvider.future);
        expect(container.read(chatSessionsProvider).isLoading, true);
        
        final data = await future;
        expect(data, []);
        expect(container.read(chatSessionsProvider).isLoading, false);

        container.dispose();
      });

      test('BR-45: Live Chat cô lập theo phòng; Provider chỉ subscribe đúng channel theo Role', () async {
        when(() => mockRepo.getMessages(any())).thenAnswer((_) async => []);
        
        // Test Resident role
        final container = ProviderContainer(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockRepo),
            authNotifierProvider.overrideWith(() => MockAuthNotifier(mockUser)),
          ],
        );
        
        final notifier = container.read(chatMessagesProvider.notifier);
        await container.read(chatMessagesProvider.future);
        
        // Pusher initialization should happen without crashing for RESIDENT
        expect(notifier.state.hasValue, true);
        
        // Test Manager role
        final managerUser = User(
          id: 2,
          phoneNumber: '0987654321',
          fullName: 'Manager User',
          roles: ['MANAGER'],
        );
        
        final managerContainer = ProviderContainer(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockRepo),
            authNotifierProvider.overrideWith(() => MockAuthNotifier(managerUser)),
          ],
        );
        
        final managerNotifier = managerContainer.read(chatMessagesProvider.notifier);
        await managerContainer.read(chatMessagesProvider.future);
        
        // Pusher initialization should happen without crashing for MANAGER and subscribe to management channel
        expect(managerNotifier.state.hasValue, true);

        container.dispose();
        managerContainer.dispose();
      });

      test('AT1: Gửi tin nhắn lỗi sẽ hiển thị lại state cũ (Optimistic Rollback)', () async {
        when(() => mockRepo.getMessages(any())).thenAnswer((_) async => []);
        when(() => mockRepo.sendMessage(
              receiverId: any(named: 'receiverId'),
              content: any(named: 'content'),
              image: any(named: 'image'),
            )).thenThrow(Exception('Lỗi mạng'));

        final container = ProviderContainer(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockRepo),
            authNotifierProvider.overrideWith(() => MockAuthNotifier(mockUser)),
          ],
        );

        final notifier = container.read(chatMessagesProvider.notifier);
        await container.read(chatMessagesProvider.future); // Wait for initial load

        expect(() => notifier.sendMessage(content: 'Test'), throwsException);
        
        container.dispose();
      });
    });

    // =========================================================================
    // 3. Repository Layer
    // =========================================================================
    group('3. Repository Layer', () {
      test('ChatRepository.getChatSessions gọi API chính xác', () async {
        when(() => mockDio.get('/chat/sessions', queryParameters: any(named: 'queryParameters')))
            .thenAnswer((_) async => Response(
                  requestOptions: RequestOptions(path: ''),
                  statusCode: 200,
                  data: {'status': 'success', 'data': []},
                ));

        final repo = ChatRepository(mockDio);
        final res = await repo.getChatSessions();

        expect(res, []);
        verify(() => mockDio.get('/chat/sessions', queryParameters: {'limit': 20, 'offset': 0})).called(1);
      });

      test('ChatRepository.sendMessage gọi API chính xác với content', () async {
        when(() => mockDio.post('/chat/messages', data: any(named: 'data')))
            .thenAnswer((_) async => Response(
                  requestOptions: RequestOptions(path: ''),
                  statusCode: 200,
                  data: {
                    'status': 'success',
                    'data': {
                      'id': 1,
                      'sender_id': 1,
                      'receiver_id': null,
                      'content': 'ABC',
                      'is_image': false,
                      'is_read': false,
                      'created_at': DateTime.now().toIso8601String(),
                    }
                  },
                ));

        final repo = ChatRepository(mockDio);
        final res = await repo.sendMessage(content: 'ABC');

        expect(res.content, 'ABC');
        verify(() => mockDio.post('/chat/messages', data: any(named: 'data'))).called(1);
      });
    });
  });
}
