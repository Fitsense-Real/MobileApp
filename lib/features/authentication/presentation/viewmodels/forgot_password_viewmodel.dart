import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/forgot_password_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../providers/forgot_password_provider.dart';
import '../state/forgot_password_state.dart';

class ForgotPasswordViewModel
    extends Notifier<ForgotPasswordState> {

  late final ForgotPasswordUseCase _forgotPasswordUseCase;
  late final ResetPasswordUseCase _resetPasswordUseCase;

  @override
  ForgotPasswordState build() {
    _forgotPasswordUseCase =
        ref.read(forgotPasswordUseCaseProvider);

    _resetPasswordUseCase =
        ref.read(resetPasswordUseCaseProvider);

    return const ForgotPasswordState();
  }

  Future<bool> sendRecoveryEmail(
      String email,
      ) async {

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {

      await _forgotPasswordUseCase(email);

      state = state.copyWith(
        isLoading: false,
        emailSent: true,
      );

      return true;

    } catch (e) {

      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );

      return false;
    }
  }

  Future<bool> resetPassword({
    required String code,
    required String password,
  }) async {

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {

      await _resetPasswordUseCase(
        code,
        password,
      );

      state = state.copyWith(
        isLoading: false,
        passwordReset: true,
      );

      return true;

    } catch (e) {

      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );

      return false;
    }
  }
}