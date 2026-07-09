import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../constants/app_strings.dart';
import 'token_storage.dart';

/// Handler gọi khi backend trả 401 với request đã đăng nhập (token hết hạn /
/// bị vô hiệu theo BR-07). Gán implementation thật (authNotifier.sessionExpired)
/// qua ProviderScope.overrides ở main.dart - core không import ngược vào features.
final sessionExpiredHandlerProvider =
    Provider<Future<void> Function()>((ref) => () async {});

/// Dio client dùng chung: tự gắn JWT vào header Authorization,
/// tự đăng xuất local khi phiên hết hiệu lực (401).
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await ref.read(tokenStorageProvider).readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        // 401 = phiên hết hiệu lực -> xóa phiên local, router tự về Login.
        // Trừ login: 401 ở đó nghĩa là sai mật khẩu, không phải hết phiên.
        final isLoginCall = err.requestOptions.path == ApiConstants.login;
        if (err.response?.statusCode == 401 && !isLoginCall) {
          await ref.read(sessionExpiredHandlerProvider)();
        }
        handler.next(err);
      },
    ),
  );

  return dio;
});

/// Map lỗi Dio -> message tiếng Việt thân thiện (không để app crash).
/// Ưu tiên message từ backend ({ status: 'error', message: ... }).
String mapDioError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return AppStrings.msgNetworkError;
      default:
        return AppStrings.msgUnknownError;
    }
  }
  return AppStrings.msgUnknownError;
}
