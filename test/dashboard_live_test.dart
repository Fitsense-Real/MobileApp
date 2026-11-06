import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/network/auth_interceptor.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

class ApiAdapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    calls.add(options);
    final Object data = switch (options.path) {
      '/users/me/metrics/weekly' => [{'weekStartDate': '2026-10-19'}, {'weekStartDate': '2026-10-26'}],
      '/users/me/interventions' => [],
      '/sessions/current' => {'sessionId': 8, 'plannedWorkoutId': 21},
      _ => {'sessionId': 8, 'planId': 3},
    };
    return ResponseBody.fromString(jsonEncode(data), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Dashboard and execution use JWT and exact API contracts', () async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'dashboard-token'});
    final adapter = ApiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'))..httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor());
    final dashboard = DashboardRepository(dio);
    expect((await dashboard.metrics()).first['weekStartDate'], '2026-10-26');
    expect(await dashboard.interventions(), isEmpty);
    await dashboard.runCycle();
    final workouts = WorkoutRepository(dio);
    await workouts.current(); await workouts.start(21);
    await workouts.record(8, 31, {'actualSets': 2, 'actualRepsTotal': 20});
    await workouts.finish(8, {'sessionRpe': 7}); await workouts.abandon(8);
    await workouts.skip(21, 'FATIGUE');
    final report = {'performedAt': '2026-10-27T18:30:00Z', 'sessionRpe': 7, 'exercises': [{'plannedExerciseId': 31, 'actualSets': 3, 'actualRepsTotal': 30}]};
    await workouts.report(21, report);
    expect(adapter.calls.map((e) => '${e.method} ${e.path}'), [
      'GET /users/me/metrics/weekly', 'GET /users/me/interventions', 'POST /cycle/run-for-me', 'GET /sessions/current',
      'POST /workouts/21/start', 'PUT /sessions/8/exercises/31', 'POST /sessions/8/finish', 'POST /sessions/8/abandon', 'POST /workouts/21/skip', 'POST /workouts/21/report',
    ]);
    expect(adapter.calls[2].data, isNull); expect(adapter.calls[4].data, isNull);
    expect(adapter.calls[5].data, {'actualSets': 2, 'actualRepsTotal': 20});
    expect(adapter.calls[8].data, {'reason': 'FATIGUE'});
    expect(adapter.calls.last.data, report);
    for (final request in adapter.calls) { expect(request.headers['Authorization'], 'Bearer dashboard-token'); }
  });

  testWidgets('Dashboard renders server plan, metrics and interventions and refreshes', (tester) async {
    tester.view.physicalSize = const Size(420, 900); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    var progress = 37;
    var loads = 0;
    // Relative to today: the home tab only lists today's and upcoming workouts.
    final day = DateTime.now().add(const Duration(days: 1));
    final scheduled = day.toIso8601String().substring(0, 10);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentPlanProvider.overrideWith((ref) async => {'planId': 3, 'weekStartDate': '2026-10-26', 'weekEndDate': '2026-11-01', 'workouts': [{'plannedWorkoutId': 21, 'workoutName': 'Rutina enviada por servidor', 'scheduledDate': scheduled, 'expectedDurationMinutes': 25, 'status': 'SCHEDULED', 'exercises': []}]}),
      weeklyMetricsProvider.overrideWith((ref) async { loads++; return [{'weekStartDate': '2026-10-19', 'weekEndDate': '2026-10-25', 'weightedAdherencePct': progress, 'completedWorkouts': 1, 'scheduledWorkouts': 3, 'totalTrainingMinutes': 25}]; }),
      interventionsProvider.overrideWith((ref) async => [{'messageShown': 'Ajuste real recibido', 'appliedAt': '2026-10-26'}]),
      dashboardProfileProvider.overrideWith((ref) async => {'goalText': 'Objetivo del usuario'}),
    ], child: MaterialApp(theme: AppTheme.light, home: const DashboardPage())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Rutina enviada por servidor'), 180, scrollable: find.byType(Scrollable).first);
    expect(find.text('Rutina enviada por servidor'), findsOneWidget);
    expect(find.text(trainingDay(scheduled)), findsOneWidget);
    expect(find.text('Programado'), findsWidgets);
    expect(find.text('Full body suave'), findsNothing);
    await tester.tap(find.text('Rutinas')); await tester.pumpAndSettle();
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('FUERZA'), findsNothing);
    expect(find.text('CARDIO'), findsNothing);
    await tester.tap(find.text('Progreso')); await tester.pumpAndSettle();
    expect(find.text('37%'), findsOneWidget);
    progress = 62;
    await tester.tap(find.byTooltip('Actualizar datos')); await tester.pumpAndSettle();
    expect(find.text('62%'), findsOneWidget); expect(loads, greaterThan(1));
    await tester.scrollUntilVisible(find.text('Ajuste real recibido'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Ajuste real recibido'), findsOneWidget);
    expect(find.text('Procesar ciclo semanal'), findsNothing);
    await tester.tap(find.text('Perfil')); await tester.pumpAndSettle();
    expect(find.byTooltip('Editar perfil'), findsNothing);
    await tester.scrollUntilVisible(find.text('Cuenta'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Cuenta')); await tester.pumpAndSettle();
    // The profile can be edited (PUT /users/me/profile) once it exists.
    expect(find.text('Editar perfil'), findsOneWidget);
    expect(find.textContaining('lunes siguiente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty metrics and a failed plan do not invent progress or routines', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      currentPlanProvider.overrideWith((ref) async => throw Exception('Unavailable')),
      weeklyMetricsProvider.overrideWith((ref) async => []),
      interventionsProvider.overrideWith((ref) async => []),
      dashboardProfileProvider.overrideWith((ref) async => null),
    ], child: MaterialApp(theme: AppTheme.light, home: const DashboardPage())));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Progreso')); await tester.pumpAndSettle();
    expect(find.textContaining('Todavía no hay métricas'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
  });

  testWidgets('Session effort is mandatory before finishing', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => showDialog<void>(context: context, builder: (_) => const FinishDialog()), child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar')); await tester.pumpAndSettle();
    expect(find.text('Selecciona el esfuerzo percibido'), findsOneWidget);
  });
}
