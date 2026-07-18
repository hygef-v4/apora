import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/contract.dart';

/// UC06: hợp đồng của chính user - fetch tường minh mỗi lần mở màn
/// để số ngày còn lại luôn được tính mới (BR-13).
class MyContractNotifier extends AsyncNotifier<MyContract?> {
  @override
  Future<MyContract?> build() async => null;

  Future<void> fetch() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.myContract);
      return MyContract.fromJson(res.data['data'] as Map<String, dynamic>);
    });
  }

  /// UC07: gửi yêu cầu gia hạn. [requestedEndDate] dạng 'YYYY-MM-DD'.
  /// Thành công thì refetch để UC06 hiển thị "đang chờ duyệt";
  /// lỗi ném message tiếng Việt (AT4) cho màn hình hiển thị.
  Future<void> requestExtension({
    required String requestedEndDate,
    required String reason,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        ApiConstants.stayExtensions,
        data: {
          'requestedEndDate': requestedEndDate,
          'reason': reason.trim(),
        },
      );
      await fetch();
    } catch (e) {
      throw mapDioError(e);
    }
  }
}

final myContractProvider = AsyncNotifierProvider<MyContractNotifier, MyContract?>(
  MyContractNotifier.new,
);

/// Danh sách TẤT CẢ hợp đồng cho Manager/Landlord (màn Hợp đồng).
/// Fetch toàn bộ rồi lọc phía client theo nhóm Hiệu lực/Sắp HH/Hết hạn.
class AllContractsNotifier extends AsyncNotifier<List<ContractListItem>> {
  @override
  Future<List<ContractListItem>> build() async => const [];

  Future<void> fetch() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.contracts);
      final raw = res.data['data'] as List;
      return raw
          .map((json) => ContractListItem.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }
}

final allContractsProvider =
    AsyncNotifierProvider<AllContractsNotifier, List<ContractListItem>>(
  AllContractsNotifier.new,
);

/// UC08: danh sách yêu cầu gia hạn cho Manager/Landlord.
/// Fetch toàn bộ rồi lọc phía client để tab đếm số PENDING (FID-11 field 1)
/// và chuyển tab tức thì không cần gọi lại API.
class ExtensionListNotifier extends AsyncNotifier<List<StayExtension>> {
  @override
  Future<List<StayExtension>> build() async => const [];

  Future<void> fetch() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.stayExtensions);
      final raw = res.data['data'] as List;
      return raw
          .map((json) => StayExtension.fromJson(json as Map<String, dynamic>))
          .toList();
    });
  }
}

final extensionListProvider =
    AsyncNotifierProvider<ExtensionListNotifier, List<StayExtension>>(
  ExtensionListNotifier.new,
);

/// UC09: chi tiết + duyệt/từ chối yêu cầu gia hạn.
class ExtensionDetailNotifier extends AsyncNotifier<StayExtensionDetail?> {
  @override
  Future<StayExtensionDetail?> build() async => null;

  Future<void> fetch(int extensionId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.stayExtensionDetail(extensionId));
      return StayExtensionDetail.fromJson(
        res.data['data'] as Map<String, dynamic>,
      );
    });
  }

  /// UC09: chốt kết quả duyệt. [action] = 'APPROVE' | 'REJECT';
  /// REJECT bắt buộc [rejectReason] (AT1/AT2). Backend chạy transaction
  /// BR-17; lỗi (409 hợp đồng hết hiệu lực / đã có người duyệt...) ném
  /// message tiếng Việt cho màn hình.
  Future<void> review(
    int extensionId, {
    required String action,
    String? rejectReason,
  }) async {
    try {
      final dio = ref.read(dioProvider);
      final reason = rejectReason?.trim();
      final res = await dio.put(
        ApiConstants.stayExtensionReview(extensionId),
        data: {
          'action': action,
          if (reason != null && reason.isNotEmpty) 'rejectReason': reason,
        },
      );
      state = AsyncData(
        StayExtensionDetail.fromJson(res.data['data'] as Map<String, dynamic>),
      );
    } catch (e) {
      throw mapDioError(e);
    }
  }
}

final extensionDetailProvider =
    AsyncNotifierProvider<ExtensionDetailNotifier, StayExtensionDetail?>(
  ExtensionDetailNotifier.new,
);
