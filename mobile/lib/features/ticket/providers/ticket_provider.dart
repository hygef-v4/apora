import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/ticket.dart';

class TicketState {
  final List<Ticket> tickets;
  final bool isLoading;
  final String? errorMessage;
  /// null = tất cả; ngược lại lọc theo 1 trạng thái (UC18).
  final String? statusFilter;

  TicketState({
    required this.tickets,
    this.isLoading = false,
    this.errorMessage,
    this.statusFilter,
  });

  TicketState copyWith({
    List<Ticket>? tickets,
    bool? isLoading,
    String? errorMessage,
    Object? statusFilter = _unset,
  }) {
    return TicketState(
      tickets: tickets ?? this.tickets,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      statusFilter:
          statusFilter == _unset ? this.statusFilter : statusFilter as String?,
    );
  }
}

/// Sentinel để phân biệt "không truyền" với "truyền null" khi copyWith statusFilter.
const Object _unset = Object();

/// Danh sách sự cố (UC18). Backend tự phân luồng theo vai trò:
/// RESIDENT thấy của mình, MANAGER/LANDLORD thấy tất cả.
class TicketNotifier extends Notifier<TicketState> {
  @override
  TicketState build() => TicketState(tickets: const []);

  Future<void> fetchTickets({String? status}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, statusFilter: status);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        ApiConstants.tickets,
        queryParameters: status != null ? {'status': status} : null,
      );
      final raw = res.data['data'] as List;
      final list = raw
          .map((json) => Ticket.fromJson(json as Map<String, dynamic>))
          .toList();
      state = state.copyWith(tickets: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: mapDioError(e));
    }
  }
}

final ticketProvider =
    NotifierProvider<TicketNotifier, TicketState>(() => TicketNotifier());
