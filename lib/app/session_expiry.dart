import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'router/app_routes.dart';

/// Lets code outside the widget tree (the HTTP interceptor) show a message.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

const sessionExpiredMessage = 'Tu sesión expiró. Vuelve a iniciar sesión.';

/// Screens where a signed-out user may already be: no redirect from them.
const _publicLocations = {
  AppRoutes.splash, AppRoutes.login, AppRoutes.register,
  AppRoutes.forgotPassword, AppRoutes.resetPassword,
};

/// Reaction to an expired JWT: clear the session (state, token and device
/// reminders), go to login and say why.
Future<void> handleSessionExpired({
  required AuthViewModel auth,
  required GoRouter router,
  GlobalKey<ScaffoldMessengerState>? messenger,
}) async {
  await auth.logout();
  final location = router.routerDelegate.currentConfiguration.uri.path;
  if (!_publicLocations.contains(location)) router.go(AppRoutes.login);
  (messenger ?? rootMessengerKey).currentState
    ?..clearSnackBars()
    ..showSnackBar(const SnackBar(content: Text(sessionExpiredMessage)));
}
