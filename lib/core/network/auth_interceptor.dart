import 'package:dio/dio.dart';

import '../api/api_constants.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
      RequestOptions options,
      RequestInterceptorHandler handler,
      ) async {
    // No enviar Authorization en endpoints públicos
    if (options.path == ApiConstants.login ||
        options.path == ApiConstants.register) {
      handler.next(options);
      return;
    }

    final token = await TokenStorage.getToken();

    if (token != null && token.isNotEmpty) {
      options.headers["Authorization"] = "Bearer $token";
    }

    handler.next(options);
  }
}