// O20 · stale routines. Before sending any result the app confirms the routine with the backend
// (GET /users/me/plan/current, at most 8 s). If it cannot confirm it — no network, slow answer,
// 401, 422 — it sends nothing: no answer never means «allowed». The result stays on the phone
// and can be sent again once the routine is confirmed. Simulated backend with its exact shapes.
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/pain/data/pain_exclusion_repository.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/presentation/exercise_result_dialog.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'pain_o20_test.dart' show FakePain, FakeWorkouts, exercise, workoutWith, http, pumpPage, tap, effectiveRow;

/// The plan as the backend answers it: a value, an error, or an answer that has not arrived yet.
class ControlledPlans extends PlanRepository {
  ControlledPlans(this.plan) : super(Dio());
  Json? plan;
  Object? error;
  Completer<Json?>? gate;
  int reads = 0;
  @override
  Future<Json?> current() async {
    reads++;
    if (gate != null) return gate!.future;
    if (error != null) throw error!;
    return plan;
  }
  @override
  Future<List<Json>> adaptations() async => const [];
}

DioException offline() => DioException(requestOptions: RequestOptions(path: '/users/me/plan/current'), type: DioExceptionType.connectionError);

void main() {
  late FakePain pain;
  late ControlledPlans plans;
  late FakeWorkouts workouts;
  final allowed = exercise(42, 578, 'Sentadilla', order: 2);
  final squatBlocked = exercise(42, 578, 'Sentadilla', order: 2, block: 'dolor_registrado');
  final other = exercise(41, 120, 'Plancha');
  Json planWith(List<Json> exercises) => {'planId': 1, 'workouts': [workoutWith(exercises)]};
  List<Override> overrides() => [
    painExclusionRepositoryProvider.overrideWithValue(pain),
    planRepositoryProvider.overrideWithValue(plans),
    workoutRepositoryProvider.overrideWithValue(workouts),
  ];

  setUp(() {
    pain = FakePain(effective: [effectiveRow(578, 'Sentadilla', 'DIRECT', confirmed: true)]);
    plans = ControlledPlans(planWith([other, allowed]));
    workouts = FakeWorkouts(session: {'sessionId': 77, 'plannedWorkoutId': 9123, 'startedAt': DateTime.now().toIso8601String(), 'exercises': <Json>[]});
  });

  Future<void> open(WidgetTester tester) => pumpPage(tester, PlannedWorkoutPage(workout: workoutWith([other, allowed])), overrides());

  /// Opens the dialog of the squat and saves «Lo completé».
  Future<void> completeSquat(WidgetTester tester, {Duration wait = Duration.zero}) async {
    await tap(tester, find.text('Registrar ejercicio').at(1));
    if (wait > Duration.zero) { await tester.pump(wait); await tester.pumpAndSettle(); }
    await tap(tester, find.text('Lo completé'));
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    if (wait > Duration.zero) await tester.pump(wait);
    await tester.pumpAndSettle();
  }

  void expectKeptNotSent(WidgetTester tester) {
    expect(workouts.recorded, isEmpty, reason: 'nothing sent without confirming the routine');
    expect(find.byKey(const Key('pending-results')), findsOneWidget);
    expect(find.text('Pendiente de enviar'), findsOneWidget);
  }

  Future<void> retryAndExpectOneRecord(WidgetTester tester) async {
    await tap(tester, find.text('Reintentar envío'));
    expect(workouts.recorded.length, 1);
    expect(workouts.recorded.single['plannedExerciseId'], 42);
    expect(workouts.recorded.single['actualRepsTotal'], 30);
    expect(find.byKey(const Key('pending-results')), findsNothing);
  }

  group('1–4 · the plan cannot be confirmed: nothing is sent, the result is kept, and it can be retried', () {
    testWidgets('1 · the connection fails', (tester) async {
      await open(tester);
      plans.error = offline();
      await completeSquat(tester);
      expectKeptNotSent(tester);
      expect(find.textContaining('No pudimos confirmar con el servidor que tu rutina sigue vigente'), findsOneWidget);
      plans.error = null;
      await retryAndExpectOneRecord(tester);
    });

    testWidgets('2 · the backend takes more than 8 seconds', (tester) async {
      await open(tester);
      plans.gate = Completer<Json?>(); // never answers
      await completeSquat(tester, wait: const Duration(seconds: 9));
      expectKeptNotSent(tester);
      plans.gate = null;
      await retryAndExpectOneRecord(tester);
    });

    testWidgets('3 · the plan request answers 401', (tester) async {
      await open(tester);
      plans.error = http(401, 'Unauthorized');
      await completeSquat(tester);
      expectKeptNotSent(tester);
    });

    testWidgets('4 · the plan request answers 422', (tester) async {
      await open(tester);
      plans.error = http(422, 'No procesable');
      await completeSquat(tester);
      expectKeptNotSent(tester);
    });
  });

  group('5 · the backend answers a plan different from the one on screen', () {
    testWidgets('the exercise was blocked meanwhile: work is not sent; only «No lo hice» is offered', (tester) async {
      await open(tester);
      await tap(tester, find.text('Registrar ejercicio').at(1));
      await tap(tester, find.text('Lo completé'));
      plans.plan = planWith([other, squatBlocked]); // the block arrives while the dialog is open
      await tap(tester, find.text('Guardar'));
      expect(workouts.recorded, isEmpty);
      expect(find.textContaining('tiene ahora una restricción por seguridad'), findsWidgets);
      expect(find.byKey(const Key('blocked-42')), findsOneWidget);
      expect(find.byKey(const Key('pending-results')), findsNothing, reason: 'it will never be sent');
      expect(find.byKey(const Key('held-results')), findsOneWidget, reason: 'kept on screen for review, not applied');
      expect(find.textContaining('Revisa la rutina actualizada'), findsWidgets);
      await tap(tester, find.text('Registrar ejercicio').at(1));
      expect(find.text('Lo completé'), findsNothing);
      expect(find.text('Lo hice parcialmente'), findsNothing);
    });

    testWidgets('the routine left the plan (a new version): nothing is sent and it cannot be edited', (tester) async {
      await open(tester);
      await tap(tester, find.text('Registrar ejercicio').at(1));
      await tap(tester, find.text('Lo completé'));
      plans.plan = {'planId': 2, 'workouts': [workoutWith([other], id: 9999)]};
      await tap(tester, find.text('Guardar'));
      expect(workouts.recorded, isEmpty);
      expect(find.textContaining('ya no forma parte'), findsWidgets);
      expect(find.text('Registrar ejercicio'), findsNothing);
    });

    testWidgets('a blocked exercise on screen that the backend still allows: the dialog follows the backend', (tester) async {
      // The screen is older than a reactivation: the backend's answer decides, not the copy.
      await pumpPage(tester, PlannedWorkoutPage(workout: workoutWith([other, squatBlocked])), overrides());
      await tap(tester, find.text('Registrar ejercicio').at(1));
      expect(find.text('Lo completé'), findsOneWidget);
    });
  });

  testWidgets('6 · the connection drops while sending: kept, never duplicated when retried', (tester) async {
    await open(tester);
    var failures = 1;
    workouts.recordError = (pe, body) => failures-- > 0
        ? DioException(requestOptions: RequestOptions(path: '/sessions/77/exercises/42'), type: DioExceptionType.connectionError)
        : null;
    await completeSquat(tester);
    expectKeptNotSent(tester);
    expect(find.textContaining('Se perdió la conexión al enviar el resultado'), findsOneWidget);
    await retryAndExpectOneRecord(tester);
  });

  group('6 · lost answer: before repeating, the app asks the backend what it has', () {
    testWidgets('the request had arrived: it is not sent again', (tester) async {
      final lossy = LossyWorkouts(session: workouts.session);
      workouts = lossy;
      await open(tester);
      await completeSquat(tester);
      expect(lossy.puts, 1);
      expect(find.byKey(const Key('pending-results')), findsOneWidget);
      expect(find.textContaining('comprobará si el servidor ya lo recibió'), findsOneWidget);
      final reads = lossy.currentReads;
      await tap(tester, find.text('Reintentar envío'));
      expect(lossy.currentReads, greaterThan(reads), reason: 'GET /sessions/current before repeating');
      expect(lossy.puts, 1, reason: 'already saved: nothing repeated');
      expect(lossy.recorded.length, 1);
      expect(find.byKey(const Key('pending-results')), findsNothing);
      expect(find.text('Pendiente de enviar'), findsNothing);
    });

    testWidgets('the session was closed meanwhile: the result is held, never sent', (tester) async {
      var failures = 1;
      workouts.recordError = (pe, body) => failures-- > 0
          ? DioException(requestOptions: RequestOptions(path: '/sessions/77/exercises/42'), type: DioExceptionType.connectionError)
          : null;
      await open(tester);
      await completeSquat(tester);
      workouts.session = null; // the backend closed the session (finished elsewhere or stale)
      await tap(tester, find.text('Reintentar envío'));
      expect(workouts.recorded, isEmpty);
      expect(find.byKey(const Key('held-results')), findsOneWidget);
      expect(find.textContaining('La sesión ya no está abierta'), findsOneWidget);
    });

    testWidgets('the session cannot be checked: kept, not sent again', (tester) async {
      final lossy = LossyWorkouts(session: workouts.session)..losses = 1;
      workouts = lossy;
      await open(tester);
      await completeSquat(tester);
      lossy.currentError = offline();
      await tap(tester, find.text('Reintentar envío'));
      expect(lossy.puts, 1);
      expect(find.byKey(const Key('pending-results')), findsOneWidget);
      expect(find.textContaining('No pudimos comprobar si el servidor recibió tu resultado'), findsOneWidget);
    });
  });

  group('pending result, exclusion recorded later, «Reintentar envío»: the old result is never sent', () {
    Future<void> partialSquat(WidgetTester tester) async {
      await tap(tester, find.text('Registrar ejercicio').at(1));
      await tap(tester, find.text('Lo hice parcialmente'));
      await tester.enterText(find.widgetWithText(TextFormField, 'Repeticiones totales (todas las series)'), '12');
      await tester.enterText(find.widgetWithText(TextFormField, 'Series realizadas'), '1');
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.text('Fatiga').last);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Guardar'));
    }

    for (final (kind, enter) in [('completed', null), ('partial', partialSquat)]) {
      testWidgets('$kind result', (tester) async {
        await open(tester);
        plans.error = offline(); // the connection drops before sending
        if (enter == null) { await completeSquat(tester); } else { await enter(tester); }
        expectKeptNotSent(tester);
        // Meanwhile the backend records an exclusion for that exercise.
        plans.plan = planWith([other, squatBlocked]);
        plans.error = null;
        final reads = plans.reads;
        await tap(tester, find.text('Reintentar envío'));
        expect(plans.reads, greaterThan(reads), reason: 'the current plan is read again');
        expect(workouts.recorded, isEmpty, reason: 'the old result is not sent');
        expect(find.byKey(const Key('pending-results')), findsNothing);
        expect(find.byKey(const Key('held-results')), findsOneWidget);
        expect(find.text('Retenido: no se enviará'), findsOneWidget);
        expect(find.textContaining('Revisa la rutina actualizada'), findsWidgets);
        expect(find.byKey(const Key('blocked-42')), findsOneWidget);
        // The only valid result now: «No lo hice». It replaces the held one; one record, no duplicates.
        await tap(tester, find.text('Registrar ejercicio').at(1));
        expect(find.text('Lo completé'), findsNothing);
        expect(find.text('Lo hice parcialmente'), findsNothing);
        await tap(tester, find.byType(DropdownButtonFormField<String>));
        await tester.tap(find.text('Dolor o molestias').last);
        await tester.pumpAndSettle();
        await tap(tester, find.text('Guardar'));
        expect(workouts.recorded.single, {'plannedExerciseId': 42, 'actualSets': 0, 'actualRepsTotal': 0, 'actualDurationSeconds': 0, 'actualLoadKg': 0, 'skipReason': 'PAIN_OR_DISCOMFORT'});
        expect(find.byKey(const Key('held-results')), findsNothing);
      });
    }

    testWidgets('back from the background: the pending result is checked again and held, without sending', (tester) async {
      await open(tester);
      plans.error = offline();
      await completeSquat(tester);
      plans.plan = planWith([other, squatBlocked]);
      plans.error = null;
      for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused,
                           AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(workouts.recorded, isEmpty);
      expect(find.byKey(const Key('held-results')), findsOneWidget);
      expect(find.byKey(const Key('pending-results')), findsNothing);
    });

    testWidgets('a held result can be discarded', (tester) async {
      await open(tester);
      plans.error = offline();
      await completeSquat(tester);
      plans.plan = planWith([other, squatBlocked]);
      plans.error = null;
      await tap(tester, find.text('Reintentar envío'));
      await tap(tester, find.byKey(const Key('discard-42')));
      expect(find.byKey(const Key('held-results')), findsNothing);
      expect(workouts.recorded, isEmpty);
    });
  });

  testWidgets('7 · the app goes to the background while the plan is being read: one dialog, one record', (tester) async {
    await open(tester);
    final answer = Completer<Json?>();
    plans.gate = answer;
    await tester.tap(find.text('Registrar ejercicio').at(1));
    await tester.pump();
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused,
                         AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    plans.gate = null;
    answer.complete(planWith([other, allowed]));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseResultDialog), findsOneWidget);
    await tap(tester, find.text('Lo completé'));
    await tap(tester, find.text('Guardar'));
    expect(workouts.recorded.length, 1);
  });

  group('8 · two actions on the same exercise at the same time', () {
    testWidgets('two taps on «Registrar ejercicio» while the plan is being read: one dialog', (tester) async {
      await open(tester);
      final answer = Completer<Json?>();
      plans.gate = answer;
      final where = tester.getCenter(find.text('Registrar ejercicio').at(1));
      await tester.tapAt(where);
      await tester.pump();
      await tester.tapAt(where); // the same place: the button is busy now
      await tester.pump();
      plans.gate = null;
      answer.complete(planWith([other, allowed]));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseResultDialog), findsOneWidget);
      await tap(tester, find.text('Lo completé'));
      await tap(tester, find.text('Guardar'));
      expect(workouts.recorded.length, 1);
    });

    testWidgets('two taps on «Reintentar envío»: one record', (tester) async {
      await open(tester);
      plans.error = offline();
      await completeSquat(tester);
      plans.error = null;
      final answer = Completer<Json?>();
      plans.gate = answer;
      await tester.tap(find.text('Reintentar envío'));
      await tester.pump();
      await tester.tap(find.text('Reintentar envío'), warnIfMissed: false);
      await tester.pump();
      plans.gate = null;
      answer.complete(planWith([other, allowed]));
      await tester.pumpAndSettle();
      expect(workouts.recorded.length, 1);
    });
  });

  group('retroactive report on a routine that cannot be confirmed', () {
    Future<void> fillReport(WidgetTester tester) async {
      await tap(tester, find.text('Ya lo hice · registrar entrenamiento'));
      for (final i in [0, 1]) {
        await tap(tester, find.text('Registrar ejercicio').at(i));
        await tap(tester, find.text('Lo completé'));
        await tap(tester, find.text('Usar resultado'));
      }
    }

    testWidgets('no network or a slow answer: nothing sent, every draft kept; later it goes on', (tester) async {
      final reported = <Json>[];
      workouts = ReportingWorkouts(reported);
      await open(tester);
      await fillReport(tester);
      plans.error = offline();
      await tap(tester, find.text('Guardar entrenamiento'));
      expect(reported, isEmpty);
      expect(find.textContaining('Tus resultados siguen guardados en este teléfono'), findsOneWidget);
      expect(find.text('Sin registrar'), findsNothing, reason: 'both drafts kept');
      plans.error = null;
      plans.gate = Completer<Json?>();
      await tester.tap(find.text('Guardar entrenamiento'));
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(reported, isEmpty);
      expect(find.text('Finalizar entrenamiento'), findsNothing);
      plans.gate = null;
      await tap(tester, find.text('Guardar entrenamiento'));
      expect(find.text('Finalizar entrenamiento'), findsOneWidget, reason: 'confirmed: the report can be finished');
    });
  });
}

class ReportingWorkouts extends FakeWorkouts {
  ReportingWorkouts(this.sent);
  final List<Json> sent;
  @override
  Future<Json?> current() async => null;
  @override
  Future<Json> report(Object workoutId, Json body) async { sent.add(body); return {'completionPercentage': 100}; }
}

/// The PUT reaches the backend (it is saved) but the answer is lost [losses] times.
class LossyWorkouts extends FakeWorkouts {
  LossyWorkouts({super.session});
  int losses = 1, puts = 0, currentReads = 0;
  Object? currentError;
  @override
  Future<Json?> current() async {
    currentReads++;
    if (currentError != null) throw currentError!;
    return super.current();
  }
  @override
  Future<Json> record(Object sessionId, Object plannedExerciseId, Json body) async {
    puts++;
    final saved = await super.record(sessionId, plannedExerciseId, body);
    if (losses-- > 0) throw DioException(requestOptions: RequestOptions(path: '/sessions/$sessionId/exercises/$plannedExerciseId'), type: DioExceptionType.connectionError);
    return saved;
  }
}
