import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasource/auth_remote_datasource.dart';
import '../mappers/user_mapper.dart';
import '../models/login_request.dart';
import '../models/register_request.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl(this.remoteDataSource);

  @override
  Future<User> login({
    required String email,
    required String password,
  }) async {

    final response = await remoteDataSource.login(
      LoginRequest(
        email: email,
        password: password,
      ),
    );

    await TokenStorage.saveToken(response.token);

    try {
      return UserMapper.toEntity(await remoteDataSource.me());
    } catch (_) {
      await TokenStorage.deleteToken();
      rethrow;
    }
  }

  @override
  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String timezone = 'America/Lima',
    bool acceptsStudyParticipation = false,
  }) async {

    final response = await remoteDataSource.register(
      RegisterRequest(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        timezone: timezone,
        acceptsStudyParticipation: acceptsStudyParticipation,
      ),
    );

    return UserMapper.toEntity(response);
  }

  @override
  Future<User?> getCurrentUser() async {
    final response = await remoteDataSource.me();

    return UserMapper.toEntity(response);
  }

  @override
  Future<void> logout() async {
    await TokenStorage.deleteToken();
  }

  @override
  Future<void> forgotPassword(String email) async {
    await remoteDataSource.forgotPassword(email);
  }

  @override
  Future<void> resetPassword({
    required String code,
    required String password,
  }) async {
    await remoteDataSource.resetPassword(
      code: code,
      password: password,
    );
  }
}
