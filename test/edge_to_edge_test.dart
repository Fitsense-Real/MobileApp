import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/login_page.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/register_page.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/onboarding/presentation/onboarding_page.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/system_bars.dart';
import 'support/welcome_fakes.dart';

/// Android 16 (targetSdk 36) always draws edge to edge. These screens are
/// checked with a status bar, a navigation bar and, where there is typing,
/// the keyboard: no fixed control may end up under them.
class _Profile extends ProfileRepository {
  _Profile() : super(Dio());
  @override
  Future<Map<String, dynamic>?> fetch() async => null;
  @override
  Future<List<Equipment>> equipment() async => [const Equipment('band', 'Banda', false)];
}

Future<void> pumpScreen(WidgetTester tester, Widget app, {Size size = const Size(390, 844), double textScale = 1, double keyboard = 0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MediaQuery(data: edgeToEdge(size, textScale: textScale, keyboard: keyboard), child: app));
  await tester.pumpAndSettle();
}

String iso(DateTime d) => d.toIso8601String().substring(0, 10);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Widget auth(String location) {
    final router = GoRouter(initialLocation: location, routes: [
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterPage()),
    ]);
    return ProviderScope(child: MaterialApp.router(routerConfig: router, theme: AppTheme.light));
  }

  for (final location in [AppRoutes.login, AppRoutes.register]) {
    testWidgets('$location: nothing under the system bars, also with the keyboard open', (tester) async {
      await pumpScreen(tester, auth(location));
      expectNothingUnderSystemBars(tester, where: location);
      await pumpScreen(tester, auth(location), size: const Size(360, 740), textScale: 1.5, keyboard: 300);
      expect(tester.takeException(), isNull);
      expectNothingUnderSystemBars(tester, keyboard: 300, where: '$location with keyboard');
    });
  }

  testWidgets('dashboard: the four tabs and the navigation bar stay out of the system bars', (tester) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(start.year, start.month, start.day + 6);
    await pumpScreen(tester, ProviderScope(overrides: [
      currentPlanProvider.overrideWith((ref) async => {
            'planId': 1, 'weekStartDate': iso(start), 'weekEndDate': iso(end),
            'workouts': [{'plannedWorkoutId': 21, 'workoutName': 'Tren superior', 'scheduledDate': iso(start), 'expectedDurationMinutes': 40, 'status': 'SCHEDULED', 'exercises': []}],
          }),
      weeklyMetricsProvider.overrideWith((ref) async => []),
      interventionsProvider.overrideWith((ref) async => []),
      dashboardProfileProvider.overrideWith((ref) async => null),
    ], child: MaterialApp(theme: AppTheme.light, home: const DashboardPage())));
    for (final tab in ['Inicio', 'Rutinas', 'Progreso', 'Perfil']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectNothingUnderSystemBars(tester, where: 'tab $tab');
    }
  });

  testWidgets('profile form: header and fields out of the system bars, also with the keyboard', (tester) async {
    final router = GoRouter(initialLocation: '/onboarding', routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
    ]);
    Widget app() => ProviderScope(overrides: [
          authViewModelProvider.overrideWith(SignedIn.new),
          profileRepositoryProvider.overrideWithValue(_Profile()),
        ], child: MaterialApp.router(routerConfig: router, theme: AppTheme.light, locale: const Locale('es'),
            supportedLocales: const [Locale('es')], localizationsDelegates: GlobalMaterialLocalizations.delegates));
    await pumpScreen(tester, app());
    expectNothingUnderSystemBars(tester, where: 'profile step 1');
    await pumpScreen(tester, app(), size: const Size(360, 740), textScale: 1.5, keyboard: 300);
    expect(tester.takeException(), isNull);
    expectNothingUnderSystemBars(tester, keyboard: 300, where: 'profile step 1 with keyboard');
  });
}
