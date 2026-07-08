import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../models/staff_detail.dart';
import '../models/staff_member.dart';
import '../models/staff_stats.dart';

/// Kết quả UC36: danh sách + thống kê trong 1 response.
class StaffListResult {
  const StaffListResult({required this.staff, required this.stats});

  final List<StaffMember> staff;
  final StaffStats stats;
}

/// Service gọi REST API /api/staff/** (Module 8, UC36-UC40).
/// Chỉ MANAGER/LANDLORD có quyền - backend enforce, client chỉ điều hướng.
class StaffAPIService {
  StaffAPIService(this._dio);

  final Dio _dio;

  static const String _base = '/staff';

  Future<StaffListResult> getStaffList({String? status, String? search}) async {
    final res = await _dio.get(_base, queryParameters: {
      'status': ?status,
      'search': ?search,
    });
    final data = res.data['data'] as Map<String, dynamic>;
    return StaffListResult(
      staff: (data['staff'] as List<dynamic>)
          .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      stats: StaffStats.fromJson(data['stats'] as Map<String, dynamic>),
    );
  }

  Future<StaffDetail> getStaffDetail(int id) async {
    final res = await _dio.get('$_base/$id');
    return StaffDetail.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  Future<StaffMember> createStaff({
    required String fullName,
    required String phone,
    required String password,
    required String role,
  }) async {
    final res = await _dio.post(_base, data: {
      'fullName': fullName,
      'phone': phone,
      'password': password,
      'role': role,
    });
    return StaffMember.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// [avatarBytes] đã nén < 500KB (BR-10) trước khi truyền vào.
  Future<StaffMember> updateStaff(
    int id, {
    required String fullName,
    required String phone,
    required String role,
    Uint8List? avatarBytes,
  }) async {
    final form = FormData.fromMap({
      'fullName': fullName,
      'phone': phone,
      'role': role,
      if (avatarBytes != null)
        'avatar': MultipartFile.fromBytes(avatarBytes, filename: 'avatar.jpg'),
    });
    final res = await _dio.put('$_base/$id', data: form);
    return StaffMember.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// UC40 - backend trả 409 khi còn task đang mở (BR-50).
  Future<void> deactivateStaff(int id, {String? reason}) async {
    await _dio.put('$_base/$id/status', data: {'reason': ?reason});
  }

  Future<void> resetPassword(int id, String newPassword) async {
    await _dio.put('$_base/$id/reset-password', data: {'newPassword': newPassword});
  }
}

final staffApiServiceProvider =
    Provider<StaffAPIService>((ref) => StaffAPIService(ref.watch(dioProvider)));
