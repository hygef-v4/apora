import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_stats.dart';
import '../repositories/dashboard_api_service.dart';

/// Notifier quản lý trạng thái của Báo cáo thống kê Dashboard (UC35).
/// Lưu bộ lọc tháng hiện tại và tải lại dữ liệu tương ứng.
class DashboardNotifier extends AsyncNotifier<DashboardStats> {
  late String _monthYear;

  /// Bộ lọc tháng hiện tại ở dạng MM/YYYY
  String get monthYear => _monthYear;

  @override
  Future<DashboardStats> build() async {
    final now = DateTime.now();
    _monthYear = '${now.month.toString().padLeft(2, '0')}/${now.year}';
    return ref.read(dashboardApiServiceProvider).getMetrics(_monthYear);
  }

  /// UC35: Thay đổi bộ lọc tháng và tải lại số liệu
  Future<void> changeMonth(String newMonthYear) async {
    _monthYear = newMonthYear;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(dashboardApiServiceProvider).getMetrics(newMonthYear);
    });
  }

  /// UC35: Làm mới dữ liệu cho tháng hiện tại
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return ref.read(dashboardApiServiceProvider).getMetrics(_monthYear);
    });
  }
}

final dashboardProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardStats>(
  DashboardNotifier.new,
);
