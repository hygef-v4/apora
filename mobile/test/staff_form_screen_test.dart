import 'package:apartment_management/features/management/models/staff_member.dart';
import 'package:apartment_management/features/management/models/staff_stats.dart';
import 'package:apartment_management/features/management/repositories/staff_api_service.dart';
import 'package:apartment_management/features/management/screens/staff_form_screen.dart';
import 'package:dio/dio.dart';
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

  /// Điền tên + SĐT rồi chọn vai trò trong dropdown.
  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'Pham Van Lao Cong',
    String phone = '0900000006',
    String role = 'Janitor',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. Jane Doe'),
      name,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'e.g. 0912345678'),
      phone,
    );
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(role).last);
    await tester.pumpAndSettle();
  }

  group('StaffFormScreen - UC38 (FID-37)', () {
    testWidgets('bỏ trống trường bắt buộc -> lỗi inline, chặn submit',
        (tester) async {
      await tester.pumpWidget(buildTestApp());

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.text('Please enter a phone number.'), findsOneWidget);
      expect(find.text('Please select a role.'), findsOneWidget);
      verifyNever(() => mockApi.createStaff(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            role: any(named: 'role'),
          ));
    });

    testWidgets('SĐT sai định dạng -> lỗi inline (BR-02)', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await fillForm(tester, phone: '12345');

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(
        find.text('Invalid phone number. Enter 10 digits starting with 0.'),
        findsOneWidget,
      );
      verifyNever(() => mockApi.createStaff(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            role: any(named: 'role'),
          ));
    });

    testWidgets(
        'nhập đủ + chọn vai trò -> gọi API với mật khẩu mặc định tự sinh (BR-01/BR-09)',
        (tester) async {
      when(() => mockApi.createStaff(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            role: any(named: 'role'),
          )).thenAnswer((_) async => const StaffMember(
            id: 6,
            fullName: 'Pham Van Lao Cong',
            phoneNumber: '0900000006',
            role: 'JANITOR',
            status: 'ACTIVE',
            openTaskCount: 0,
          ));

      await tester.pumpWidget(buildTestApp());
      await fillForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      final captured = verify(() => mockApi.createStaff(
            fullName: 'Pham Van Lao Cong',
            phone: '0900000006',
            password: captureAny(named: 'password'),
            role: 'JANITOR',
          )).captured;
      expect(captured, hasLength(1));

      // Mật khẩu do app sinh, phải thỏa BR-09: >= 8 ký tự, có chữ hoa + chữ số
      final password = captured.single as String;
      expect(password.length, greaterThanOrEqualTo(8));
      expect(password, matches(RegExp(r'[A-Z]')));
      expect(password, matches(RegExp(r'[0-9]')));

      // Mật khẩu được bàn giao cho Manager đúng một lần qua dialog
      expect(find.text('Staff account created'), findsOneWidget);
      expect(find.text(password), findsOneWidget);
    });

    testWidgets('SĐT trùng (409) -> lỗi inline dưới ô SĐT, không dùng SnackBar',
        (tester) async {
      when(() => mockApi.createStaff(
            fullName: any(named: 'fullName'),
            phone: any(named: 'phone'),
            password: any(named: 'password'),
            role: any(named: 'role'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/staff'),
        response: Response(
          requestOptions: RequestOptions(path: '/staff'),
          statusCode: 409,
        ),
      ));

      await tester.pumpWidget(buildTestApp());
      await fillForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Phone number already exists'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
