class AppRoutes {
  AppRoutes._();

  static const splash = "/splash";

  static const login = "/login";

  static const forgotPassword = "/forgot-password";

  static const resetPassword = "/reset-password";

  static const register = "/register";

  static const dashboard = "/dashboard";
  static const accountSetup = "/account-setup";

  /// Perfil → Cuenta → Eliminar mi cuenta (only with ACCOUNT_DELETION_ENABLED).
  static const deleteAccount = "/cuenta/eliminar";

  /// Acceptance of newly published terms / privacy policy (backend V63).
  static const consents = "/consentimientos";

  static const profile = "/profile";

  static const assessment = "/assessment";

  static const workout = "/workout";

  static const progress = "/progress";

  static const settings = "/settings";
}
