class ForgotPasswordState {
  final bool isLoading;
  final String? errorMessage;
  final bool emailSent;
  final bool passwordReset;

  const ForgotPasswordState({
    this.isLoading = false,
    this.errorMessage,
    this.emailSent = false,
    this.passwordReset = false,
  });

  ForgotPasswordState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? emailSent,
    bool? passwordReset,
  }) {
    return ForgotPasswordState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      emailSent: emailSent ?? this.emailSent,
      passwordReset: passwordReset ?? this.passwordReset,
    );
  }
}