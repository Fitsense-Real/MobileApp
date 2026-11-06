import '../entities/user.dart';

abstract class AuthRepository {

  Future<User> login({
    required String email,
    required String password,
  });

  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String timezone = 'America/Lima',
    bool acceptsStudyParticipation = false,
  });

  Future<User?> getCurrentUser();

  Future<void> logout();

  /// Voluntary withdrawal from the study (`POST /users/me/withdraw`).
  Future<User> withdrawFromStudy();

  Future<void> forgotPassword(
      String email,
      );

  Future<void> resetPassword({
    required String code,
    required String password,
  });
}