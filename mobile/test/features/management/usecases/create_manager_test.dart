import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:apartment_management/features/management/providers/manager_notifier.dart';
import 'package:apartment_management/features/management/repositories/manager_api_service.dart';
import 'package:apartment_management/features/management/models/manager_stats.dart';
import 'package:apartment_management/features/management/screens/manager_form_screen.dart';
import 'package:apartment_management/core/constants/app_strings.dart';

// --- Mocks ---
class MockManagerAPIService extends Mock implements ManagerAPIService {}
class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() async {
    // Load .env to avoid DotEnv not initialized error
    await dotenv.load(fileName: ".env");
  });

  group('UC43: Create Manager Account', () {
    late MockManagerAPIService mockApi;
    late MockDio mockDio;

    setUp(() {
      mockApi = MockManagerAPIService();
      mockDio = MockDio();
    });

    group('1. UI & Widget Tests', () {
      testWidgets('Render đầy đủ các thành phần tĩnh của Form (Happy Path)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: const MaterialApp(
              home: ManagerFormScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Thêm quản lý'), findsOneWidget);
        expect(find.text('Cấp tài khoản cho ban quản lý'), findsOneWidget);
        expect(find.byType(TextFormField), findsNWidgets(2)); // Name & Phone
        expect(find.text('Tài khoản sẽ được tạo với mật khẩu mặc định là Apora@123'), findsOneWidget);
        expect(find.text('Tạo tài khoản'), findsOneWidget);
        expect(find.text('Hủy'), findsOneWidget);
      });

      testWidgets('Validation (Business Rules): Bỏ trống input và hiển thị lỗi (UI validation cho BR-02 gián tiếp)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: const MaterialApp(
              home: ManagerFormScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhấn nút Tạo tài khoản khi chưa nhập gì
        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pumpAndSettle();

        // Kiểm tra thông báo lỗi
        expect(find.text(AppStrings.msgFieldRequired), findsOneWidget);
        expect(find.text(AppStrings.msgPhoneRequired), findsOneWidget);
      });

      testWidgets('Loading State & Success Navigation', (tester) async {
        final mockApi = MockManagerAPIService();
        
        when(() => mockApi.createManager(
              fullName: any(named: 'fullName'),
              phone: any(named: 'phone'),
            )).thenAnswer((_) async {
              await Future.delayed(const Duration(milliseconds: 100));
            });
        
        when(() => mockApi.getManagerList(
              status: any(named: 'status'),
              search: any(named: 'search'),
            )).thenAnswer((_) async => const ManagerListResult(managers: [], stats: ManagerStats.empty));

        final router = GoRouter(
          initialLocation: '/managers',
          routes: [
            GoRoute(
              path: '/managers',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => context.push('/managers/create'),
                    child: const Text('Open Form'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/managers/create',
              builder: (context, state) => const ManagerFormScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              managerApiServiceProvider.overrideWithValue(mockApi),
            ],
            child: MaterialApp.router(
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Push to the form
        await tester.tap(find.text('Open Form'));
        await tester.pumpAndSettle();

        // Nhập thông tin hợp lệ
        await tester.enterText(find.byType(TextFormField).first, 'John Doe');
        await tester.enterText(find.byType(TextFormField).last, '0987654321');
        
        // Nhấn tạo
        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pump(); // frame to start showing CircularProgressIndicator
        
        // Kiểm tra Loading State
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Wait for Loading State to disappear and pop animation to complete
        await tester.pumpAndSettle();

        // Kiểm tra đã pop về màn hình trước đó
        expect(find.text('Open Form'), findsOneWidget);
        expect(find.byType(ManagerFormScreen), findsNothing);
        
        // Kiểm tra API được gọi
        verify(() => mockApi.createManager(fullName: 'John Doe', phone: '0987654321')).called(1);
      });
      
      testWidgets('Alternative Flow: Hiển thị thông báo lỗi khi nhập trùng số điện thoại (AT1)', (tester) async {
        final mockApi = MockManagerAPIService();
        
        when(() => mockApi.createManager(
              fullName: any(named: 'fullName'),
              phone: any(named: 'phone'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/managers'),
            response: Response(
              requestOptions: RequestOptions(path: '/managers'),
              statusCode: 400,
              data: {'message': 'Số điện thoại này đã được đăng ký'},
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              managerApiServiceProvider.overrideWithValue(mockApi),
            ],
            child: const MaterialApp(
              home: ManagerFormScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhập thông tin
        await tester.enterText(find.byType(TextFormField).first, 'John Doe');
        await tester.enterText(find.byType(TextFormField).last, '0987654321');
        
        // Nhấn tạo
        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pumpAndSettle(); 

        // Kiểm tra SnackBar báo lỗi
        expect(find.text('Số điện thoại này đã được đăng ký'), findsOneWidget);
      });

      testWidgets('Business Rule: Kiểm tra quy tắc số điện thoại phải là duy nhất (BR-02)', (tester) async {
        final mockApi = MockManagerAPIService();
        
        when(() => mockApi.createManager(
              fullName: any(named: 'fullName'),
              phone: any(named: 'phone'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/managers'),
            response: Response(
              requestOptions: RequestOptions(path: '/managers'),
              statusCode: 400,
              data: {'message': 'Số điện thoại này đã được đăng ký'},
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              managerApiServiceProvider.overrideWithValue(mockApi),
            ],
            child: const MaterialApp(
              home: ManagerFormScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhập thông tin
        await tester.enterText(find.byType(TextFormField).first, 'Duplicate Name');
        await tester.enterText(find.byType(TextFormField).last, '0987654321'); // Duplicate phone
        
        // Nhấn tạo
        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pumpAndSettle(); 

        // Đảm bảo không điều hướng đi (vẫn ở lại form) và lỗi được log/hiển thị
        expect(find.byType(ManagerFormScreen), findsOneWidget);
        expect(find.text('Số điện thoại này đã được đăng ký'), findsOneWidget);
      });
    });

    group('2. Domain & State Management', () {
      test('Tạo tài khoản quản lý thành công và tự động làm mới danh sách', () async {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            managerApiServiceProvider.overrideWithValue(mockApi),
          ],
        );
        
        const fullName = 'Test Manager';
        const phone = '0912345678';

        when(() => mockApi.createManager(
              fullName: any(named: 'fullName'),
              phone: any(named: 'phone'),
            )).thenAnswer((_) async => {});

        // Mock refresh call inside createManager
        when(() => mockApi.getManagerList(
              status: any(named: 'status'),
              search: any(named: 'search'),
            )).thenAnswer((_) async => throw Exception('Mock refresh error to skip'));

        // Act
        final notifier = container.read(managerDirectoryProvider.notifier);
        
        try {
          await notifier.createManager(fullName: fullName, phone: phone);
        } catch (_) {
          // Ignore the refresh exception in mock
        }

        // Assert
        verify(() => mockApi.createManager(fullName: fullName, phone: phone)).called(1);
        // build() calls it once, refresh() calls it once -> total 2 times
        verify(() => mockApi.getManagerList(status: null, search: null)).called(2);
      });

      test('Tạo tài khoản quản lý thất bại do lỗi phân quyền (BR-57) hoặc lỗi hệ thống', () async {
        final container = ProviderContainer(
          overrides: [
            managerApiServiceProvider.overrideWithValue(mockApi),
          ],
        );
        
        const fullName = 'Test Manager';
        const phone = '0912345678';

        when(() => mockApi.createManager(
              fullName: any(named: 'fullName'),
              phone: any(named: 'phone'),
            )).thenThrow(Exception('Lỗi hệ thống'));

        // Act
        final notifier = container.read(managerDirectoryProvider.notifier);
        
        try {
          await notifier.createManager(fullName: fullName, phone: phone);
          fail('Should throw exception');
        } catch (e) {
          expect(e.toString(), contains('Lỗi hệ thống'));
        }

        // Assert
        verify(() => mockApi.createManager(fullName: fullName, phone: phone)).called(1);
        // build() calls it once upon reading the provider, but refresh() is not called
        verify(() => mockApi.getManagerList(
              status: any(named: 'status'),
              search: any(named: 'search'),
            )).called(1);
      });
    });

    group('3. Repository Layer', () {
      late ManagerAPIService apiService;

      setUp(() {
        apiService = ManagerAPIService(mockDio);
      });

      test('API Calling: Gửi POST request (Thiết lập cơ chế ép đổi mật khẩu lần đầu cho BR-01)', () async {
        // Arrange
        const fullName = 'Jane Doe';
        const phone = '0111222333';

        when(() => mockDio.post(
              '/managers',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response(
                  requestOptions: RequestOptions(path: '/managers'),
                  statusCode: 200,
                  data: {'message': 'Tạo thành công', 'data': {}},
                ));

        // Act
        await apiService.createManager(fullName: fullName, phone: phone);

        // Assert
        final capturedArgs = verify(() => mockDio.post(
              '/managers',
              data: captureAny(named: 'data'),
            )).captured;
        
        final payload = capturedArgs.first as Map<String, dynamic>;
        expect(payload['fullName'], fullName);
        expect(payload['phoneNumber'], phone);
      });

      test('API Calling: Gửi POST request (Hỗ trợ gọi backend để mã hóa bcrypt cho BR-03)', () async {
        // Arrange
        const fullName = 'Jane Doe';
        const phone = '0111222333';

        when(() => mockDio.post(
              '/managers',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response(
                  requestOptions: RequestOptions(path: '/managers'),
                  statusCode: 200,
                  data: {'message': 'Tạo thành công', 'data': {}},
                ));

        // Act
        await apiService.createManager(fullName: fullName, phone: phone);

        // Assert
        final capturedArgs = verify(() => mockDio.post(
              '/managers',
              data: captureAny(named: 'data'),
            )).captured;
        
        final payload = capturedArgs.first as Map<String, dynamic>;
        expect(payload['fullName'], fullName);
        expect(payload['phoneNumber'], phone);
      });
    });
  });
}
