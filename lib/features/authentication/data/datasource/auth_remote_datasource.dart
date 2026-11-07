import 'package:dio/dio.dart';

import '../../../../core/api/api_constants.dart';
import '../../../../core/api/api_error.dart';
import '../models/authentication_response.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';
import '../models/user_response.dart';

class AuthRemoteDataSource {
  final Dio _dio;

  const AuthRemoteDataSource(this._dio);

  Future<AuthenticationResponse> login(LoginRequest request) => _call(
    () => _dio.post(ApiConstants.login, data: request.toJson()),
    (data) => AuthenticationResponse.fromJson(data),
  );

  Future<UserResponse> register(RegisterRequest request) => _call(
    () => _dio.post(ApiConstants.register, data: request.toJson()),
    UserResponse.fromJson,
  );

  Future<UserResponse> me() => _call(() => _dio.get(ApiConstants.me), UserResponse.fromJson);

  /// Voluntary withdrawal from the study. Collected data is kept.
  Future<UserResponse> withdraw() =>
      _call(() => _dio.post(ApiConstants.withdraw), UserResponse.fromJson);

  Future<void> forgotPassword(String email) => _call(
    () => _dio.post(ApiConstants.forgotPassword, data: {'email': email}),
    (_) {},
  );

  /// `PasswordResetConfirmResource`: the code sent by email is the `token`.
  Future<void> resetPassword({required String code, required String password}) => _call(
    () => _dio.post(ApiConstants.resetPassword, data: {'token': code, 'newPassword': password}),
    (_) {},
  );

  Future<T> _call<T>(
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await request();
      final data = response.data;
      return parse(data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ApiException _handleError(DioException e) {
    if (e.response?.statusCode == 401 && e.requestOptions.path == ApiConstants.login) {
      return ApiException('Correo o contraseña incorrectos.', statusCode: 401, cause: e);
    }
    return ApiException.from(e);
  }
}
