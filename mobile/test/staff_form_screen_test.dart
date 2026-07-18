import 'package:apartment_management/core/constants/app_strings.dart';
import 'package:apartment_management/features/management/models/staff_member.dart';
import 'package:apartment_management/features/management/models/staff_stats.dart';
import 'package:apartment_management/features/management/repositories/staff_api_service.dart';
import 'package:apartment_management/features/management/screens/staff_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStaffAPIService extends Mock implements StaffAPIService {}

void main() {
  late MockStaffAPIService mockApi;

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [staffApiServiceProvider.overrideWithValue(mockApi)],
      child: const MaterialApp(home: StaffFormScreen()),
    );
  }

  setUp(() {
    mockApi = MockStaffAPIService();
    when(() => mockApi.getStaffList(
          status: any(named: 'status'),
          search: any(named: 'search'),
        )).thenAnswer(
      (_) async => const StaffListResult(staff: [], stats: StaffStats.empty),
    );
  });

  group('StaffFormScreen - UC38 (FID-37)', () {
    testWidgets('bỏ trống trường bắt buộc -> lỗi inline, chặn submit',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      await tester.tap(find.text('Tạo tài khoản'));
      await tester.pump();

      expect(find.text(AppStrings.msgFieldRequired), findsWidgets);
      expect(find.text(AppStrings.msgPhoneRequired), findsOneWidget);
      expect(find.text('Vui lòng chọn vai trò.'), findsOneWidget);
      verifyNever(() => mockApi.createStaff(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            role: any(named: 'role'),
          ));
    });

    testWidgets('mật khẩu xác nhận không khớp -> báo lỗi', (tester) async {
      await tester.pumpWidget(buildTestApp());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Họ và tên'),
        'Phạm Văn Lao Công',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại (dùng để đăng nhập)'),
        '0900000006',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu ban đầu'),
        'Apora@123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
        'KhacNhau@1',
      );

      await tester.tap(find.text('Tạo tài khoản'));
      await tester.pump();

      expect(find.text(AppStrings.msgPasswordMismatch), findsOneWidget);
    });

    testWidgets('nhập đủ + chọn vai trò -> gọi API tạo nhân viên',
        (tester) async {
      when(() => mockApi.createStaff(
            fullName: 'Phạm Văn Lao Công',
            phone: '0900000006',
            password: 'Apora@123',
            role: 'JANITOR',
          )).thenAnswer((_) async => const StaffMember(
            id: 6,
            fullName: 'Phạm Văn Lao Công',
            phoneNumber: '0900000006',
            role: 'JANITOR',
            status: 'ACTIVE',
            openTaskCount: 0,
          ));

      await tester.pumpWidget(buildTestApp());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Họ và tên'),
        'Phạm Văn Lao Công',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Số điện thoại (dùng để đăng nhập)'),
        '0900000006',
      );
      // Chọn vai trò từ dropdown
      await tester.tap(find.text('Vai trò'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lao công').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu ban đầu'),
        'Apora@123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
        'Apora@123',
      );

      await tester.tap(find.text('Tạo tài khoản'));
      await tester.pumpAndSettle();

      verify(() => mockApi.createStaff(
            fullName: 'Phạm Văn Lao Công',
            phone: '0900000006',
            password: 'Apora@123',
            role: 'JANITOR',
          )).called(1);
    });
  });
}
