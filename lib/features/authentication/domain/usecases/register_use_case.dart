import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<User> call({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String timezone = 'America/Lima',
    bool acceptsStudyParticipation = false,
  }) {
    return repository.register(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      timezone: timezone,
      acceptsStudyParticipation: acceptsStudyParticipation,
    );
  }
}
