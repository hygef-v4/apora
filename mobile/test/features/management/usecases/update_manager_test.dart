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
import 'package:apartment_management/features/management/models/manager_member.dart';
import 'package:apartment_management/features/management/screens/manager_form_screen.dart';
import 'package:apartment_management/core/constants/app_strings.dart';

// --- Mocks ---
class MockManagerAPIService extends Mock implements ManagerAPIService {}
class MockDio extends Mock implements Dio {}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  group('UC44: Update Manager Account', () {
    late MockManagerAPIService mockApi;
    final testManager = ManagerMember(
      id: 1,
      fullName: 'Old Name',
      phoneNumber: '0987654321',
      avatarUrl: null,
      status: 'ACTIVE',
    );

    setUp(() {
      mockApi = MockManagerAPIService();
    });

    group('1. UI & Widget Tests', () {
      testWidgets('Render đầy đủ các thành phần tĩnh của Form (Happy Path, Edit Mode)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ManagerFormScreen(manager: testManager),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cập nhật quản lý'), findsOneWidget);
        expect(find.text('Chỉnh sửa thông tin tài khoản'), findsOneWidget);
        expect(find.text('Old Name'), findsOneWidget); // Pre-filled name
        expect(find.text('0987654321'), findsOneWidget); // Pre-filled phone
        expect(find.text('Lưu thay đổi'), findsOneWidget);
        expect(find.text('Hủy'), findsOneWidget);
        
        // Không hiển thị hướng dẫn mật khẩu mặc định trong edit mode
        expect(find.text('Tài khoản sẽ được tạo với mật khẩu mặc định là Apora@123'), findsNothing);
      });

      testWidgets('Validation (Business Rules): Bỏ trống input và hiển thị lỗi (AT1)', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: ManagerFormScreen(manager: testManager),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Xóa thông tin
        await tester.enterText(find.byType(TextFormField).first, '');
        await tester.enterText(find.byType(TextFormField).last, '');

        // Nhấn nút Lưu thay đổi
        await tester.tap(find.text('Lưu thay đổi'));
        await tester.pumpAndSettle();

        // Kiểm tra thông báo lỗi
        expect(find.text(AppStrings.msgFieldRequired), findsOneWidget);
        expect(find.text(AppStrings.msgPhoneRequired), findsOneWidget);
      });

      testWidgets('Loading State & Success Navigation (Edit Mode)', (tester) async {
        when(() => mockApi.updateManager(
              id: any(named: 'id'),
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
                    onPressed: () => context.push('/managers/1/edit', extra: testManager),
                    child: const Text('Open Edit Form'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/managers/:id/edit',
              builder: (context, state) {
                final manager = state.extra as dynamic;
                return ManagerFormScreen(manager: manager);
              },
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

        // Push to edit form
        await tester.tap(find.text('Open Edit Form'));
        await tester.pumpAndSettle();

        // Cập nhật thông tin
        await tester.enterText(find.byType(TextFormField).first, 'New Name');
        
        // Nhấn lưu
        await tester.tap(find.text('Lưu thay đổi'));
        await tester.pump(); 
        
        // Kiểm tra Loading State
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Đợi pop animation
        await tester.pumpAndSettle();

        // Đảm bảo không còn ở màn hình form (pop về màn danh sách)
        expect(find.text('Open Edit Form'), findsOneWidget);
        expect(find.byType(ManagerFormScreen), findsNothing);
        
        // Kiểm tra API được gọi
        verify(() => mockApi.updateManager(id: 1, fullName: 'New Name', phone: '0987654321')).called(1);
      });
      
      testWidgets('Alternative Flow: Hiển thị thông báo lỗi khi nhập trùng số điện thoại (AT1/BR-02)', (tester) async {
        when(() => mockApi.updateManager(
              id: any(named: 'id'),
              fullName: any(named: 'fullName'),
              phone: any(named: 'phone'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/managers/1'),
            response: Response(
              requestOptions: RequestOptions(path: '/managers/1'),
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
            child: MaterialApp(
              home: ManagerFormScreen(manager: testManager),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Đổi sđt thành sđt trùng
        await tester.enterText(find.byType(TextFormField).last, '0999999999');
        
        // Nhấn lưu
        await tester.tap(find.text('Lưu thay đổi'));
        await tester.pumpAndSettle(); 

        // Kiểm tra SnackBar báo lỗi
        expect(find.text('Số điện thoại này đã được đăng ký'), findsOneWidget);
        // Vẫn ở lại màn hình
        expect(find.byType(ManagerFormScreen), findsOneWidget);
      });

      testWidgets('Alternative Flow: Hiển thị lỗi phân quyền khi không phải Landlord (BR-57)', (tester) async {
        when(() => mockApi.updateManager(
              id: any(named: 'id'),
              fullName: any(named: 'fullName'),
              phone: any(named: 'phone'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/managers/1'),
            response: Response(
              requestOptions: RequestOptions(path: '/managers/1'),
              statusCode: 403,
              data: {'message': 'Bạn không có quyền thực hiện chức năng này.'},
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              managerApiServiceProvider.overrideWithValue(mockApi),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ManagerFormScreen(manager: testManager),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Nhấn lưu
        await tester.tap(find.text('Lưu thay đổi'));
        await tester.pumpAndSettle(); 

        // Kiểm tra SnackBar báo lỗi phân quyền
        expect(find.text('Bạn không có quyền thực hiện chức năng này.'), findsOneWidget);
      });
    });

    group('2. Domain & State Management', () {
      test('Business Rule: Ghi nhận lịch sử quản lý khi cập nhật thành công (BR-11) (Backend trigger)', () async {
        // Test này đảm bảo notifier gọi đúng method api với tham số chuẩn, 
        // để backend có đủ thông tin ghi nhận audit log (BR-11).
        final container = ProviderContainer(
          overrides: [
            managerApiServiceProvider.overrideWithValue(mockApi),
          ],
        );
        
        when(() => mockApi.updateManager(
              id: 1,
              fullName: 'Updated Name',
              phone: '0987654321',
            )).thenAnswer((_) async => {});

        when(() => mockApi.getManagerList(
              status: any(named: 'status'),
              search: any(named: 'search'),
            )).thenAnswer((_) async => const ManagerListResult(
              managers: [],
              stats: ManagerStats.empty,
            ));

        final notifier = container.read(managerDirectoryProvider.notifier);
        
        await notifier.updateManager(
          1,
          fullName: 'Updated Name',
          phone: '0987654321',
        );

        verify(() => mockApi.updateManager(
              id: 1,
              fullName: 'Updated Name',
              phone: '0987654321',
            )).called(1);
      });
      test('Cập nhật tài khoản quản lý thành công và tự động làm mới danh sách', () async {
        final container = ProviderContainer(
          overrides: [
            managerApiServiceProvider.overrideWithValue(mockApi),
          ],
        );
        
        const newName = 'New Manager Name';
        const newPhone = '0911111111';

        when(() => mockApi.updateManager(
              id: 1,
              fullName: newName,
              phone: newPhone,
            )).thenAnswer((_) async => {});

        when(() => mockApi.getManagerList(
              status: any(named: 'status'),
              search: any(named: 'search'),
            )).thenAnswer((_) async => const ManagerListResult(
              managers: [],
              stats: ManagerStats.empty,
            ));

        final notifier = container.read(managerDirectoryProvider.notifier);
        
        await notifier.updateManager(
          1,
          fullName: newName,
          phone: newPhone,
        );

        verify(() => mockApi.updateManager(
              id: 1,
              fullName: newName,
              phone: newPhone,
            )).called(1);

        verify(() => mockApi.getManagerList(
              status: null,
              search: null,
            )).called(2); // 1 for initial build, 1 for refresh
      });

      test('Cập nhật tài khoản quản lý thất bại thì throw error và không làm mới danh sách', () async {
        final container = ProviderContainer(
          overrides: [
            managerApiServiceProvider.overrideWithValue(mockApi),
          ],
        );
        
        when(() => mockApi.updateManager(
              id: 1,
              fullName: any(named: 'fullName'),
              phone: any(named: 'phone'),
            )).thenThrow(Exception('Update error'));

        when(() => mockApi.getManagerList(
              status: any(named: 'status'),
              search: any(named: 'search'),
            )).thenAnswer((_) async => const ManagerListResult(
              managers: [],
              stats: ManagerStats.empty,
            ));

        final notifier = container.read(managerDirectoryProvider.notifier);
        
        // Đợi một chút để Provider khởi tạo (build được gọi)
        await container.read(managerDirectoryProvider.future);

        // Xóa log gọi api của build()
        clearInteractions(mockApi);

        expect(
          () => notifier.updateManager(
            1,
            fullName: 'New',
            phone: '0911111111',
          ),
          throwsException,
        );

        // Ensure refresh was not called since it failed
        verifyNever(() => mockApi.getManagerList(
              status: any(named: 'status'),
              search: any(named: 'search'),
            ));
      });
    });

    group('3. API Repository Layer', () {
      late MockDio mockDio;
      late ManagerAPIService apiService;

      setUp(() {
        mockDio = MockDio();
        apiService = ManagerAPIService(mockDio);
      });

      test('updateManager() calls PUT /managers/:id with correct payload', () async {
        when(() => mockDio.put(
              '/managers/1',
              data: any(named: 'data'),
            )).thenAnswer(
          (_) async => Response(
            requestOptions: RequestOptions(path: '/managers/1'),
            statusCode: 200,
            data: {'success': true},
          ),
        );

        await apiService.updateManager(
          id: 1,
          fullName: 'New Name',
          phone: '0999999999',
        );

        verify(() => mockDio.put(
              '/managers/1',
              data: {
                'fullName': 'New Name',
                'phoneNumber': '0999999999',
              },
            )).called(1);
      });
      
      test('updateManager() throws exception when API returns error', () async {
        when(() => mockDio.put(
              '/managers/1',
              data: any(named: 'data'),
            )).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/managers/1'),
            response: Response(
              requestOptions: RequestOptions(path: '/managers/1'),
              statusCode: 500,
            ),
          ),
        );

        expect(
          () => apiService.updateManager(
            id: 1,
            fullName: 'Name',
            phone: '123',
          ),
          throwsA(isA<DioException>()),
        );
      });
    });
  });
}
