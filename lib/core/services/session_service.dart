import '../../features/authentication/domain/entities/user.dart';
import '../../features/authentication/domain/usecases/get_current_user_use_case.dart';
import '../api/api_error.dart';
import '../storage/token_storage.dart';

class SessionService {
  final GetCurrentUserUseCase _getCurrentUser;

  const SessionService(this._getCurrentUser);

  /// Validates the stored JWT against `GET /users/me` and returns its user.
  ///
  /// The token is deleted only when the server rejects it (401). A network
  /// failure or a 5xx keeps it, so an offline start never logs the user out.
  Future<User?> restore() async {
    final token = await TokenStorage.getToken();
    if (token == null || token.isEmpty) return null;
    try {
      return await _getCurrentUser();
    } catch (e) {
      if (isUnauthorized(e)) await TokenStorage.deleteToken();
      return null;
    }
  }

  Future<bool> isAuthenticated() async => await restore() != null;
}
