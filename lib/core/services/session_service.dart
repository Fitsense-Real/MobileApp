import '../../features/authentication/domain/usecases/get_current_user_use_case.dart';
import '../storage/token_storage.dart';

class SessionService {
  final GetCurrentUserUseCase _getCurrentUser;

  const SessionService(this._getCurrentUser);

  Future<bool> isAuthenticated() async {
    try {
      final token = await TokenStorage.getToken();

      if (token == null || token.isEmpty) {
        return false;
      }

      final user = await _getCurrentUser();

      return user != null;
    } catch (_) {
      await TokenStorage.deleteToken();

      return false;
    }
  }
}