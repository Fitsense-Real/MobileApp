import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

void main() {
  testWidgets('Four dashboard layouts render without overflow on a phone', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final font = FontLoader('Poppins');
    for (final weight in [
      'Regular',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      font.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentPlanProvider.overrideWith(
            (ref) async => {
              'planId': 3,
              'weekStartDate': date,
              'weekEndDate': date,
              'workouts': [
                for (var i = 0; i < 4; i++)
                  {
                    'plannedWorkoutId': i,
                    'workoutName': [
                      'Movilidad de cuerpo completo',
                      'Cardio en casa',
                      'Fuerza total',
                      'Sesión de recuperación',
                    ][i],
                    'focusCode': [
                      'CORE',
                      'LOWER_BODY',
                      'UPPER_BODY',
                      'FULL_BODY',
                    ][i],
                    'scheduledDate': date,
                    'expectedDurationMinutes': 20 + i * 5,
                    'status': 'SCHEDULED',
                  },
              ],
            },
          ),
          weeklyMetricsProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < 5; i++)
                {
                  'planId': 3,
                  'weekStartDate': DateTime(
                    2026,
                    10,
                    26 - i * 7,
                  ).toIso8601String().substring(0, 10),
                  'weightedAdherencePct': 84 - i * 9,
                  'completedWorkouts': 4,
                  'scheduledWorkouts': 5,
                  'totalTrainingMinutes': 120,
                  'calculatedAt': date,
                },
            ],
          ),
          interventionsProvider.overrideWith(
            (ref) async => [
              {
                'resultingPlanId': 3,
                'appliedAt': date,
                'messageShown':
                    'Ajustamos el volumen de tu plan según tus registros de la semana anterior.',
              },
            ],
          ),
          dashboardProfileProvider.overrideWith(
            (ref) async => {'goalText': 'Moverme más', 'daysPerWeek': 3},
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(key: boundary, child: const DashboardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final name in [
        'logo.png',
        'challenge.jpg',
        'mobility.jpg',
        'cardio.jpg',
        'strength.jpg',
        'full_body.jpg',
        'home_body.jpg',
      ]) {
        await precacheImage(
          AssetImage('assets/images/kora/$name'),
          boundary.currentContext!,
        );
      }
    });
    await tester.pumpAndSettle();
    for (final tab in ['Inicio', 'Rutinas', 'Progreso', 'Perfil']) {
      await tester.tap(find.widgetWithText(NavigationDestination, tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final picture = await render.toImage(pixelRatio: 1);
        final bytes = (await picture.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        await Directory('tmp/dashboard-preview').create(recursive: true);
        await File('tmp/dashboard-preview/$tab.png').writeAsBytes(bytes);
        picture.dispose();
      });
    }
    await tester.tap(find.widgetWithText(NavigationDestination, 'Rutinas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TREN INFERIOR'));
    await tester.pumpAndSettle();
    expect(find.text('Cardio en casa'), findsOneWidget);
    expect(find.text('Fuerza total'), findsNothing);
    await tester.tap(find.byTooltip('Buscar rutinas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('No hay rutinas para este filtro.'), findsOneWidget);
  });
}
