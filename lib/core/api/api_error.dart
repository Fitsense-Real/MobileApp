import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import 'api_constants.dart';

/// Error with a user-facing message that keeps the HTTP status of its cause.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.cause});
  factory ApiException.from(Object error) => error is ApiException
      ? error
      : ApiException(apiError(error), statusCode: statusOf(error), cause: error);
  final String message;
  final int? statusCode;
  final Object? cause;
  @override
  String toString() => message;
}

int? statusOf(Object error) => switch (error) {
  ApiException(:final statusCode) => statusCode,
  DioException(:final response) => response?.statusCode,
  _ => null,
};

/// True when the request reached the server and it answered that the JWT is
/// missing, expired or invalid. Network failures are never treated as such.
bool isUnauthorized(Object error) => statusOf(error) == 401;

/// The backend reports a plan that already exists as a domain rule violation
/// (422). Older builds answered 409; both mean "reconcile with current".
bool isPlanConflict(Object error) {
  final status = statusOf(error);
  return status == 409 || status == 422;
}

/// Human message for any error, following the backend `ApiErrorResource`
/// contract: `{timestamp, status, error, message, details: [String]}`.
String apiError(Object error) {
  if (error is DioException &&
      error.type == DioExceptionType.receiveTimeout &&
      error.requestOptions.path == ApiConstants.generatePlan) {
    return 'La rutina no llegó en cinco minutos. Tu perfil está guardado; puedes reintentar.';
  }
  if (error is ApiException) return error.message;
  if (error is! DioException) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  final status = error.response?.statusCode;
  if (status == 401) return 'Tu sesión no es válida. Vuelve a iniciar sesión.';
  if (status == 403) return 'No tienes acceso a este recurso.';
  final data = error.response?.data;
  if (data is Map) {
    final message = data['message'] ?? data['detail'];
    final details = data['details'] ?? data['errors'];
    final lines = <String>[
      if (details is List)
        for (final item in details)
          // Machine codes (`DEMASIADAS_SOLICITUDES`) are for the app, not for people.
          if ('$item'.trim().isNotEmpty && !_machineCode.hasMatch('$item'.trim())) '$item',
      if (details is Map)
        for (final entry in details.entries) '${entry.key}: ${entry.value}',
    ];
    final wait = status == 429 ? retryAfterText(error) : null;
    if (lines.isNotEmpty) {
      return [
        if (message is String && message.isNotEmpty) message,
        ...lines,
        ?wait,
      ].join('\n');
    }
    if (message is String && message.isNotEmpty) return wait == null ? message : '$message $wait';
  }
  if (status == 429) {
    return ['Demasiadas solicitudes. Espera un momento antes de volver a intentarlo.', ?retryAfterText(error)].join(' ');
  }
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
      return connectionErrorMessage();
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return 'El servidor tardó demasiado en responder. Inténtalo nuevamente.';
    default:
      break;
  }
  if (status == 404) return 'No se encontró el recurso solicitado.';
  if (status != null && status >= 500) {
    return 'El servidor tuvo un problema ($status). Inténtalo más tarde.';
  }
  return 'No se pudo completar la operación (${status ?? 'sin conexión'}). Inténtalo nuevamente.';
}

final _machineCode = RegExp(r'^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$');

/// Seconds the backend asks to wait after a 429 (`Retry-After`), or null.
int? retryAfterSeconds(Object error) {
  if (error is! DioException) return null;
  final value = error.response?.headers.value('retry-after');
  return value == null ? null : int.tryParse(value.trim());
}

/// "Podrás intentarlo de nuevo en N minutos." from `Retry-After`, or null.
String? retryAfterText(Object error) {
  final seconds = retryAfterSeconds(error);
  if (seconds == null || seconds <= 0) return null;
  if (seconds < 60) return 'Podrás intentarlo de nuevo en unos segundos.';
  final minutes = (seconds / 60).ceil();
  return 'Podrás intentarlo de nuevo en $minutes ${minutes == 1 ? 'minuto' : 'minutos'}.';
}

/// The port hint only helps a developer with a local backend; a participant
/// using a release build just needs to check their connection.
String connectionErrorMessage({bool debug = kDebugMode}) => debug
    ? 'No se pudo conectar al backend. Comprueba que esté encendido y accesible en el puerto 8080.'
    : 'No se pudo conectar con el servidor. Revisa tu conexión a internet e inténtalo de nuevo.';
