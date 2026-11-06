import 'package:dio/dio.dart';

String apiError(Object error) {
  if (error is DioException && error.type == DioExceptionType.receiveTimeout && error.requestOptions.path == '/users/me/plan/generate') return 'La rutina no llegó en cinco minutos. Tu perfil está guardado; puedes reintentar.';
  if (error is! DioException) return error.toString().replaceFirst('Exception: ', '');
  if (error.response?.statusCode == 401) return 'Tu sesión no es válida. Vuelve a iniciar sesión.';
  final data = error.response?.data;
  if (data is Map) {
    final details = data['errors'];
    final message = data['message'] ?? data['detail'];
    if (details is Map) return details.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    if (message is String && message.isNotEmpty) return message;
  }
  if (error.type == DioExceptionType.connectionError || error.type == DioExceptionType.connectionTimeout) return 'No se pudo conectar al backend. Comprueba que esté encendido y accesible en el puerto 8080.';
  return 'No se pudo guardar (${error.response?.statusCode ?? 'sin conexión'}). Inténtalo nuevamente.';
}
