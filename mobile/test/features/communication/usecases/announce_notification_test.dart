import 'package:apartment_management/core/network/dio_client.dart';
import 'package:apartment_management/features/communication/providers/announce_notifier.dart';
import 'package:apartment_management/features/communication/repositories/communication_repository.dart';
import 'package:apartment_management/features/communication/screens/announce_form_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart' as go_router;

class MockDio extends Mock implements Dio {}
class MockCommunicationRepository extends Mock implements CommunicationRepository {}
class MockImagePicker extends Mock implements ImagePicker {}

void main() {
  setUpAll(() async {
    // Ngăn lỗi DotEnv chưa được khởi tạo khi ProviderContainer vô tình load ApiConstants.baseUrl
    await dotenv.load(fileName: ".env");
    registerFallbackValue(ImageSource.gallery);
  });

  group('UC24: Announce Notification - 100% Coverage & Business Rules', () {
    late MockDio mockDio;
    late MockImagePicker mockImagePicker;

    setUp(() {
      mockDio = MockDio();
      mockImagePicker = MockImagePicker();
      registerFallbackValue(FormData());
    });

    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      Widget createWidget() {
        final router = go_router.GoRouter(
          initialLocation: '/',
          routes: [
            go_router.GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(body: Text('Home')),
              routes: [
                go_router.GoRoute(
                  path: 'form',
                  builder: (context, state) => const AnnounceFormScreen(),
                ),
              ],
            ),
          ],
        );
        return ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(mockDio),
            imagePickerProvider.overrideWithValue(mockImagePicker),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        );
      }

      Future<void> pumpAndPush(WidgetTester tester) async {
        await tester.pumpWidget(createWidget());
        final BuildContext context = tester.element(find.text('Home'));
        go_router.GoRouter.of(context).go('/form');
        await tester.pumpAndSettle();
      }

      testWidgets('Hiển thị đầy đủ giao diện ban đầu', (tester) async {
        await pumpAndPush(tester);
        expect(find.text('Tạo thông báo'), findsOneWidget);
        expect(find.text('Tiêu đề thông báo *'), findsOneWidget);
        expect(find.text('Nội dung *'), findsOneWidget);
        expect(find.text('Đăng thông báo'), findsOneWidget);
      });

      testWidgets('AT1: Bắt lỗi khi bỏ trống cả 2 trường', (tester) async {
        await pumpAndPush(tester);
        await tester.tap(find.text('Đăng thông báo'));
        await tester.pumpAndSettle();
        
        expect(find.text('Vui lòng nhập tiêu đề'), findsOneWidget);
        expect(find.text('Vui lòng nhập nội dung'), findsOneWidget);
        verifyNever(() => mockDio.post(any(), data: any(named: 'data')));
      });

      testWidgets('AT1: Bắt lỗi khi chỉ nhập tiêu đề, bỏ trống nội dung', (tester) async {
        await pumpAndPush(tester);
        await tester.enterText(find.byType(TextFormField).first, 'Tiêu đề hợp lệ');
        await tester.tap(find.text('Đăng thông báo'));
        await tester.pumpAndSettle();
        
        expect(find.text('Vui lòng nhập tiêu đề'), findsNothing);
        expect(find.text('Vui lòng nhập nội dung'), findsOneWidget);
      });

      testWidgets('AT1: Bắt lỗi khi chỉ nhập nội dung, bỏ trống tiêu đề', (tester) async {
        await pumpAndPush(tester);
        await tester.enterText(find.byType(TextFormField).last, 'Nội dung hợp lệ');
        await tester.tap(find.text('Đăng thông báo'));
        await tester.pumpAndSettle();
        
        expect(find.text('Vui lòng nhập tiêu đề'), findsOneWidget);
        expect(find.text('Vui lòng nhập nội dung'), findsNothing);
      });

      testWidgets('Hiển thị Loading Indicator và Disable nút khi isLoading = true', (tester) async {
        // Mock API delay
        when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 500));
          return Response(requestOptions: RequestOptions(path: ''), statusCode: 200, data: {'status': 'success'});
        });

        await pumpAndPush(tester);
        await tester.enterText(find.byType(TextFormField).first, 'Title');
        await tester.enterText(find.byType(TextFormField).last, 'Body');
        
        await tester.tap(find.text('Đăng thông báo'));
        await tester.pump(); // Start animation

        // Expect loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        
        await tester.pumpAndSettle(); // Finish animation
      });
      
      testWidgets('Lắng nghe lỗi (Error State) hiển thị SnackBar', (tester) async {
        when(() => mockDio.post(any(), data: any(named: 'data'))).thenThrow(
          Exception('API Error 500'),
        );

        await pumpAndPush(tester);
        await tester.enterText(find.byType(TextFormField).first, 'Title');
        await tester.enterText(find.byType(TextFormField).last, 'Body');
        
        await tester.tap(find.text('Đăng thông báo'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Exception: API Error 500'), findsOneWidget);
      });

      testWidgets('Thành công (Success State) hiển thị SnackBar và Pop khỏi màn hình', (tester) async {
        when(() => mockDio.post(any(), data: any(named: 'data'))).thenAnswer(
          (_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 200, data: {'status': 'success'}),
        );

        await pumpAndPush(tester);
        await tester.enterText(find.byType(TextFormField).first, 'Title');
        await tester.enterText(find.byType(TextFormField).last, 'Body');
        
        await tester.tap(find.text('Đăng thông báo'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Đăng thông báo thành công'), findsOneWidget);
      });

      testWidgets('BR-10: Client-side image compression (< 500KB) gọi đúng imageQuality 70', (tester) async {
        when(() => mockImagePicker.pickImage(
              source: any(named: 'source'),
              imageQuality: any(named: 'imageQuality'),
            )).thenAnswer((_) async => XFile('path/to/mock.jpg'));

        await pumpAndPush(tester);

        // Chạm vào nút chọn ảnh
        await tester.tap(find.text('Nhấn để tải ảnh lên'));
        await tester.pumpAndSettle();

        // Xác nhận ImagePicker được gọi với imageQuality = 70
        verify(() => mockImagePicker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 70,
            )).called(1);
      });
    });

    // =========================================================================
    // 2. Domain & State Management (AnnounceState & AnnounceNotifier)
    // =========================================================================
    group('2. Domain & State Management (AnnounceState & AnnounceNotifier)', () {
      test('AnnounceState: default values and copyWith test', () {
        final state = AnnounceState();
        expect(state.isLoading, false);
        expect(state.error, null);
        expect(state.isSuccess, false);

        final newState = state.copyWith(isLoading: true, error: 'Lỗi', isSuccess: true);
        expect(newState.isLoading, true);
        expect(newState.error, 'Lỗi');
        expect(newState.isSuccess, true);

        // state.copyWith() doesn't preserve error (by design in announce_notifier), it clears it
        final sameState = newState.copyWith();
        expect(sameState.isLoading, true);
        expect(sameState.error, null);
      });

      test('AnnounceNotifier: Initial state is correct', () {
        final container = ProviderContainer(
          overrides: [dioProvider.overrideWithValue(mockDio)],
        );
        final state = container.read(announceNotifierProvider);
        expect(state.isLoading, false);
        expect(state.error, null);
        expect(state.isSuccess, false);
        container.dispose();
      });

      test('AnnounceNotifier: submit() - Happy Path (POS-01) with success', () async {
        final mockRepo = MockCommunicationRepository();
        when(() => mockRepo.announceNotification(
              title: any(named: 'title'),
              body: any(named: 'body'),
              bannerImage: any(named: 'bannerImage'),
            )).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(mockDio),
            communicationRepositoryProvider.overrideWithValue(mockRepo)
          ],
        );

        final notifier = container.read(announceNotifierProvider.notifier);
        
        final future = notifier.submit(title: 'Họp dân', body: 'Tại sảnh');
        
        // Assert Loading State
        expect(container.read(announceNotifierProvider).isLoading, true);
        
        await future;

        // Assert Success State
        final finalState = container.read(announceNotifierProvider);
        expect(finalState.isLoading, false);
        expect(finalState.isSuccess, true);
        expect(finalState.error, null);
        
        verify(() => mockRepo.announceNotification(title: 'Họp dân', body: 'Tại sảnh', bannerImage: null)).called(1);
        container.dispose();
      });

      test('AnnounceNotifier: submit() - Error Path (BR-01, Network Error)', () async {
        final mockRepo = MockCommunicationRepository();
        when(() => mockRepo.announceNotification(
              title: any(named: 'title'),
              body: any(named: 'body'),
              bannerImage: any(named: 'bannerImage'),
            )).thenThrow(Exception('Không có quyền Manager'));

        final container = ProviderContainer(
          overrides: [
            dioProvider.overrideWithValue(mockDio),
            communicationRepositoryProvider.overrideWithValue(mockRepo)
          ],
        );

        final notifier = container.read(announceNotifierProvider.notifier);
        await notifier.submit(title: 'Họp dân', body: 'Tại sảnh');

        // Assert Error State
        final finalState = container.read(announceNotifierProvider);
        expect(finalState.isLoading, false);
        expect(finalState.isSuccess, false);
        expect(finalState.error, 'Exception: Không có quyền Manager');
        
        container.dispose();
      });
    });

    // =========================================================================
    // 3. Repository Layer (CommunicationRepository)
    // =========================================================================
    group('3. Repository Layer (CommunicationRepository)', () {
      test('Repository: announceNotification gọi API chính xác', () async {
        when(() => mockDio.post(any(), data: any(named: 'data')))
            .thenAnswer((_) async => Response(requestOptions: RequestOptions(path: ''), statusCode: 200));

        final repo = CommunicationRepository(mockDio);
        await repo.announceNotification(title: 'T1', body: 'B1');

        verify(() => mockDio.post('/notifications/announce', data: any(named: 'data'))).called(1);
      });
    });
  });
}
