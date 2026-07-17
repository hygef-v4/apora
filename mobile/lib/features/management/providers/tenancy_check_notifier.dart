import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/apartment_api_service.dart';
import 'apartment_notifier.dart';

/// Notifier quản lý tiến trình Check-in và Check-out căn hộ.
class TenancyCheckNotifier extends AsyncNotifier<void> {
  ApartmentAPIService get _api => ref.read(apartmentApiServiceProvider);

  @override
  Future<void> build() async {}

  /// UC33: Tiến hành Check-in
  Future<void> processCheckIn(
    int apartmentId, {
    required String fullName,
    required String phoneNumber,
    required String startDate,
    required String endDate,
    required double depositValue,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _api.checkIn(
        apartmentId,
        fullName: fullName,
        phoneNumber: phoneNumber,
        startDate: startDate,
        endDate: endDate,
        depositValue: depositValue,
      );
      // Refresh danh sách căn hộ & chi tiết căn hộ sau khi checkin thành công
      ref.read(apartmentDirectoryProvider.notifier).refresh();
      ref.read(apartmentDetailProvider.notifier).fetch(apartmentId);
    });
  }

  /// UC34: Tiến hành Check-out
  Future<void> processCheckOut(int apartmentId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _api.checkOut(apartmentId);
      // Refresh danh sách căn hộ & chi tiết căn hộ sau khi checkout thành công
      ref.read(apartmentDirectoryProvider.notifier).refresh();
      ref.read(apartmentDetailProvider.notifier).fetch(apartmentId);
    });
  }
}

final tenancyCheckProvider =
    AsyncNotifierProvider<TenancyCheckNotifier, void>(
  TenancyCheckNotifier.new,
);
