import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import '../../domain/usecases/forgot_password_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../state/forgot_password_state.dart';
import '../viewmodels/forgot_password_viewmodel.dart';

final forgotPasswordUseCaseProvider =
Provider<ForgotPasswordUseCase>((ref) {
  return ForgotPasswordUseCase(
    ref.read(authRepositoryProvider),
  );
});

final resetPasswordUseCaseProvider =
Provider<ResetPasswordUseCase>((ref) {
  return ResetPasswordUseCase(
    ref.read(authRepositoryProvider),
  );
});

final forgotPasswordViewModelProvider =
NotifierProvider<ForgotPasswordViewModel, ForgotPasswordState>(
  ForgotPasswordViewModel.new,
);