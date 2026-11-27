class ForgotPasswordState {
  final bool isLoading;
  final String? errorMessage;
  final bool emailSent;
  final bool passwordReset;

  /// Address the last code was requested for: prefilled when the person comes
  /// back for a new code and on the login after changing the password.
  final String email;

  const ForgotPasswordState({
    this.isLoading = false,
    this.errorMessage,
    this.emailSent = false,
    this.passwordReset = false,
    this.email = '',
  });

  ForgotPasswordState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? emailSent,
    bool? passwordReset,
    String? email,
  }) {
    return ForgotPasswordState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      emailSent: emailSent ?? this.emailSent,
      passwordReset: passwordReset ?? this.passwordReset,
      email: email ?? this.email,
    );
  }
}