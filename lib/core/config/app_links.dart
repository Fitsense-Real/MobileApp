/// Publication settings passed at build time with `--dart-define`. None has
/// an invented default: a missing value means "not available yet".
class AppLinks {
  AppLinks._();

  /// Shows "Eliminar mi cuenta" in Perfil. Off until the backend's
  /// `DELETE /users/me` is in service: the option must never look like it
  /// works when it cannot complete a real request.
  static const accountDeletionEnabled = bool.fromEnvironment('ACCOUNT_DELETION_ENABLED');

  /// Public web page to request the deletion without the app (Google Play
  /// requirement). Built in the web stage; empty until it exists.
  static const accountDeletionWebUrl = String.fromEnvironment('ACCOUNT_DELETION_WEB_URL');

  /// Privacy policy of Kora and the study. Empty until it is published.
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
}
