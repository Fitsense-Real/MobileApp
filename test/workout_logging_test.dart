// Mobile-M4: recording a workout (M-10, M-11, M-12, M-13). The fake server
// keeps a live session like Backend generation 77b9df3 (PUT replaces the
// result of an exercise; contratos-backend-local.txt §5).
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/workouts/domain/workout_rules.dart';
import 'package:fitsense_mobile/features/workouts/presentation/exercise_detail_page.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/fake_backend.dart';

Json ex(int i, {String type = 'SETS_REPS', String? block}) => {
      'plannedExerciseId': 500 + i, 'exerciseId': 1000 + i, 'exerciseName': 'Ejercicio $i', 'exerciseOrder': i, 'prescriptionType': type,
      'plannedSets': 2, 'plannedReps': type == 'SETS_REPS' ? 10 : null, 'plannedDurationSeconds': type == 'DURATION' ? 60 : null,
      'targetLoadKg': null, 'restSeconds': 60, 'equipment': 'body weight', 'gifPath': null, 'safetyBlockReason': block,
    };

/// Live session server: start, PUT per exercise (replaces), finish.
class SessionServer {
  SessionServer(this.exercises);
  List<Json> exercises;
  Json? session;
  bool planUnreachable = false;
  final puts = <(int, Json)>[];
  int planReads = 0;
  Json? finished;

  Json get workout => {
        'plannedWorkoutId': 21, 'workoutName': 'Cuerpo completo', 'status': session == null ? 'SCHEDULED' : 'IN_PROGRESS',
        'scheduledDate': '2030-01-07', 'expiresAt': '2030-01-07T23:59:00-05:00', 'exercises': exercises,
      };

  FakeAnswer handle(RequestOptions o) {
    final route = '${o.method} ${o.path}';
    if (route == 'GET /users/me/plan/current') {
      planReads++;
      if (planUnreachable) throw connectionLost(o.path);
      return (status: 200, body: {'planId': 3, 'workouts': [workout]});
    }
    if (route == 'GET /sessions/current') return session == null ? (status: 204, body: null) : (status: 200, body: session);
    if (route == 'POST /workouts/21/start') {
      session = {'sessionId': 8, 'plannedWorkoutId': 21, 'startedAt': DateTime.now().toUtc().toIso8601String(), 'exercises': <Json>[]};
      return (status: 201, body: session);
    }
    final put = RegExp(r'^PUT /sessions/8/exercises/(\d+)$').firstMatch(route);
    if (put != null) {
      final id = int.parse(put.group(1)!);
      final body = Map<String, dynamic>.from(o.data as Map);
      puts.add((id, body));
      final planned = exercises.firstWhere((e) => e['plannedExerciseId'] == id);
      final pct = plannedTotal(planned) == 0 ? 0 : ((isDurationBased(planned) ? body['actualDurationSeconds'] : body['actualRepsTotal']) as num) / plannedTotal(planned) * 100;
      final record = {...body, 'plannedExerciseId': id, 'status': pct >= 100 ? 'COMPLETED' : pct > 0 ? 'PARTIAL' : 'SKIPPED', 'completionPercentage': pct};
      session = {...session!, 'exercises': [...jsonRows(session!['exercises']).where((r) => r['plannedExerciseId'] != id), record]};
      return (status: 200, body: session);
    }
    if (route == 'POST /sessions/8/finish') {
      finished = Map<String, dynamic>.from(o.data as Map);
      return (status: 200, body: {...session!, 'status': 'COMPLETED', 'completionPercentage': 100});
    }
    if (route == 'GET /users/me/pain-exclusions/effective' || route == 'GET /catalog/equipment-types') return (status: 200, body: []);
    return (status: 404, body: apiErrorBody(404, 'No encontrado'));
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<SessionServer> open(WidgetTester tester, List<Json> exercises, {bool started = false, Size size = const Size(1080, 6000), double ratio = 3}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final server = SessionServer(exercises);
    if (started) server.session = {'sessionId': 8, 'plannedWorkoutId': 21, 'startedAt': DateTime.now().toUtc().toIso8601String(), 'exercises': <Json>[]};
    final backend = ScriptedBackend(server.handle);
    await tester.pumpWidget(ProviderScope(overrides: [dioProvider.overrideWithValue(scriptedDio(backend))],
        child: MaterialApp(theme: AppTheme.light, home: PlannedWorkoutPage(workout: server.workout))));
    await tester.pumpAndSettle();
    return server;
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  group('M-13 actions always visible', () {
    testWidgets('«Comenzar entrenamiento» is visible without scrolling on a 320 × 568 phone, with «Ya lo hice» and «Omitir» next to it', (tester) async {
      await open(tester, [for (var i = 1; i <= 8; i++) ex(i)], size: const Size(640, 1136), ratio: 2);
      expect(find.text('Comenzar entrenamiento').hitTestable(), findsOneWidget);
      expect(find.text('Ya lo hice · registrar entrenamiento').hitTestable(), findsOneWidget);
      expect(find.text('Omitir entrenamiento').hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('how-to-start')), findsOneWidget);
      await leave(tester);
    });

    testWidgets('during the session the bar offers finishing, marking several and abandoning', (tester) async {
      await open(tester, [ex(1), ex(2)]);
      await tap(tester, find.text('Comenzar entrenamiento'));
      expect(find.text('Finalizar sesión').hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('mark-completed')), findsOneWidget);
      expect(find.text('Abandonar sesión'), findsOneWidget);
      expect(find.byKey(const Key('session-running')), findsOneWidget);
      await leave(tester);
    });
  });

  group('M-10 fast path with explicit confirmation', () {
    testWidgets('8 exercises recorded and the session finished in ≤ 12 taps; nothing preselected; same bodies as one by one', (tester) async {
      final exercises = [for (var i = 1; i <= 8; i++) ex(i, type: i == 8 ? 'DURATION' : 'SETS_REPS')];
      final server = await open(tester, exercises);
      var taps = 0;
      Future<void> t(Finder f) async { taps++; await tap(tester, f); }
      await t(find.text('Comenzar entrenamiento'));
      await t(find.byKey(const Key('mark-completed')));
      final boxes = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(boxes, hasLength(8));
      expect(boxes.every((b) => b.value == false), isTrue, reason: 'never marked for the person');
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirmo que los hice completos')).onPressed, isNull);
      await t(find.text('Seleccionar todos'));
      await t(find.text('Confirmo que hice completos 8'));
      expect(server.puts.map((p) => p.$1), [for (final e in exercises) e['plannedExerciseId']]);
      for (final (id, body) in server.puts) {
        expect(body, prescribedResult(exercises.firstWhere((e) => e['plannedExerciseId'] == id)), reason: 'exactly «Lo completé» (D-M1)');
      }
      expect(server.planReads, greaterThanOrEqualTo(8), reason: 'the routine is confirmed before each result (O20)');
      await t(find.text('Finalizar sesión'));
      expect(find.byKey(const Key('finish-summary')), findsOneWidget);
      expect(find.text('Completados: 8'), findsOneWidget);
      await t(find.byType(DropdownButtonFormField<int>).first);
      await t(find.text('6').last);
      await t(find.text('Finalizar'));
      expect(server.finished?['sessionRpe'], 6);
      expect(taps, lessThanOrEqualTo(12));
      await leave(tester);
    });

    testWidgets('only the ticked exercises are recorded; blocked (O20) ones are never offered', (tester) async {
      final server = await open(tester, [ex(1), ex(2), ex(3, block: 'dolor_registrado')], started: true);
      await tap(tester, find.byKey(const Key('mark-completed')));
      expect(find.byKey(const Key('mark-503')), findsNothing, reason: 'a blocked exercise can only be «No lo hice»');
      await tap(tester, find.byKey(const Key('mark-502')));
      await tap(tester, find.text('Confirmo que hice completos 1'));
      expect(server.puts.map((p) => p.$1), [502]);
      await leave(tester);
    });

    testWidgets('without connection the first result stays on the phone (P1) and nothing else is sent', (tester) async {
      final server = await open(tester, [ex(1), ex(2)], started: true);
      server.planUnreachable = true;
      await tap(tester, find.byKey(const Key('mark-completed')));
      await tap(tester, find.text('Seleccionar todos'));
      await tap(tester, find.text('Confirmo que hice completos 2'));
      expect(server.puts, isEmpty);
      expect(find.byKey(const Key('pending-results')), findsOneWidget);
      expect(find.text('Pendiente de enviar'), findsOneWidget, reason: 'stops at the first problem');
      await leave(tester);
    });
  });

  group('M-12 reporting pain', () {
    testWidgets('during the session: «Tengo dolor o molestias» + «Guardar» (2 taps) records it as not done for pain', (tester) async {
      final server = await open(tester, [ex(1), ex(2)], started: true);
      await tap(tester, find.byKey(const Key('pain-501')));
      expect(find.text('Si te duele, detén este ejercicio. Kora dejará de proponértelo, y también sus variantes equivalentes, en tus próximos planes.'), findsOneWidget);
      await tap(tester, find.text('Guardar'));
      expect(server.puts.single.$1, 501);
      expect(server.puts.single.$2, {'actualSets': 0, 'actualRepsTotal': 0, 'actualDurationSeconds': 0, 'actualLoadKg': 0, 'skipReason': 'PAIN_OR_DISCOMFORT'});
      await leave(tester);
    });

    testWidgets('already completed: «Paré antes» opens a partial for pain; «Lo terminé, pero me dolió» sends nothing (no contract yet)', (tester) async {
      final server = await open(tester, [ex(1)], started: true);
      await tap(tester, find.byKey(const Key('mark-completed')));
      await tap(tester, find.text('Seleccionar todos'));
      await tap(tester, find.text('Confirmo que hice completos 1'));
      expect(server.puts, hasLength(1));
      await tap(tester, find.byKey(const Key('pain-501')));
      await tap(tester, find.text('Lo terminé, pero me dolió'));
      expect(find.text('Todavía no se puede registrar'), findsOneWidget);
      await tap(tester, find.text('Entendido'));
      expect(server.puts, hasLength(1));
      await tap(tester, find.byKey(const Key('pain-501')));
      await tap(tester, find.text('Paré antes de terminar por dolor'));
      await tester.enterText(find.byKey(const Key('series-0')), '6');
      await tap(tester, find.text('Guardar'));
      expect(server.puts.last.$2, {'actualSets': 1, 'actualRepsTotal': 6, 'actualDurationSeconds': 0, 'actualLoadKg': null, 'skipReason': 'PAIN_OR_DISCOMFORT'});
      await leave(tester);
    });

    testWidgets('restriction added meanwhile: the dialog opened from the pain button only allows «No lo hice»', (tester) async {
      final server = await open(tester, [ex(1), ex(2)], started: true);
      server.exercises = [ex(1, block: 'dolor_registrado'), ex(2)];
      await tap(tester, find.byKey(const Key('pain-501')));
      expect(find.text('Lo completé'), findsNothing);
      expect(find.text('Lo hice parcialmente'), findsNothing);
      await tap(tester, find.text('Guardar'));
      expect(server.puts.single.$2['skipReason'], 'PAIN_OR_DISCOMFORT');
      await leave(tester);
    });

    testWidgets('from the exercise screen: «Tengo dolor o molestias» returns to the routine with the dialog open', (tester) async {
      final server = await open(tester, [ex(1), ex(2)], started: true);
      await tap(tester, find.text('Ver instrucciones').first);
      expect(find.byType(ExerciseDetailPage), findsOneWidget);
      await tap(tester, find.byKey(const Key('detail-report-pain')));
      expect(find.byType(ExerciseDetailPage), findsNothing);
      await tap(tester, find.text('Guardar'));
      expect(server.puts.single.$1, 501);
      await leave(tester);
    });

    testWidgets('without connection a pain report is kept on the phone, never sent blind (P1/O20)', (tester) async {
      final server = await open(tester, [ex(1)], started: true);
      server.planUnreachable = true;
      await tap(tester, find.byKey(const Key('pain-501')));
      await tap(tester, find.text('Guardar'));
      expect(server.puts, isEmpty);
      expect(find.byKey(const Key('pending-results')), findsOneWidget);
      await leave(tester);
    });
  });

  group('M-11 finishing', () {
    testWidgets('effort explained apart from pain and satisfaction; approved descriptions shown when configured', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => showDialog<Json>(context: context, builder: (_) => const FinishDialog(rpeDescriptions: {5: 'Descripción sintética de prueba'})),
        child: const Text('Abrir'),
      )))));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No es dolor ni satisfacción'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      expect(find.text('5 · Descripción sintética de prueba').last, findsOneWidget);
      expect(find.text('6').last, findsOneWidget, reason: 'levels without an approved description show only the number');
    });

    test('no descriptions are shipped until the study team approves them', () {
      expect(const FinishDialog().rpeDescriptions, isEmpty);
      expect(const FinishDialog().satisfactionDescriptions, isEmpty);
    });
  });
}
