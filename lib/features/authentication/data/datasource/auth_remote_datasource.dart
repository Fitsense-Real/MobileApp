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

  Future<AuthenticationResponse> login(
      LoginRequest request,
      ) async {
    try {
      final response = await _dio.post(
        ApiConstants.login,
        data: request.toJson(),
      );

      return AuthenticationResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserResponse> register(
      RegisterRequest request,
      ) async {
    try {
      final response = await _dio.post(
        ApiConstants.register,
        data: request.toJson(),
      );

      return UserResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserResponse> me() async {
    try {
      final response = await _dio.get(
        ApiConstants.me,
      );

      return UserResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> forgotPassword(
      String email,
      ) async {
    try {
      await _dio.post(
        ApiConstants.forgotPassword,
        data: {
          "email": email,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> resetPassword({
    required String code,
    required String password,
  }) async {
    try {
      await _dio.post(
        ApiConstants.resetPassword,
        data: {
          "code": code,
          "password": password,
        },
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 401 && e.requestOptions.path == ApiConstants.login) {
      return Exception('Correo o contraseña incorrectos.');
    }
    return Exception(apiError(e));
  }

}
