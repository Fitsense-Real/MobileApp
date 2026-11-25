import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/pain/data/pain_exclusion_repository.dart';
import 'package:fitsense_mobile/features/pain/domain/pain_safety.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_confirmation_sheet.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_exclusions_sheet.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_safety_notices.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';

// O20 (Backend PR #84): everything simulated with the backend's exact shapes
// (ESPEC_MOBILE_EXCLUSIONES.md). The backend is the only authority: the app
// never unblocks anything by itself.

// --- the backend's JSON -------------------------------------------------------

Json effectiveRow(int id, String name, String origin,
        {bool confirmed = false, bool provisional = false, bool confirmationRequired = false, int? from, String? fromName,
        String? level, int? source, String? date, bool? canIdentify, bool? canReactivate}) =>
    {
      'exerciseId': id, 'exerciseName': name, 'origin': origin, 'confirmed': confirmed, 'provisional': provisional,
      'confirmationRequired': confirmationRequired, 'derivedFromExerciseId': from, 'derivedFromExerciseName': fromName,
      'equivalenceLevel': level, 'equivalenceGroup': level == null ? null : 'G2-0xx front raise', 'equivalenceJustification': level == null ? null : 'mismo gesto',
      'sourcePlannedWorkoutId': source, 'eventDate': date,
      'canIdentify': canIdentify ?? (origin == 'DIRECT' && !confirmed), 'canReactivate': canReactivate ?? origin == 'DIRECT',
    };

/// The specification's example: 537 from a session with unidentified pain, 707 its provisional equivalent.
final specRows = [
  effectiveRow(537, 'Elevación frontal con mancuerna', 'DIRECT', source: 9123, date: '2026-01-09'),
  effectiveRow(707, 'Elevación frontal sentado con mancuerna', 'EQUIVALENT', provisional: true, from: 537,
      fromName: 'Elevación frontal con mancuerna', level: 'MISMO_GESTO'),
];

Json exercise(int pe, int id, String name, {String? block, int order = 1}) => {
  'plannedExerciseId': pe, 'exerciseId': id, 'exerciseName': name, 'exerciseOrder': order, 'prescriptionType': 'SETS_REPS',
  'plannedSets': 3, 'plannedReps': 10, 'plannedDurationSeconds': null, 'targetLoadKg': null, 'restSeconds': 60, 'safetyBlockReason': block,
};

Json workoutWith(List<Json> exercises, {int id = 9123, String status = 'SCHEDULED'}) => {
  'plannedWorkoutId': id, 'workoutName': 'Hombros', 'status': status, 'safetyBlocked': false, 'safetyBlockMessage': null,
  'scheduledDate': DateTime.now().toIso8601String().substring(0, 10),
  'expiresAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(), 'exercises': exercises,
};

// --- fakes ------------------------------------------------------------------------

class FakePain extends PainExclusionRepository {
  FakePain({List<Json>? effective, List<Json>? requests}) : effectiveRows = effective ?? [], requestRows = requests ?? [], super(Dio());
  List<Json> effectiveRows, requestRows;
  final identified = <Json>[];
  final reactivated = <int>[];
  Object? identifyError, reactivateError;
  Json identifyAnswer = {};
  int effectiveReads = 0;

  @override
  Future<List<Json>> list() async => const [];
  @override
  Future<List<EffectiveExclusion>> effective() async { effectiveReads++; return [for (final r in effectiveRows) EffectiveExclusion.fromJson(r)]; }
  @override
  Future<List<PainConfirmationRequest>> confirmationRequests() async => [for (final r in requestRows) PainConfirmationRequest.fromJson(r)];
  @override
  Future<IdentificationResult> identify(int exerciseId, {int? plannedWorkoutId, Set<int> unrelated = const {}}) async {
    identified.add({'exerciseId': exerciseId, 'plannedWorkoutId': plannedWorkoutId, 'unrelatedExerciseIds': unrelated.toList()..sort()});
    if (identifyError != null) throw identifyError!;
    return IdentificationResult.fromJson({'exerciseId': exerciseId, ...identifyAnswer});
  }
  @override
  Future<Json> reactivate(Object exerciseId, {String? comment}) async {
    reactivated.add(exerciseId as int);
    if (reactivateError != null) throw reactivateError!;
    effectiveRows = effectiveRows.where((r) => r['exerciseId'] != exerciseId && r['derivedFromExerciseId'] != exerciseId).toList();
    return {'exerciseId': exerciseId, 'candidatoHoy': true, 'nota': 'Vuelve a ser candidato.'};
  }
}

class FakePlans extends PlanRepository {
  FakePlans(this.plan) : super(Dio());
  Json? plan;
  int reads = 0;
  @override
  Future<Json?> current() async { reads++; return plan; }
  @override
  Future<List<Json>> adaptations() async => const [];
}

class FakeWorkouts extends WorkoutRepository {
  FakeWorkouts({this.session}) : super(Dio());
  Json? session;
  final recorded = <Json>[];
  final skipped = <String>[];
  Object? Function(Object plannedExerciseId, Json body)? recordError;
  @override
  Future<Json?> current() async => session;
  @override
  Future<Json> start(Object workoutId) async => session = {'sessionId': 77, 'plannedWorkoutId': workoutId, 'startedAt': DateTime.now().toIso8601String(), 'exercises': <Json>[]};
  @override
  Future<Json> record(Object sessionId, Object plannedExerciseId, Json body) async {
    final error = recordError?.call(plannedExerciseId, body);
    if (error != null) throw error;
    recorded.add({'plannedExerciseId': plannedExerciseId, ...body});
    final rows = [...jsonRows(session?['exercises'] ?? []).where((r) => r['plannedExerciseId'] != plannedExerciseId), {'plannedExerciseId': plannedExerciseId, ...body}];
    return session = {...?session, 'exercises': rows};
  }
  @override
  Future<void> skip(Object workoutId, String reason, {String? lackOfTimeContext, int? availableMinutes}) async => skipped.add(reason);
}

DioException http(int status, String message) {
  final options = RequestOptions(path: '/x');
  return DioException(requestOptions: options, response: Response(requestOptions: options, statusCode: status, data: {'status': status, 'message': message, 'details': []}));
}

Future<void> pumpPage(WidgetTester tester, Widget child, List<Override> overrides) async {
  tester.view.physicalSize = const Size(600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp(home: child)));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('contract parsing (exact fields of the backend)', () {
    test('/effective: DIRECT and its provisional EQUIVALENT, as in the specification', () {
      final rows = [for (final r in specRows) EffectiveExclusion.fromJson(r)];
      expect(rows[0].origin, PainOrigin.direct);
      expect(rows[0].confirmed, isFalse);
      expect(rows[0].canIdentify, isTrue);
      expect(rows[0].sourcePlannedWorkoutId, 9123);
      expect(rows[1].origin, PainOrigin.equivalent);
      expect(rows[1].provisional, isTrue);
      expect(rows[1].derivedFromExerciseId, 537);
      expect(rows[1].canReactivate, isFalse, reason: 'equivalents come back with the exercise they derive from');
      expect(PainOrigin.parse('ALGO_NUEVO'), PainOrigin.unknown);
    });

    test('/confirmation-requests and /identification answer', () {
      final r = PainConfirmationRequest.fromJson({'plannedWorkoutId': 9123, 'eventDate': '2026-01-09', 'confirmationRequired': true,
        'exercises': [{'exerciseId': 537, 'exerciseName': 'Elevación frontal con mancuerna'}, {'exerciseId': 578, 'exerciseName': 'Elevación lateral'}]});
      expect(r.exercises.map((e) => e.id), [537, 578]);
      final answer = IdentificationResult.fromJson({'exerciseId': 537, 'exclusionesConfirmadas': [1], 'identificadaEn': '2026-01-20T10:00:00Z',
        'equivalentesExcluidos': [538, 707], 'noRelacionadosLevantados': [578], 'noRelacionadosNoLevantados': {'150': 'equivalente del identificado'},
        'otrosDeLaSesionSiguenExcluidos': [988], 'nota': 'Listo.'});
      expect(answer.unrelatedLifted, [578]);
      expect(answer.unrelatedNotLifted, {150: 'equivalente del identificado'});
      expect(answer.stillExcludedFromSession, [988]);
    });
  });

  group('1–3 · why an exercise is blocked (no codes, no own interpretation)', () {
    final effective = [
      EffectiveExclusion.fromJson(effectiveRow(537, 'Elevación frontal con mancuerna', 'DIRECT', confirmed: true)),
      EffectiveExclusion.fromJson(effectiveRow(538, 'Elevación frontal v. 2', 'EQUIVALENT', confirmed: true, from: 537, fromName: 'Elevación frontal con mancuerna', level: 'VARIANTE_MISMO_EJERCICIO')),
      EffectiveExclusion.fromJson(effectiveRow(988, 'Press de pecho en máquina', 'PRECAUTION', provisional: true, from: 992, fromName: 'Press inclinado en máquina', level: 'PRECAUCION_OTRO_ANGULO')),
    ];

    test('1 · exercise blocked by pain', () {
      expect(blockExplanation(exercise(1, 537, 'x', block: 'dolor_registrado'), effective: effective), 'Lo marcaste con dolor.');
    });
    test('2 · equivalent variant excluded', () {
      expect(blockExplanation(exercise(2, 538, 'x', block: 'dolor_registrado'), effective: effective),
          'Es una variante de «Elevación frontal con mancuerna», que te dolió.');
    });
    test('3 · precaution for a change of angle (provisional)', () {
      expect(blockExplanation(exercise(3, 988, 'x', block: 'dolor_registrado'), effective: effective),
          'Es el mismo movimiento que «Press inclinado en máquina», con otro ángulo o apoyo, mientras confirmamos qué te dolió.');
    });
    test('2 · a provisional equivalent never says that it hurt (not known yet)', () {
      final provisional = EffectiveExclusion.fromJson(effectiveRow(707, 'Elevación frontal sentado', 'EQUIVALENT', provisional: true, from: 537, fromName: 'Elevación frontal con mancuerna', level: 'MISMO_GESTO'));
      expect(provisional.explanation, 'Es una variante de «Elevación frontal con mancuerna», de la sesión en la que reportaste dolor, mientras confirmamos qué te dolió.');
      final precaution = EffectiveExclusion.fromJson(effectiveRow(988, 'Press de pecho', 'PRECAUTION', confirmed: true, from: 992, fromName: 'Press inclinado', level: 'PRECAUCION_OTRO_ANGULO'));
      expect(precaution.explanation, 'Es el mismo movimiento que «Press inclinado», que te dolió, con otro ángulo o apoyo.');
    });
    test('pain plus a profile restriction; unknown codes stay generic; no block, no text', () {
      expect(blockExplanation(exercise(1, 537, 'x', block: 'suelo+dolor_registrado'), effective: effective),
          'Lo marcaste con dolor. No es compatible con lo que indicaste en tu perfil (trabajo en el suelo).');
      expect(blockExplanation(exercise(1, 999, 'x', block: 'dolor_registrado')), 'Está relacionado con un reporte de dolor.');
      expect(blockExplanation(exercise(1, 999, 'x', block: 'INC-CAT-1374')), 'Una revisión de seguridad lo retiró por ahora.');
      expect(blockExplanation(exercise(1, 537, 'x')), isNull, reason: 'only the backend blocks');
    });
  });

  group('4, 8, 12 · open routine', () {
    late FakePain pain;
    late FakePlans plans;
    late FakeWorkouts workouts;
    final blocked = exercise(41, 537, 'Elevación frontal con mancuerna', block: 'dolor_registrado');
    final allowed = exercise(42, 578, 'Sentadilla', order: 2);
    List<Override> overrides() => [
      painExclusionRepositoryProvider.overrideWithValue(pain),
      planRepositoryProvider.overrideWithValue(plans),
      workoutRepositoryProvider.overrideWithValue(workouts),
    ];

    setUp(() {
      pain = FakePain(effective: [effectiveRow(537, 'Elevación frontal con mancuerna', 'DIRECT', confirmed: true)]);
      plans = FakePlans({'planId': 1, 'workouts': [workoutWith([blocked, allowed])]});
      workouts = FakeWorkouts(session: {'sessionId': 77, 'plannedWorkoutId': 9123, 'startedAt': DateTime.now().toIso8601String(), 'exercises': <Json>[]});
    });

    testWidgets('4 · blocked and allowed in one session: the blocked one only as not done, the rest normally', (tester) async {
      await pumpPage(tester, PlannedWorkoutPage(workout: workoutWith([blocked, allowed])), overrides());
      expect(find.byKey(const Key('blocked-41')), findsOneWidget);
      expect(find.text('No disponible por ahora'), findsOneWidget);
      expect(find.textContaining('Lo marcaste con dolor.'), findsOneWidget);
      expect(find.textContaining('dolor_registrado'), findsNothing, reason: 'no technical codes');
      expect(find.byKey(const Key('blocked-42')), findsNothing);
      // Blocked: only «No lo hice» is offered.
      await tap(tester, find.text('Registrar ejercicio').at(0));
      expect(find.text('Lo completé'), findsNothing);
      expect(find.text('Lo hice parcialmente'), findsNothing);
      await tap(tester, find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.text('Dolor o molestias').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Si te duele, detén este ejercicio'), findsOneWidget);
      await tap(tester, find.text('Guardar'));
      expect(workouts.recorded.single, {'plannedExerciseId': 41, 'actualSets': 0, 'actualRepsTotal': 0, 'actualDurationSeconds': 0, 'actualLoadKg': 0, 'skipReason': 'PAIN_OR_DISCOMFORT'});
      // Allowed: completed as usual.
      await tap(tester, find.text('Registrar ejercicio').at(1));
      await tap(tester, find.text('Lo completé'));
      await tap(tester, find.text('Guardar'));
      expect(workouts.recorded.last['actualRepsTotal'], 30);
      expect(tester.takeException(), isNull);
    });

    testWidgets('8 · a 422 SESION_BLOQUEADA_POR_SEGURIDAD is explained and the routine is re-read from the backend', (tester) async {
      // On screen the exercise still looks allowed (stale list); the backend already blocked it.
      final stale = workoutWith([exercise(41, 537, 'Elevación frontal con mancuerna'), allowed]);
      plans.plan = {'planId': 1, 'workouts': [stale]};
      workouts.recordError = (pe, body) => pe == 41 && (body['actualSets'] as num) > 0
          ? http(422, 'SESION_BLOQUEADA_POR_SEGURIDAD: el ejercicio prescrito 41 ya no es seguro para ti (dolor_registrado). Solo puede registrarse como omitido.')
          : null;
      await pumpPage(tester, PlannedWorkoutPage(workout: stale), overrides());
      expect(find.byKey(const Key('blocked-41')), findsNothing);
      plans.plan = {'planId': 1, 'workouts': [workoutWith([blocked, allowed])]}; // what the backend has now
      final readsBefore = plans.reads;
      await tap(tester, find.text('Registrar ejercicio').at(0));
      await tap(tester, find.text('Lo completé'));
      await tap(tester, find.text('Guardar'));
      expect(find.textContaining('ya no puede registrarse con trabajo realizado'), findsOneWidget);
      expect(plans.reads, greaterThan(readsBefore), reason: 'the plan is read again');
      expect(find.byKey(const Key('blocked-41')), findsOneWidget, reason: 'updated state recovered');
      expect(workouts.recorded, isEmpty);
      // The session goes on with what is still allowed.
      await tap(tester, find.text('Registrar ejercicio').at(1));
      await tap(tester, find.text('Lo completé'));
      await tap(tester, find.text('Guardar'));
      expect(workouts.recorded.single['plannedExerciseId'], 42);
    });

    testWidgets('12 · reopening the app: block and records come back from the backend, without duplicates', (tester) async {
      workouts.session = {'sessionId': 77, 'plannedWorkoutId': 9123, 'startedAt': DateTime.now().toIso8601String(),
        'exercises': [{'plannedExerciseId': 42, 'actualSets': 3, 'actualRepsTotal': 30, 'actualDurationSeconds': 0, 'status': 'COMPLETED', 'completionPercentage': 100}]};
      // The app restarts with an old copy of the routine (nothing blocked).
      await pumpPage(tester, PlannedWorkoutPage(workout: workoutWith([exercise(41, 537, 'Elevación frontal con mancuerna'), allowed])), overrides());
      expect(find.byKey(const Key('blocked-41')), findsOneWidget);
      expect(find.text('Completado'), findsOneWidget);
      expect(find.textContaining('Guardado: 3 series'), findsOneWidget, reason: 'one record, not two');
    });
  });

  group('5–7 · pain without an identified exercise', () {
    final request = {'plannedWorkoutId': 9123, 'eventDate': '2026-01-09', 'confirmationRequired': false, 'exercises': [
      {'exerciseId': 537, 'exerciseName': 'Elevación frontal con mancuerna'},
      {'exerciseId': 578, 'exerciseName': 'Elevación lateral'},
      {'exerciseId': 150, 'exerciseName': 'Elevación frontal con barra'},
    ]};

    testWidgets('5 · skipping for pain re-reads the plan and offers, without insisting, to say which one', (tester) async {
      final pain = FakePain(requests: [request]);
      final plans = FakePlans({'planId': 1, 'workouts': [workoutWith([exercise(41, 537, 'Elevación frontal con mancuerna')])]});
      final workouts = FakeWorkouts();
      await pumpPage(tester, PlannedWorkoutPage(workout: workoutWith([exercise(41, 537, 'Elevación frontal con mancuerna')])), [
        painExclusionRepositoryProvider.overrideWithValue(pain),
        planRepositoryProvider.overrideWithValue(plans),
        workoutRepositoryProvider.overrideWithValue(workouts),
      ]);
      await tap(tester, find.text('Omitir entrenamiento'));
      await tap(tester, find.text('Dolor o molestias'));
      expect(workouts.skipped, ['PAIN_OR_DISCOMFORT']);
      expect(find.text('Gracias por avisar'), findsOneWidget);
      await tap(tester, find.text('Indicar ahora'));
      expect(find.text('¿Qué ejercicio te dolió?'), findsOneWidget);
      expect(find.byKey(const Key('painful-578')), findsOneWidget);
    });

    Future<FakePain> openSheet(WidgetTester tester, {Json? answer, Object? error}) async {
      final pain = FakePain(effective: [for (final e in jsonRows(request['exercises'])) effectiveRow(e['exerciseId'] as int, '${e['exerciseName']}', 'DIRECT', source: 9123)], requests: [request]);
      pain.identifyAnswer = answer ?? {};
      pain.identifyError = error;
      await pumpPage(tester, Scaffold(body: PainConfirmationSheet(request: PainConfirmationRequest.fromJson(request))), [
        painExclusionRepositoryProvider.overrideWithValue(pain),
        planRepositoryProvider.overrideWithValue(FakePlans(null)),
      ]);
      return pain;
    }

    testWidgets('6 · later identification of the exercise that hurt', (tester) async {
      final pain = await openSheet(tester, answer: {'equivalentesExcluidos': [538], 'otrosDeLaSesionSiguenExcluidos': [578, 150], 'nota': 'Identificado.'});
      await tap(tester, find.text('Enviar'));
      expect(find.text('Elige qué ejercicio te dolió.'), findsOneWidget);
      expect(pain.identified, isEmpty);
      await tap(tester, find.byKey(const Key('painful-537')));
      final reads = pain.effectiveReads;
      await tap(tester, find.text('Enviar'));
      expect(pain.identified.single, {'exerciseId': 537, 'plannedWorkoutId': 9123, 'unrelatedExerciseIds': <int>[]});
      expect(find.textContaining('Registramos que te dolió «Elevación frontal con mancuerna»'), findsOneWidget);
      expect(find.text('• Elevación lateral'), findsOneWidget, reason: 'not named: still excluded');
      expect(pain.effectiveReads, greaterThanOrEqualTo(reads), reason: 'exclusions re-read after the answer');
    });

    testWidgets('7 · the ones that had nothing to do with it; the backend can keep some', (tester) async {
      final pain = await openSheet(tester, answer: {
        'noRelacionadosLevantados': [578],
        'noRelacionadosNoLevantados': {'150': 'Es una variante equivalente del ejercicio que te dolió.'},
      });
      await tap(tester, find.byKey(const Key('unrelated-537')));
      await tap(tester, find.byKey(const Key('painful-537')));
      // The painful one can never be marked as unrelated at the same time.
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('unrelated-537'))).value, isFalse);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('unrelated-537'))).onChanged, isNull);
      await tap(tester, find.byKey(const Key('unrelated-578')));
      await tap(tester, find.byKey(const Key('unrelated-150')));
      await tap(tester, find.text('Enviar'));
      expect(pain.identified.single, {'exerciseId': 537, 'plannedWorkoutId': 9123, 'unrelatedExerciseIds': [150, 578]});
      expect(find.text('Vuelven a poder proponerse:'), findsOneWidget);
      expect(find.text('• Elevación lateral'), findsOneWidget);
      expect(find.text('Siguen sin proponerse por seguridad:'), findsOneWidget);
      expect(find.textContaining('Elevación frontal con barra: Es una variante equivalente'), findsOneWidget);
    });

    test('7 · the same rule before sending (the backend checks it again with 422)', () {
      final r = PainConfirmationRequest.fromJson(request);
      expect(identificationProblem(r, 537, {537}), contains('no puede ser a la vez'));
      expect(identificationProblem(r, 537, {999}), 'Solo puedes indicar ejercicios de esta sesión.');
      expect(identificationProblem(r, 999, {}), 'Ese ejercicio no es de esta sesión.');
      expect(identificationProblem(r, 537, {578}), isNull);
    });

    testWidgets('8 · a 422 from /identification is shown and nothing is assumed lifted', (tester) async {
      final pain = await openSheet(tester, error: http(422, 'El ejercicio 999 no esta pendiente de confirmar en esa sesion.'));
      await tap(tester, find.byKey(const Key('painful-537')));
      await tap(tester, find.text('Enviar'));
      expect(pain.identified, hasLength(1));
      expect(find.textContaining('no esta pendiente de confirmar'), findsOneWidget);
      expect(find.text('Vuelven a poder proponerse:'), findsNothing);
      expect(find.text('Enviar'), findsOneWidget, reason: 'can answer again');
    });
  });

  group('9–11 · exclusions over time, reactivation and NO_FACTIBLE', () {
    testWidgets('9 · after two weeks the exclusion is still there and Kora asks actively', (tester) async {
      final pain = FakePain(
        effective: [
          effectiveRow(537, 'Elevación frontal con mancuerna', 'DIRECT', confirmationRequired: true, source: 9123, date: '2026-01-09'),
          effectiveRow(707, 'Elevación frontal sentado', 'EQUIVALENT', provisional: true, confirmationRequired: true, from: 537, fromName: 'Elevación frontal con mancuerna', level: 'MISMO_GESTO'),
        ],
        requests: [{'plannedWorkoutId': 9123, 'eventDate': '2026-01-09', 'confirmationRequired': true, 'exercises': [{'exerciseId': 537, 'exerciseName': 'Elevación frontal con mancuerna'}]}],
      );
      final overrides = [painExclusionRepositoryProvider.overrideWithValue(pain), planRepositoryProvider.overrideWithValue(FakePlans(null))];
      await pumpPage(tester, const Scaffold(body: PainSafetyNotices()), overrides);
      expect(find.textContaining('¿Recuerdas qué ejercicio te dolió el'), findsOneWidget);
      await pumpPage(tester, const Scaffold(body: PainExclusionsSheet()), overrides);
      expect(find.byKey(const Key('effective-537')), findsOneWidget, reason: 'still excluded: nothing expires by itself');
      expect(find.byKey(const Key('effective-707')), findsOneWidget);
      expect(find.textContaining('mientras confirmamos qué te dolió'), findsOneWidget);
    });

    testWidgets('an early request is listed in Perfil but not pushed on Inicio', (tester) async {
      final pain = FakePain(requests: [{'plannedWorkoutId': 1, 'eventDate': '2026-01-09', 'confirmationRequired': false, 'exercises': [{'exerciseId': 5, 'exerciseName': 'X'}]}]);
      await pumpPage(tester, const Scaffold(body: PainSafetyNotices()), [painExclusionRepositoryProvider.overrideWithValue(pain), planRepositoryProvider.overrideWithValue(FakePlans(null))]);
      expect(find.textContaining('¿Recuerdas'), findsNothing);
    });

    testWidgets('10 · reactivation the backend authorizes: the exercise and its equivalents leave the list', (tester) async {
      final pain = FakePain(effective: [
        effectiveRow(537, 'Elevación frontal con mancuerna', 'DIRECT', confirmed: true),
        effectiveRow(538, 'Elevación frontal v. 2', 'EQUIVALENT', confirmed: true, from: 537, fromName: 'Elevación frontal con mancuerna', level: 'VARIANTE_MISMO_EJERCICIO'),
      ]);
      await pumpPage(tester, const Scaffold(body: PainExclusionsSheet()), [painExclusionRepositoryProvider.overrideWithValue(pain), planRepositoryProvider.overrideWithValue(FakePlans(null))]);
      expect(find.text('Ya no me duele'), findsOneWidget, reason: 'only the DIRECT one has the action');
      await tap(tester, find.text('Ya no me duele'));
      await tap(tester, find.text('Ya no tengo dolor'));
      expect(pain.reactivated, [537]);
      expect(find.byKey(const Key('effective-537')), findsNothing);
      expect(find.byKey(const Key('effective-538')), findsNothing);
    });

    testWidgets('10 · a reactivation the backend refuses (422) keeps the exclusion', (tester) async {
      final pain = FakePain(effective: [effectiveRow(537, 'Elevación frontal con mancuerna', 'DIRECT', confirmed: true)])
        ..reactivateError = http(422, 'REACTIVACION_RECHAZADA_POR_SEGURIDAD: el ejercicio 537 choca con una restriccion vigente.');
      await pumpPage(tester, const Scaffold(body: PainExclusionsSheet()), [painExclusionRepositoryProvider.overrideWithValue(pain), planRepositoryProvider.overrideWithValue(FakePlans(null))]);
      await tap(tester, find.text('Ya no me duele'));
      await tap(tester, find.text('Ya no tengo dolor'));
      expect(find.byKey(const Key('effective-537')), findsOneWidget);
      expect(find.textContaining('choca con una restriccion vigente'), findsOneWidget);
    });

    test('11 · adaptation NO_FACTIBLE: a clear explanation instead of the code', () {
      final text = notFeasibleExplanation({'resultado': 'NO_FACTIBLE_POR_SEGURIDAD', 'motivoTexto': 'Conservar habría vuelto a publicar lo que dolió.'})!;
      expect(text, startsWith('Kora no ha podido adaptar esa parte del entrenamiento debido a las restricciones actuales.'));
      expect(text, contains('Conservar habría vuelto a publicar lo que dolió.'));
      expect(text, isNot(contains('NO_FACTIBLE')));
      expect(notFeasibleExplanation({'resultado': 'ADAPTACION_APLICADA'}), isNull);
      final now = DateTime(2026, 1, 20);
      expect(recentNotFeasibleAdaptation([{'weekStartDate': '2026-01-19', 'resultado': 'NO_FACTIBLE'}, {'weekStartDate': '2026-01-12', 'resultado': 'ADAPTACION_APLICADA'}], now: now), isNotNull);
      expect(recentNotFeasibleAdaptation([{'weekStartDate': '2025-12-01', 'resultado': 'NO_FACTIBLE'}], now: now), isNull, reason: 'an old one is not shown');
      expect(recentNotFeasibleAdaptation([{'weekStartDate': '2026-01-19', 'resultado': 'ADAPTACION_APLICADA'}, {'weekStartDate': '2026-01-12', 'resultado': 'NO_FACTIBLE'}], now: now), isNull, reason: 'superseded');
    });
  });
}
