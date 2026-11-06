import 'package:dio/dio.dart';
import '../network/auth_interceptor.dart';
import 'api_constants.dart';

class DioClient {
  DioClient._();
  // No credential, JWT, or health-data logging.
  static final Dio instance = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {'Accept': 'application/json'},
  ))..interceptors.add(AuthInterceptor());
}
