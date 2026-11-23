import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/auth_interceptor.dart';
import '../features/authentication/presentation/providers/auth_provider.dart';
import '../features/push/presentation/push_controller.dart';

import '../shared/theme/app_theme.dart';
import 'router/app_router.dart';
import 'session_expiry.dart';

class FitSenseApp extends ConsumerStatefulWidget {
  const FitSenseApp({
    super.key,
  });

  @override
  ConsumerState<FitSenseApp> createState() =>
      _FitSenseAppState();
}

class _FitSenseAppState
    extends ConsumerState<FitSenseApp> {

  ThemeMode _themeMode =
      ThemeMode.light;

  // ============================================================
  // CAMBIAR TEMA
  // ============================================================

  @override
  void initState() {
    super.initState();
    // Any request rejected with 401 (expired JWT) ends the session here.
    AuthInterceptor.onSessionExpired = () => handleSessionExpired(
      auth: ref.read(authViewModelProvider.notifier),
      router: AppRouter.router,
    );
    // Push notifications (Firebase kora-fitpe): the device is registered for
    // the signed-in user and a tapped notification opens its screen.
    pushRouter = AppRouter.router.go;
    ref.listenManual(authViewModelProvider.select((s) => s.user?.id),
        (_, userId) => ref.read(pushControllerProvider).onUser(userId), fireImmediately: true);
    // Back from the permission dialog, the phone settings or without network:
    // register what is still missing.
    _lifecycle = AppLifecycleListener(onResume: () => ref.read(pushControllerProvider).onResumed());
  }

  AppLifecycleListener? _lifecycle;

  @override
  void dispose() {
    AuthInterceptor.onSessionExpired = null;
    pushRouter = null;
    _lifecycle?.dispose();
    super.dispose();
  }

  void _setThemeMode(
      ThemeMode mode) {

    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(
      BuildContext context) {

    return MaterialApp.router(

      debugShowCheckedModeBanner:
      false,

      title: 'Kora',
      scaffoldMessengerKey: rootMessengerKey,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,

      // ==========================================================
      // TEMA CLARO
      // ==========================================================

      theme: AppTheme.light,

      // ==========================================================
      // TEMA OSCURO
      // ==========================================================

      darkTheme: AppTheme.dark,

      // ==========================================================
      // DEFAULT = OSCURO
      // ==========================================================

      themeMode: _themeMode,

      routerConfig:
      AppRouter.router,

      builder: (
          context,
          child,
          ) {

        return FitSenseThemeScope(
          themeMode: _themeMode,

          onThemeChanged:
          _setThemeMode,

          child:
          child ??
              const SizedBox.shrink(),
        );
      },
    );
  }
}

// ============================================================
// SCOPE GLOBAL DEL TEMA
// ============================================================
//
// Permite que cualquier pantalla pueda cambiar:
//
// ThemeMode.dark
//
// o:
//
// ThemeMode.light
//
// desde el menú de configuración.
//

class FitSenseThemeScope
    extends InheritedWidget {

  final ThemeMode themeMode;

  final ValueChanged<ThemeMode>
  onThemeChanged;

  const FitSenseThemeScope({
    super.key,

    required this.themeMode,

    required this.onThemeChanged,

    required super.child,
  });

  static FitSenseThemeScope
  of(BuildContext context) {

    final scope = context.dependOnInheritedWidgetOfExactType<
        FitSenseThemeScope>();

    assert(
    scope != null,
    'FitSenseThemeScope no encontrado en el árbol.',
    );

    return scope!;
  }

  @override
  bool updateShouldNotify(
      FitSenseThemeScope oldWidget) {

    return oldWidget.themeMode !=
        themeMode;
  }
}
