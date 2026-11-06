import '../repositories/auth_repository.dart';

class ResetPasswordUseCase {
  final AuthRepository repository;

  ResetPasswordUseCase(this.repository);

  Future<void> call(
      String code,
      String password,
      ) {
    return repository.resetPassword(
      code: code,
      password: password,
    );
  }
}