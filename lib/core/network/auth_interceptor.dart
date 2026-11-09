import 'dart:async';

import 'package:dio/dio.dart';

import '../api/api_constants.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  /// Called once when the backend rejects the stored JWT (expired, revoked or
  /// invalid). The app wires it to: clear the session, go to login and show
  /// a message. Null in tests and before the app starts.
  static FutureOr<void> Function()? onSessionExpired;

  /// Guards against several requests failing with 401 at the same time.
  static Future<void>? _expiring;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // No enviar Authorization en endpoints públicos.
    if (ApiConstants.publicPaths.contains(options.path)) {
      handler.next(options);
      return;
    }

    final token = await TokenStorage.getToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (isExpiredSession(err)) await expireSession();
    handler.next(err);
  }

  /// A 401 on a protected endpoint for a request that carried a JWT. A 401
  /// from login means wrong credentials, and a request without a token was
  /// never authenticated: neither is an expired session.
  static bool isExpiredSession(DioException err) =>
      err.response?.statusCode == 401 &&
      !ApiConstants.publicPaths.contains(err.requestOptions.path) &&
      err.requestOptions.headers['Authorization'] != null;

  /// Deletes the token and notifies the app, once per expired session.
  static Future<void> expireSession() => _expiring ??= () async {
    try {
      final hadToken = (await TokenStorage.getToken())?.isNotEmpty == true;
      await TokenStorage.deleteToken();
      // Parallel 401s arriving after the token was already removed must not
      // log the user out twice.
      if (hadToken) await onSessionExpired?.call();
    } finally {
      _expiring = null;
    }
  }();
}
