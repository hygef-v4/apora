import 'package:apartment_management/features/management/models/staff_member.dart';
import 'package:apartment_management/features/management/models/staff_stats.dart';
import 'package:apartment_management/features/management/providers/staff_notifier.dart';
import 'package:apartment_management/features/management/repositories/staff_api_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStaffAPIService extends Mock implements StaffAPIService {}

void main() {
  late MockStaffAPIService mockApi;
  late ProviderContainer container;

  const staffList = [
    StaffMember(
      id: 4,
      fullName: 'Trần Văn Kỹ Thuật',
      phoneNumber: '0900000004',
      role: 'TECHNICIAN',
      status: 'ACTIVE',
      openTaskCount: 2,
    ),
    StaffMember(
      id: 5,
      fullName: 'Lê Văn Bảo Vệ',
      phoneNumber: '0900000005',
      role: 'SECURITY_GUARD',
      status: 'INACTIVE',
      openTaskCount: 0,
    ),
  ];
  const stats = StaffStats(total: 2, active: 1, inactive: 1, openTasks: 2);

  setUp(() {
    mockApi = MockStaffAPIService();
    container = ProviderContainer(
      overrides: [staffApiServiceProvider.overrideWithValue(mockApi)],
    );
    addTearDown(container.dispose);
  });

  group('StaffDirectoryNotifier - UC36', () {
    test('tải danh sách thành công: đúng số nhân viên và thống kê', () async {
      when(() => mockApi.getStaffList(status: null, search: null)).thenAnswer(
        (_) async => const StaffListResult(staff: staffList, stats: stats),
      );

      final result = await container.read(staffDirectoryProvider.future);

      expect(result.staff.length, 2);
      expect(result.staff.first.fullName, 'Trần Văn Kỹ Thuật');
      expect(result.stats.total, 2);
      expect(result.stats.openTasks, 2);
    });

    test('lọc theo trạng thái ACTIVE gọi API với đúng tham số', () async {
      when(() => mockApi.getStaffList(
            status: any(named: 'status'),
            search: any(named: 'search'),
          )).thenAnswer(
        (_) async => const StaffListResult(staff: [], stats: StaffStats.empty),
      );

      await container.read(staffDirectoryProvider.future);
      await container
          .read(staffDirectoryProvider.notifier)
          .setStatusFilter('ACTIVE');

      verify(() => mockApi.getStaffList(status: 'ACTIVE', search: null))
          .called(1);
    });
  });

  group('StaffDirectoryNotifier - UC38 Create', () {
    test('tạo nhân viên gọi API đúng tham số rồi refresh danh sách', () async {
      when(() => mockApi.getStaffList(
            status: any(named: 'status'),
            search: any(named: 'search'),
          )).thenAnswer(
        (_) async => const StaffListResult(staff: staffList, stats: stats),
      );
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

      await container.read(staffDirectoryProvider.future);
      await container.read(staffDirectoryProvider.notifier).createStaff(
            fullName: 'Phạm Văn Lao Công',
            phone: '0900000006',
            password: 'Apora@123',
            role: 'JANITOR',
          );

      verify(() => mockApi.createStaff(
            fullName: 'Phạm Văn Lao Công',
            phone: '0900000006',
            password: 'Apora@123',
            role: 'JANITOR',
          )).called(1);
    });
  });

  group('StaffDirectoryNotifier - UC40 Deactivate (BR-50)', () {
    test('backend chặn 409 khi còn task mở -> ném lỗi cho UI', () async {
      when(() => mockApi.getStaffList(
            status: any(named: 'status'),
            search: any(named: 'search'),
          )).thenAnswer(
        (_) async => const StaffListResult(staff: staffList, stats: stats),
      );
      when(() => mockApi.deactivateStaff(4, reason: any(named: 'reason')))
          .thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/staff/4/status'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/staff/4/status'),
            statusCode: 409,
            data: {
              'status': 'error',
              'message':
                  'Nhân viên còn 2 công việc chưa xử lý. Vui lòng phân công lại trước khi vô hiệu hóa.',
            },
          ),
        ),
      );

      await container.read(staffDirectoryProvider.future);

      await expectLater(
        container.read(staffDirectoryProvider.notifier).deactivateStaff(4),
        throwsA(isA<DioException>()),
      );
    });
  });
}
