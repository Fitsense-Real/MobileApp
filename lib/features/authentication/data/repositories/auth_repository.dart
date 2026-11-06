import '../../data/models/authentication_response.dart';
import '../../data/models/login_request.dart';
import '../../data/models/register_request.dart';
import '../../data/models/user_response.dart';

abstract class AuthRepository {
  Future<AuthenticationResponse> login(LoginRequest request);

  Future<UserResponse> register(RegisterRequest request);

  Future<UserResponse> me();

  Future<void> logout();
}
