import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/api_error.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/storage/token_storage.dart';

/// What the backend answered to the deletion request.
enum DeletionOutcome {
  /// 200/204: the account no longer exists.
  completed,

  /// 202: the request was accepted and will be processed later. The account
  /// is NOT deleted yet, and the app must not say it is.
  accepted,
}

/// Why the deletion could not be requested. Nothing was deleted in any case.
class DeletionFailure implements Exception {
  const DeletionFailure(this.kind, this.message);
  final DeletionFailureKind kind;
  final String message;
  @override
  String toString() => message;
}

enum DeletionFailureKind { wrongPassword, otherAccount, unavailable, offline, server, rejected }

/// `DELETE /users/me` of Fitsense-Real/Backend. The contract is being prepared
/// in the backend; the codes handled here are the standard REST ones and are
/// reviewed against the real contract before enabling the option
/// (`ACCOUNT_DELETION_ENABLED`, docs/preparacion_google_play/ELIMINACION_CUENTA_FLUTTER.md).
class AccountDeletionRepository {
  AccountDeletionRepository(this._dio);
  final Dio _dio;

  /// Re-authentication with the existing login (`POST /auth/login`): proves
  /// it is the owner and gets a fresh JWT for the deletion. The account
  /// signed in must be the one being deleted.
  Future<void> reauthenticate({required int userId, required String email, required String password}) async {
    try {
      final response = await _dio.post(ApiConstants.login, data: {'email': email, 'password': password});
      final data = response.data is Map ? Map<String, dynamic>.from(response.data as Map) : const <String, dynamic>{};
      final token = data['token'] as String?;
      final id = (data['userId'] as num?)?.toInt() ?? ((data['user'] as Map?)?['userId'] as num?)?.toInt();
      if (token == null || token.isEmpty) throw const DeletionFailure(DeletionFailureKind.server, 'No pudimos confirmar tu identidad. Inténtalo de nuevo.');
      if (id != null && id != userId) {
        throw const DeletionFailure(DeletionFailureKind.otherAccount, 'Esa contraseña corresponde a otra cuenta.');
      }
      await TokenStorage.saveToken(token);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) throw const DeletionFailure(DeletionFailureKind.wrongPassword, 'La contraseña no es correcta. No se eliminó nada.');
      throw _failure(e);
    }
  }

  Future<DeletionOutcome> requestDeletion() async {
    try {
      final response = await _dio.delete(ApiConstants.deleteAccount);
      return switch (response.statusCode) {
        202 => DeletionOutcome.accepted,
        200 || 204 => DeletionOutcome.completed,
        _ => throw DeletionFailure(DeletionFailureKind.server, 'Respuesta inesperada del servidor (${response.statusCode}). No se eliminó nada.'),
      };
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  DeletionFailure _failure(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) {
      return const DeletionFailure(DeletionFailureKind.offline, 'No hay conexión con el servidor. No se eliminó nada; inténtalo cuando tengas conexión.');
    }
    if (status == 404 || status == 405 || status == 501) {
      return const DeletionFailure(DeletionFailureKind.unavailable, 'La eliminación de cuentas todavía no está disponible en el servidor. No se eliminó nada.');
    }
    if (status >= 500) {
      return const DeletionFailure(DeletionFailureKind.server, 'El servidor no pudo procesar la solicitud. No se eliminó nada; inténtalo más tarde.');
    }
    return DeletionFailure(DeletionFailureKind.rejected, apiError(e));
  }
}

final accountDeletionRepositoryProvider = Provider((ref) => AccountDeletionRepository(ref.read(dioProvider)));
