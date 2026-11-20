import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/api_error.dart';
import '../../../core/providers/dio_provider.dart';

/// What the backend answered to `DELETE /users/me` (`AccountDeletionResource`).
enum DeletionOutcome {
  /// 200 `DELETED`: no row of the person is left.
  completed,

  /// 202 `PENDING`: the account is already deactivated (no sign-in, every
  /// token revoked) and the backend finishes the deletion automatically. The
  /// data are NOT gone yet, and the app must not say they are.
  pending,
}

class DeletionResult {
  const DeletionResult(this.outcome, {this.alreadyRequested = false});
  final DeletionOutcome outcome;

  /// 202 with `alreadyRequested: true`: an earlier request was already registered.
  final bool alreadyRequested;
}

/// Why the deletion was not done. Nothing was deleted in any case.
/// Pause after a 429 that does not say how long to wait.
const minimumRetryPause = Duration(minutes: 1);

class DeletionFailure implements Exception {
  const DeletionFailure(this.kind, this.message, {this.retryAfter});
  final DeletionFailureKind kind;
  final String message;

  /// 429: how long the backend asks to wait (`Retry-After`).
  final Duration? retryAfter;
  @override
  String toString() => message;
}

enum DeletionFailureKind {
  /// No answer after the request left the phone (timeout, cut connection):
  /// the backend may have registered the deletion.
  uncertain, wrongPassword, tooManyAttempts, sessionExpired, alreadyGone, unavailable, offline, server, rejected }

/// `DELETE /api/v1/users/me` of Fitsense-Real/Backend (`generation` 5977d28):
/// body `{password, confirm: true}` (`DeleteAccountResource`). The backend
/// re-authenticates with that password itself, so the app sends it once and
/// only here.
///
/// | Answer | Meaning |
/// |---|---|
/// | 200 `DELETED` | deleted |
/// | 202 `PENDING` | account deactivated, deletion completes automatically |
/// | 400 `CONFIRMACION_REQUERIDA` | missing `confirm=true` (never sent by the app) |
/// | 403 `REAUTENTICACION_FALLIDA` | wrong password |
/// | 429 `DEMASIADOS_INTENTOS` + `Retry-After` | too many wrong passwords |
/// | 401 | token no longer valid (revoked, expired) |
/// | 404 `CUENTA_INEXISTENTE` | the account no longer exists |
/// | 503 `ELIMINACION_NO_REGISTRADA` | the request could not be registered |
class AccountDeletionRepository {
  AccountDeletionRepository(this._dio);
  final Dio _dio;

  Future<DeletionResult> requestDeletion({required String password}) async {
    try {
      final response = await _dio.delete(ApiConstants.deleteAccount, data: {'password': password, 'confirm': true});
      final body = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : const <String, dynamic>{};
      final status = '${body['status'] ?? ''}';
      if (response.statusCode == 200 && status == 'DELETED') return const DeletionResult(DeletionOutcome.completed);
      if (response.statusCode == 202) return DeletionResult(DeletionOutcome.pending, alreadyRequested: body['alreadyRequested'] == true);
      throw DeletionFailure(DeletionFailureKind.server, 'Respuesta inesperada del servidor (${response.statusCode} $status). No se eliminó nada.');
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  DeletionFailure _failure(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) {
      // Could not even connect: the request never reached the backend.
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        return const DeletionFailure(DeletionFailureKind.offline, 'No hay conexión con el servidor. No se eliminó nada; inténtalo cuando tengas conexión.');
      }
      // The request may have been processed (the backend deactivates the
      // account at once): never claim that nothing was deleted.
      return const DeletionFailure(DeletionFailureKind.uncertain,
          'No recibimos la respuesta del servidor y no sabemos si la eliminación se registró. Vuelve a intentarlo: si ya se registró, lo confirmaremos.');
    }
    switch (status) {
      case 403:
        // Only REAUTENTICACION_FALLIDA means a wrong password; other 403s
        // (HTTPS required, access denied) are a rejection, not the user's fault.
        if (!_codes(e).contains('REAUTENTICACION_FALLIDA')) {
          return const DeletionFailure(DeletionFailureKind.rejected, 'El servidor rechazó la solicitud. No se eliminó nada; inténtalo más tarde o escribe al equipo del estudio.');
        }
        return const DeletionFailure(DeletionFailureKind.wrongPassword, 'La contraseña no es correcta. No se eliminó nada; revísala e inténtalo de nuevo.');
      case 429:
        final seconds = int.tryParse(e.response?.headers.value('retry-after') ?? '');
        // Without Retry-After (in a browser the backend does not expose it through
        // CORS) the button still pauses for a minute: the backend keeps the real
        // block, and the person is not invited to send attempts that will fail.
        final wait = seconds == null ? minimumRetryPause : Duration(seconds: seconds);
        final minutes = seconds == null ? null : (wait.inSeconds / 60).ceil();
        return DeletionFailure(
          DeletionFailureKind.tooManyAttempts,
          'Demasiados intentos con una contraseña incorrecta. Por seguridad, espera'
          '${minutes == null ? ' unos minutos' : ' $minutes ${minutes == 1 ? 'minuto' : 'minutos'}'} antes de volver a intentarlo. No se eliminó nada.',
          retryAfter: wait,
        );
      case 401:
        return const DeletionFailure(DeletionFailureKind.sessionExpired, 'Tu sesión ya no es válida. Vuelve a iniciar sesión. No se eliminó nada.');
      case 404:
        return const DeletionFailure(DeletionFailureKind.alreadyGone, 'Esta cuenta ya no existe en el servidor.');
      case 405 || 501:
        return const DeletionFailure(DeletionFailureKind.unavailable, 'La eliminación de cuentas todavía no está disponible en este servidor. No se eliminó nada.');
    }
    if (status >= 500) {
      return const DeletionFailure(DeletionFailureKind.server, 'El servidor no pudo registrar la solicitud. No se eliminó nada; inténtalo más tarde.');
    }
    return DeletionFailure(DeletionFailureKind.rejected, apiError(e));
  }

  static List<String> _codes(DioException e) {
    final data = e.response?.data;
    final details = data is Map ? data['details'] : null;
    return details is List ? details.map((d) => '$d').toList() : const [];
  }
}

final accountDeletionRepositoryProvider = Provider((ref) => AccountDeletionRepository(ref.read(dioProvider)));
