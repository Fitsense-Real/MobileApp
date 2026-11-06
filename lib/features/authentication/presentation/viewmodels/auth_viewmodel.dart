import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_user_use_case.dart';
import '../../domain/usecases/login_use_case.dart';
import '../../domain/usecases/logout_use_case.dart';
import '../../domain/usecases/register_use_case.dart';
import '../providers/auth_provider.dart';
import '../state/auth_state.dart';

class AuthViewModel extends Notifier<AuthState> {
  late final LoginUseCase _loginUseCase;
  late final RegisterUseCase _registerUseCase;
  late final LogoutUseCase _logoutUseCase;
  late final GetCurrentUserUseCase _currentUserUseCase;

  @override
  AuthState build() {

    _loginUseCase = ref.read(loginUseCaseProvider);
    _registerUseCase = ref.read(registerUseCaseProvider);
    _logoutUseCase = ref.read(logoutUseCaseProvider);
    _currentUserUseCase = ref.read(currentUserUseCaseProvider);

    return const AuthState();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final User user = await _loginUseCase(
        email: email,
        password: password,
      );

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );

      return true;
    } catch (e) {
      final message = e is Exception
          ? e.toString().replaceFirst("Exception: ", "")
          : "Ha ocurrido un error inesperado.";

      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );

      return false;
    }
  }

  Future<bool> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String timezone = 'America/Lima',
    bool acceptsStudyParticipation = false,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      final User user = await _registerUseCase(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        timezone: timezone,
        acceptsStudyParticipation: acceptsStudyParticipation,
      );

      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );

      return false;
    }
  }

  Future<void> logout() async {
    await _logoutUseCase();

    state = const AuthState();
  }

  Future<void> loadCurrentUser() async {
    final user = await _currentUserUseCase();

    if (user != null) {
      state = state.copyWith(
        isAuthenticated: true,
        user: user,
      );
    }
  }
}
