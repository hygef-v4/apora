import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/manager_detail.dart';
import '../repositories/manager_api_service.dart';

/// Riverpod notifier managing the Manager directory list (UC41).
///
/// Supports server-side filtering by status tab (All/Active/Inactive)
/// and search keyword. Each filter change triggers a fresh API call.
class ManagerDirectoryNotifier extends AsyncNotifier<ManagerListResult> {
  ManagerAPIService get _api => ref.read(managerApiServiceProvider);

  /// Current status filter: null = All, 'ACTIVE', 'INACTIVE'.
  String? statusFilter;

  /// Current search keyword (null when empty).
  String? searchKeyword;

  @override
  Future<ManagerListResult> build() =>
      _api.getManagerList(status: statusFilter, search: searchKeyword);

  /// Refreshes the list with current filter/search state.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _api.getManagerList(status: statusFilter, search: searchKeyword),
    );
  }

  /// Updates the status filter and reloads the list.
  ///
  /// [status] — 'ACTIVE' | 'INACTIVE' | null (all).
  Future<void> setStatusFilter(String? status) {
    statusFilter = status;
    return refresh();
  }

  /// Updates the search keyword and reloads the list.
  ///
  /// Trims whitespace; empty string resets to null (no filter).
  Future<void> setSearch(String keyword) {
    searchKeyword = keyword.trim().isEmpty ? null : keyword.trim();
    return refresh();
  }

  /// Creates a new Manager account and refreshes the directory (UC43).
  ///
  /// [fullName] — The Manager's full name.
  /// [phone] — The Manager's phone number.
  Future<void> createManager({
    required String fullName,
    required String phone,
  }) async {
    await _api.createManager(fullName: fullName, phone: phone);
    // Refresh the list immediately after successful creation
    await refresh();
  }

  /// Updates an existing Manager account and refreshes the directory (UC44).
  ///
  /// [id] — The Manager's user ID.
  /// [fullName] — The Manager's new full name.
  /// [phone] — The Manager's new phone number.
  Future<void> updateManager(
    int id, {
    required String fullName,
    required String phone,
  }) async {
    await _api.updateManager(id: id, fullName: fullName, phone: phone);
    // Refresh the list immediately after successful update
    await refresh();
  }
}

/// Provider for the Manager directory list state (UC41).
final managerDirectoryProvider =
    AsyncNotifierProvider<ManagerDirectoryNotifier, ManagerListResult>(
  ManagerDirectoryNotifier.new,
);

/// Riverpod notifier managing a single Manager's detail view (UC42).
///
/// Fetch is triggered explicitly by [fetch] — not automatically on build,
/// since the Manager ID comes from navigation parameters.
class ManagerDetailNotifier extends AsyncNotifier<ManagerDetail?> {
  ManagerAPIService get _api => ref.read(managerApiServiceProvider);

  @override
  Future<ManagerDetail?> build() async => null;

  /// Loads the detailed profile for the given Manager ID.
  ///
  /// [managerId] — The user ID of the Manager to fetch.
  Future<void> fetch(int managerId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _api.getManagerDetail(managerId));
  }
}

/// Provider for the Manager detail view state (UC42).
final managerDetailProvider =
    AsyncNotifierProvider<ManagerDetailNotifier, ManagerDetail?>(
  ManagerDetailNotifier.new,
);
