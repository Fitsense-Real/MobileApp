import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/pages/forgot_password_page.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/register_page.dart';
import '../../features/authentication/presentation/pages/reset_password_page.dart';
import '../../features/authentication/presentation/pages/splash_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/account/presentation/account_deletion_page.dart';
import 'app_routes.dart';
import 'route_names.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/plans/presentation/account_setup_page.dart';
import '../../features/welcome/presentation/first_plan_result_page.dart';
import '../../features/welcome/presentation/welcome_routes.dart';
import '../../features/welcome/presentation/welcome_tour_page.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: AppRoutes.splash,

    routes: [
      GoRoute(path: AppRoutes.accountSetup, builder: (_, __) => const AccountSetupPage()),
      GoRoute(path: AppRoutes.deleteAccount, builder: (_, __) => const AccountDeletionPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(
        path: welcomeTourRoute,
        builder: (_, state) => WelcomeTourPage(replay: state.uri.queryParameters['repaso'] == '1'),
      ),
      GoRoute(path: welcomeResultRoute, builder: (_, __) => const FirstPlanResultPage()),
      GoRoute(
        path: '/workout',
        redirect: (_, __) => '${AppRoutes.dashboard}?tab=1',
      ),

      GoRoute(
        path: AppRoutes.splash,
        name: RouteNames.splash,
        builder: (_, __) => const SplashPage(),
      ),

      GoRoute(
        path: AppRoutes.login,
        name: RouteNames.login,
        builder: (_, __) => const LoginPage(),
      ),

      GoRoute(
        path: AppRoutes.forgotPassword,
        name: RouteNames.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),

      GoRoute(
        path: AppRoutes.resetPassword,
        name: RouteNames.resetPassword,
        builder: (_, __) => const ResetPasswordPage(),
      ),

      GoRoute(
        path: AppRoutes.register,
        name: RouteNames.register,
        builder: (_, __) => const RegisterPage(),
      ),

      GoRoute(
        path: AppRoutes.dashboard,
        name: RouteNames.dashboard,
        builder: (_, state) => DashboardPage(
          initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
        ),
      ),
    ],
  );
}
