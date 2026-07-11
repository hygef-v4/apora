import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../models/manager_detail.dart';
import '../models/manager_member.dart';
import '../models/manager_stats.dart';

/// Combined result for UC41: manager list + aggregate statistics in one response.
class ManagerListResult {
  const ManagerListResult({required this.managers, required this.stats});

  final List<ManagerMember> managers;
  final ManagerStats stats;
}

/// Network service connecting the Flutter client to the Next.js Manager REST API.
///
/// Endpoints: `GET /api/managers` (UC41), `GET /api/managers/:id` (UC42).
/// Access restricted to LANDLORD — backend enforces 403, client only navigates.
class ManagerAPIService {
  ManagerAPIService(this._dio);

  final Dio _dio;

  static const String _base = '/managers';

  /// Fetches the Manager list with optional status filter and search keyword (UC41).
  ///
  /// [status] — 'ACTIVE' | 'INACTIVE' | null (all).
  /// [search] — Keyword matching full_name or phone_number.
  /// Returns [ManagerListResult] containing both the list and statistics.
  Future<ManagerListResult> getManagerList({
    String? status,
    String? search,
  }) async {
    final res = await _dio.get(_base, queryParameters: {
      'status': ?status,
      'search': ?search,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    return ManagerListResult(
      managers: (data['managers'] as List<dynamic>)
          .map((e) => ManagerMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      stats: ManagerStats.fromJson(data['stats'] as Map<String, dynamic>),
    );
  }

  /// Fetches detailed profile of a specific Manager account (UC42).
  ///
  /// [id] — The Manager's user ID.
  /// Returns [ManagerDetail] with profile, contact info, and management history.
  Future<ManagerDetail> getManagerDetail(int id) async {
    final res = await _dio.get('$_base/$id');
    return ManagerDetail.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}

/// Riverpod provider for [ManagerAPIService], injected with the shared Dio client.
final managerApiServiceProvider = Provider<ManagerAPIService>(
  (ref) => ManagerAPIService(ref.watch(dioProvider)),
);
