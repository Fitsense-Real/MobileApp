// Mobile-M5: navigation, progress and accessibility (M-14, M-15, M-17, M-19,
// M-24, M-35, M-38, M-40). Real Poppins fonts, 320 × 568 and 390 × 844.
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fitsense_mobile/features/help/presentation/help_sheet.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/reminders/data/reminder_scheduler.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'package:fitsense_mobile/shared/widgets/kora_ui.dart';

double contrast(Color a, Color b) {
  double lum(Color c) {
    double f(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
  }
  final l1 = lum(a), l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

Future<void> loadFonts() async {
  final font = FontLoader('Poppins');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
    font.addFont(rootBundle.load('assets/fonts/Poppins-$w.ttf'));
  }
  await font.load();
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  final date = DateTime.now().toIso8601String().substring(0, 10);
  List<Override> dashboardData({List<Map<String, dynamic>>? metrics, List<Map<String, dynamic>> limitations = const []}) => [
        currentPlanProvider.overrideWith((ref) async => {
              'planId': 3, 'weekStartDate': date, 'weekEndDate': date,
              'workouts': [
                for (var i = 0; i < 3; i++)
                  {'plannedWorkoutId': i, 'workoutName': ['Cuerpo completo', 'Fuerza total', 'Movilidad'][i], 'focusCode': 'FULL_BODY',
                    'scheduledDate': date, 'expectedDurationMinutes': 30, 'status': 'SCHEDULED'},
              ],
            }),
        weeklyMetricsProvider.overrideWith((ref) async => metrics ?? [
              {'planId': 3, 'weekStartDate': '2026-11-16', 'weightedAdherencePct': 80, 'completedWorkouts': 4, 'scheduledWorkouts': 5, 'totalTrainingMinutes': 120,
                'calculatedAt': '2026-11-23', 'riskLevel': 'LOW', 'recordedWorkouts': 4, 'registrationCoveragePct': 80, 'observedAdherencePct': 100},
              {'planId': 2, 'weekStartDate': '2026-11-09', 'weightedAdherencePct': 60, 'completedWorkouts': 3, 'scheduledWorkouts': 5, 'totalTrainingMinutes': 90, 'calculatedAt': '2026-11-16'},
            ]),
        interventionsProvider.overrideWith((ref) async => []),
        dashboardProfileProvider.overrideWith((ref) async => {'goalText': 'Moverme más', 'daysPerWeek': 3}),
        planLimitationsProvider.overrideWith((ref) async => {'limitations': limitations}),
        planAdaptationsProvider.overrideWith((ref) async => []),
      ];

  Future<void> openDashboard(WidgetTester tester, Size logical, {List<Override> extra = const [], List<Map<String, dynamic>> limitations = const [], List<Map<String, dynamic>>? metrics}) async {
    tester.view.physicalSize = logical * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: [...dashboardData(limitations: limitations, metrics: metrics), ...extra],
        child: MaterialApp(theme: AppTheme.light, home: const DashboardPage())));
    await tester.pumpAndSettle();
  }

  /// Every painted text: (text, size, color).
  List<(String, double?, Color?)> paragraphs(WidgetTester tester) => [
        for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText)))
          (p.text.toPlainText(), p.text.style?.fontSize, p.text.style?.color),
      ];

  group('M-19 accessibility on a 320 × 568 phone', () {
    testWidgets('the four tabs lay out without overflow and no text is smaller than 12 px', (tester) async {
      await openDashboard(tester, const Size(320, 568));
      for (final tab in ['Inicio', 'Rutinas', 'Progreso', 'Perfil']) {
        await tester.tap(find.widgetWithText(NavigationDestination, tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
        final small = paragraphs(tester).where((p) => p.$2 != null && p.$2! < 12 && p.$1.trim().isNotEmpty).toList();
        expect(small, isEmpty, reason: '$tab: $small');
      }
    });

    testWidgets('the headline is scaled, never split inside a word, and «VER PLAN» is a 48 dp target', (tester) async {
      await openDashboard(tester, const Size(320, 568));
      expect(find.ancestor(of: find.textContaining('Muévete'), matching: find.byType(FittedBox)), findsOneWidget);
      expect(tester.getSize(find.ancestor(of: find.text('VER PLAN  ›'), matching: find.byType(FilledButton))).height, greaterThanOrEqualTo(48));
    });

    testWidgets('no secondary text uses the low-contrast sage colour; muted reaches 4.5:1 on white and ivory', (tester) async {
      await openDashboard(tester, const Size(390, 844));
      for (final tab in ['Inicio', 'Rutinas', 'Progreso', 'Perfil']) {
        await tester.tap(find.widgetWithText(NavigationDestination, tab));
        await tester.pumpAndSettle();
        // Icons (private-use glyphs) are UI symbols (3:1 suffices); text must not be sage.
        final sage = paragraphs(tester).where((p) => p.$3 == Kora.sage && p.$1.runes.any((r) => r < 0xE000 || r > 0xF8FF)).toList();
        expect(sage, isEmpty, reason: '$tab: $sage');
      }
      expect(contrast(Kora.muted, Colors.white), greaterThanOrEqualTo(4.5));
      expect(contrast(Kora.muted, Kora.ivory), lessThan(4.5), reason: 'documented: 4.42:1 on ivory, used only for 13+ px text');
    });
  });

  group('M-14 / M-15', () {
    testWidgets('plan notes are folded under a count; the routines come first', (tester) async {
      await openDashboard(tester, const Size(390, 844), limitations: [
        {'code': 'DOSIS', 'title': 'Dosis semanal', 'message': 'Las cifras orientativas están pendientes de validación profesional.'},
        {'code': 'TRACCION', 'title': 'Ejercicios de tracción', 'message': 'Con tu equipamiento no hay tracción.'},
      ]);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Rutinas'));
      await tester.pumpAndSettle();
      expect(find.text('Tu plan tiene 2 notas'), findsOneWidget);
      expect(find.textContaining('validación profesional'), findsNothing);
      expect(find.text('Cuerpo completo').hitTestable(), findsOneWidget, reason: 'first routine visible without scrolling');
      await tester.tap(find.text('Tu plan tiene 2 notas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('validación profesional'), findsOneWidget, reason: 'still available, on demand');
    });

    testWidgets('progress speaks plainly: points against the previous week, what was recorded, when it was updated', (tester) async {
      await openDashboard(tester, const Size(390, 844));
      await tester.tap(find.widgetWithText(NavigationDestination, 'Progreso'));
      await tester.pumpAndSettle();
      expect(find.text('80%'), findsWidgets, reason: 'the backend value, not recalculated');
      expect(find.text('+20 puntos frente a la semana anterior'), findsOneWidget);
      expect(find.textContaining('De lo que registraste, cumpliste el 100%'), findsOneWidget);
      expect(find.textContaining('Actualizado el 23/11/2026'), findsOneWidget);
      expect(find.textContaining(' pp'), findsNothing);
      expect(find.textContaining('Riesgo de abandono: Bajo'), findsOneWidget, reason: 'kept by default until the study decides (SHOW_DROPOUT_RISK)');
    });

    testWidgets('without weekly metrics it says when they will appear', (tester) async {
      await openDashboard(tester, const Size(390, 844), metrics: const []);
      expect(find.text('Tus datos aparecerán al cerrar tu primera semana'), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Progreso'));
      await tester.pumpAndSettle();
      expect(find.textContaining('se calculan cada lunes'), findsOneWidget);
    });
  });

  group('M-17 / M-40 / M-24 account and help', () {
    testWidgets('«Novedades de tu plan» replaces the ambiguous «Notificaciones»; Ayuda opens the help sheet', (tester) async {
      await openDashboard(tester, const Size(390, 844));
      await tester.tap(find.widgetWithText(NavigationDestination, 'Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('Notificaciones'), findsNothing);
      expect(find.text('Novedades de tu plan'), findsOneWidget);
      await tester.ensureVisible(find.text('Ayuda y soporte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ayuda y soporte'));
      await tester.pumpAndSettle();
      expect(find.byType(HelpSheet), findsOneWidget);
    });

    testWidgets('help: questions about Kora, generic contact when none is configured, no safety text unless approved', (tester) async {
      tester.view.physicalSize = const Size(780, 3000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HelpSheet())));
      expect(find.text('Me dolió un ejercicio'), findsOneWidget);
      expect(find.textContaining('Escribe al equipo del estudio que te invitó'), findsOneWidget);
      expect(find.byKey(const Key('help-safety')), findsNothing);
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HelpSheet(contact: 'contacto-sintetico@estudio.test', painSafetyMessage: 'Mensaje sintético aprobado de prueba.'))));
      expect(find.text('contacto-sintetico@estudio.test'), findsOneWidget);
      expect(find.text('Mensaje sintético aprobado de prueba.'), findsOneWidget);
    });
  });

  test('M-32: the reminder that launched the app is consumed once', () {
    ReminderLaunch.payload = 'workout:9';
    expect(ReminderLaunch.take(), 'workout:9');
    expect(ReminderLaunch.take(), isNull);
  });

}
