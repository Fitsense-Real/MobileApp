import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../shared/theme/app_theme.dart';
import 'router/app_router.dart';

class FitSenseApp extends StatefulWidget {
  const FitSenseApp({
    super.key,
  });

  @override
  State<FitSenseApp> createState() =>
      _FitSenseAppState();
}

class _FitSenseAppState
    extends State<FitSenseApp> {

  ThemeMode _themeMode =
      ThemeMode.light;

  // ============================================================
  // CAMBIAR TEMA
  // ============================================================

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
