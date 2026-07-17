import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../models/apartment.dart';

/// Service gọi REST API /api/apartments/** (Module 6, UC29-UC32).
class ApartmentAPIService {
  ApartmentAPIService(this._dio);

  final Dio _dio;

  static const String _base = '/apartments';

  /// UC29: Lấy danh sách căn hộ kèm thống kê
  Future<List<Apartment>> getApartments({String? status, String? search}) async {
    final res = await _dio.get(_base, queryParameters: {
      if (status != null && status != 'ALL') 'status': status,
      if (search != null && search.trim().isNotEmpty) 'search': search,
    });
    final data = res.data['data'] as List<dynamic>;
    return data.map((e) => Apartment.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// UC30: Lấy chi tiết căn hộ
  Future<ApartmentDetail> getApartmentDetail(int id) async {
    final res = await _dio.get('$_base/$id');
    return ApartmentDetail.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// UC31: Tạo căn hộ mới (chỉ Landlord)
  Future<Apartment> createApartment({
    required String floor,
    required String roomNumber,
    required double areaSize,
    required double baseRent,
  }) async {
    final res = await _dio.post(_base, data: {
      'floor': floor,
      'roomNumber': roomNumber,
      'areaSize': areaSize,
      'baseRent': baseRent,
    });
    return Apartment.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  /// UC32: Cập nhật thông tin căn hộ (chỉ Landlord)
  Future<Apartment> updateApartment(
    int id, {
    required String floor,
    required String roomNumber,
    required double areaSize,
    required double baseRent,
  }) async {
    final res = await _dio.put('$_base/$id', data: {
      'floor': floor,
      'roomNumber': roomNumber,
      'areaSize': areaSize,
      'baseRent': baseRent,
    });
    return Apartment.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}

final apartmentApiServiceProvider = Provider<ApartmentAPIService>((ref) {
  return ApartmentAPIService(ref.watch(dioProvider));
});
