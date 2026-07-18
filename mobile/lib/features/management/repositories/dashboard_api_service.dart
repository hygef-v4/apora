import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../models/dashboard_stats.dart';

/// Service gọi REST API /api/dashboard (Module 7, UC35).
class DashboardAPIService {
  DashboardAPIService(this._dio);

  final Dio _dio;

  static const String _base = '/dashboard';

  /// UC35: Lấy số liệu thống kê Dashboard theo tháng (MM/YYYY)
  Future<DashboardStats> getMetrics(String monthYear) async {
    final res = await _dio.get(_base, queryParameters: {
      'monthYear': monthYear,
    });
    return DashboardStats.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}

final dashboardApiServiceProvider = Provider<DashboardAPIService>((ref) {
  return DashboardAPIService(ref.watch(dioProvider));
});
