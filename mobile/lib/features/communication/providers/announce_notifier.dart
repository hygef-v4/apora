import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../repositories/communication_repository.dart';

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

class AnnounceState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;

  AnnounceState({this.isLoading = false, this.error, this.isSuccess = false});

  AnnounceState copyWith({bool? isLoading, String? error, bool? isSuccess}) {
    return AnnounceState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class AnnounceNotifier extends Notifier<AnnounceState> {
  late CommunicationRepository _repo;

  @override
  AnnounceState build() {
    _repo = ref.read(communicationRepositoryProvider);
    return AnnounceState();
  }

  Future<void> submit({
    required String title,
    required String body,
    File? banner,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      await _repo.announceNotification(
        title: title,
        body: body,
        bannerImage: banner,
      );
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final announceNotifierProvider =
    NotifierProvider.autoDispose<AnnounceNotifier, AnnounceState>(
  AnnounceNotifier.new,
);
