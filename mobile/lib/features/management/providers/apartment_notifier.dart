import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/apartment.dart';
import '../repositories/apartment_api_service.dart';

/// Notifier danh mục căn hộ (UC29).
class ApartmentDirectoryNotifier extends AsyncNotifier<List<Apartment>> {
  ApartmentAPIService get _api => ref.read(apartmentApiServiceProvider);

  String? statusFilter;
  String? searchKeyword;

  @override
  Future<List<Apartment>> build() {
    return _api.getApartments(status: statusFilter, search: searchKeyword);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _api.getApartments(status: statusFilter, search: searchKeyword),
    );
  }

  Future<void> setStatusFilter(String? status) {
    statusFilter = status;
    return refresh();
  }

  Future<void> setSearch(String keyword) {
    searchKeyword = keyword.trim().isEmpty ? null : keyword.trim();
    return refresh();
  }

  /// UC31: Tạo căn hộ mới
  Future<void> createApartment({
    required String floor,
    required String roomNumber,
    required double areaSize,
    required double baseRent,
  }) async {
    await _api.createApartment(
      floor: floor,
      roomNumber: roomNumber,
      areaSize: areaSize,
      baseRent: baseRent,
    );
    await refresh();
  }
}

final apartmentDirectoryProvider =
    AsyncNotifierProvider<ApartmentDirectoryNotifier, List<Apartment>>(
  ApartmentDirectoryNotifier.new,
);

/// Notifier chi tiết căn hộ (UC30).
class ApartmentDetailNotifier extends AsyncNotifier<ApartmentDetail?> {
  ApartmentAPIService get _api => ref.read(apartmentApiServiceProvider);

  @override
  Future<ApartmentDetail?> build() async => null;

  Future<void> fetch(int apartmentId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _api.getApartmentDetail(apartmentId));
  }

  /// UC32: Cập nhật thông tin căn hộ
  Future<void> updateApartment(
    int id, {
    required String floor,
    required String roomNumber,
    required double areaSize,
    required double baseRent,
  }) async {
    await _api.updateApartment(
      id,
      floor: floor,
      roomNumber: roomNumber,
      areaSize: areaSize,
      baseRent: baseRent,
    );
    await fetch(id);
    // Đồng thời refresh danh sách bên ngoài
    ref.read(apartmentDirectoryProvider.notifier).refresh();
  }
}

final apartmentDetailProvider =
    AsyncNotifierProvider<ApartmentDetailNotifier, ApartmentDetail?>(
  ApartmentDetailNotifier.new,
);
