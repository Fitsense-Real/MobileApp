// O20, final validation against a running backend (Fitsense-Real/backend generation 98276a9: O20 + V65).
// Skipped unless KORA_LIVE_API_BASE_URL is set. Creates its own synthetic accounts (rules engine, AI off):
//
//   KORA_LIVE_API_BASE_URL=http://localhost:8080/api/v1 flutter test test/live/o20_validacion_live_test.dart
//
// Everything goes through the app's real repositories (PainExclusionRepository, PlanRepository,
// WorkoutRepository) and the app's own rules (blockExplanation, identificationProblem, isUnsafeExercise).
// Every request body the app sends is captured and printed: what is printed is what the backend received.
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/pain/data/pain_exclusion_repository.dart';
import 'package:fitsense_mobile/features/pain/domain/pain_safety.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/domain/workout_rules.dart';

final env = Platform.environment;
final base = env['KORA_LIVE_API_BASE_URL'];
const password = 'Sintetica-o20-x9';

// ignore: avoid_print
void log(String line) => print('O20 $line');

/// One signed-in app: its Dio (with the JWT, as the app's) and the three repositories.
class App {
  App(this.dio) : pain = PainExclusionRepository(dio), plans = PlanRepository(dio), workouts = WorkoutRepository(dio);
  final Dio dio;
  final PainExclusionRepository pain;
  final PlanRepository plans;
  final WorkoutRepository workouts;

  /// Bodies of every POST/PUT the app sent, as `METHOD path body`.
  final sent = <String>[];
  String get lastSent => sent.last;

  static Future<App> login(String email) async {
    final token = (await Dio(BaseOptions(baseUrl: base!)).post('/auth/login', data: {'email': email, 'password': password})).data['token'];
    final dio = Dio(BaseOptions(baseUrl: base!, contentType: Headers.jsonContentType, headers: {'Authorization': 'Bearer $token'}));
    final app = App(dio);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method != 'GET') app.sent.add('${options.method} ${options.path} ${options.data == null ? '' : jsonEncode(options.data)}');
      handler.next(options);
    }));
    return app;
  }

  Future<Json> plan() async => (await plans.current())!;
  Future<Set<int>> effectiveIds() async => {for (final e in await pain.effective()) e.exerciseId};
}

/// A synthetic participant with a profile and a first plan from the rules engine.
Future<String> createAccount(String tag, {required bool gym}) async {
  final email = 'o20val-$tag-${DateTime.now().microsecondsSinceEpoch}@e2e.local';
  final anon = Dio(BaseOptions(baseUrl: base!, contentType: Headers.jsonContentType));
  await anon.post('/auth/register', data: {'email': email, 'password': password, 'firstName': 'Sintetico', 'timezone': 'America/Lima', 'acceptsStudyParticipation': true});
  final app = await App.login(email);
  await app.dio.post('/users/me/profile', data: profile(gym: gym));
  await app.dio.post('/users/me/plan/generation');
  for (var i = 0; i < 40 && await app.plans.current() == null; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  expect(await app.plans.current(), isNotNull, reason: 'first plan of $email');
  return email;
}

Json profile({required bool gym, bool allowFloor = true}) => {
  'birthDate': '1995-03-10', 'heightCm': 170, 'currentWeightKg': 70, 'fitnessLevel': gym ? 'INTERMEDIATE' : 'BEGINNER',
  'goalType': 'GENERAL_FITNESS', 'goalText': 'Sentirme mejor', 'trainingLocation': gym ? 'GYM' : 'HOME', 'daysPerWeek': 3,
  'availableDays': [1, 2, 3, 4, 5, 6, 7], 'sessionMinutes': 45, if (!gym) 'equipmentCodes': ['body weight'], 'allowFloorExercises': allowFloor,
};

List<Json> workoutsOf(Json plan) => jsonRows(plan['workouts'] ?? []);
List<Json> exercisesOf(Json w) => jsonRows(w['exercises'] ?? []);
int idOf(Json e) => (e['exerciseId'] as num).toInt();
bool painBlocked(Json e) => '${e['safetyBlockReason']}'.contains(painBlockCode);
Json notDone(String reason) => {'actualSets': 0, 'actualRepsTotal': 0, 'actualDurationSeconds': 0, 'actualLoadKg': 0, 'skipReason': reason};

/// Status and message of a refused request.
Future<String> refused(Future<Object?> Function() call) async {
  try {
    await call();
  } on DioException catch (e) {
    final data = e.response?.data;
    return '${e.response?.statusCode} ${data is Map ? data['message'] : data}';
  }
  fail('the backend accepted it');
}

/// Text shown to the user: plain language, never a backend code.
void expectPlain(String? text) {
  expect(text, isNotNull);
  expect(RegExp(r'[a-z]+_[a-z]+|[A-Z]{3,}_[A-Z]+').hasMatch(text!), isFalse, reason: 'technical code in «$text»');
}

void main() {
  final skip = base == null ? 'KORA_LIVE_API_BASE_URL not set (needs a running backend)' : false;
  late String emailA;
  late Json skippedA;
  late Set<int> skippedIdsA;
  int? sessionWorkoutA;
  late Set<int> sessionRecordsA;

  test('S1 S4 S5 S8 · pain skip, blocked prescriptions, 422 on live and retroactive records, session with the rest', () async {
    emailA = await createAccount('a', gym: false);
    final app = await App.login(emailA);
    final before = await app.plan();
    log('cuenta A (casa, peso corporal): plan ${before['planId']} semana ${before['weekStartDate']}, ${workoutsOf(before).length} entrenamientos');

    // S5: skip a workout for pain, without saying which exercise.
    skippedA = workoutsOf(before).where(canSkipWorkout).first;
    skippedIdsA = {for (final e in exercisesOf(skippedA)) idOf(e)};
    await app.workouts.skip(skippedA['plannedWorkoutId'], 'PAIN_OR_DISCOMFORT');
    log('S5 acción: omitir ${skippedA['plannedWorkoutId']} por dolor → ${app.lastSent}');
    final requests = await app.pain.confirmationRequests();
    final request = requests.singleWhere((r) => r.plannedWorkoutId == skippedA['plannedWorkoutId']);
    expect({for (final e in request.exercises) e.id}, skippedIdsA);
    expect(request.confirmationRequired, isFalse);
    log('S5 GET /pain-exclusions/confirmation-requests → sesión ${request.plannedWorkoutId} (${request.eventDate}), '
        '${request.exercises.length} ejercicios, confirmationRequired=false (aún no se pide de forma activa)');
    final effective = await app.pain.effective();
    expect(effective.where((e) => e.origin == PainOrigin.direct).map((e) => e.exerciseId).toSet(), containsAll(skippedIdsA));
    log('S5 GET /pain-exclusions/effective → ${effective.where((e) => e.origin == PainOrigin.direct).length} DIRECT sin confirmar, '
        '${effective.where((e) => e.origin != PainOrigin.direct).length} derivadas');

    // S1: the plan read again marks exactly those prescriptions; the app explains them without codes.
    final after = await app.plan();
    final excluded = {for (final e in effective) e.exerciseId};
    Json? workout;
    for (final w in workoutsOf(after).where(isOpenWorkout)) {
      for (final e in exercisesOf(w)) {
        expect(painBlocked(e), excluded.contains(idOf(e)), reason: 'prescription ${e['plannedExerciseId']}');
        expect(isUnsafeExercise(e), painBlocked(e) || e['safetyBlockReason'] != null);
      }
      if (workout == null && canStartWorkout(w) && exercisesOf(w).any(painBlocked) && exercisesOf(w).any((e) => !isUnsafeExercise(e))) workout = w;
    }
    expect(workout, isNotNull, reason: 'an open workout that repeats an excluded exercise');
    final blocked = exercisesOf(workout!).firstWhere(painBlocked);
    final allowed = exercisesOf(workout).where((e) => !isUnsafeExercise(e)).toList();
    final text = blockExplanation(blocked, effective: effective);
    expectPlain(text);
    log('S1 GET /plan/current → entrenamiento ${workout['plannedWorkoutId']}: prescripción ${blocked['plannedExerciseId']} '
        '«${blocked['exerciseName']}» safetyBlockReason=${blocked['safetyBlockReason']}; safetyBlocked=${workout['safetyBlocked']}');
    log('S1 Flutter muestra: «No disponible por ahora. $text»');

    // S8 (retroactive report): work on the blocked exercise is refused; nothing is recorded.
    final reportBody = {
      'performedAt': DateTime.now().toUtc().toIso8601String(), 'sessionRpe': 6,
      'exercises': [for (final e in exercisesOf(workout)) {'plannedExerciseId': e['plannedExerciseId'], ...prescribedResult(e)}],
    };
    final reportRefusal = await refused(() => app.workouts.report(workout!['plannedWorkoutId'], reportBody));
    expect(reportRefusal, startsWith('422 SESION_BLOQUEADA_POR_SEGURIDAD'));
    final still = workoutsOf(await app.plan()).firstWhere((w) => w['plannedWorkoutId'] == workout!['plannedWorkoutId']);
    expect(workoutStatusOf(still), 'SCHEDULED', reason: 'nothing recorded');
    log('S8 POST /workouts/${workout['plannedWorkoutId']}/report con trabajo en el bloqueado → $reportRefusal; el entrenamiento sigue ${workoutStatusOf(still)}');

    // S4: live session. Blocked: work and partial work refused, not done accepted. The rest normally.
    final session = await app.workouts.start(workout['plannedWorkoutId']);
    sessionWorkoutA = workout['plannedWorkoutId'];
    final full = await refused(() => app.workouts.record(session['sessionId'], blocked['plannedExerciseId'], prescribedResult(blocked)));
    expect(full, startsWith('422 SESION_BLOQUEADA_POR_SEGURIDAD'));
    final partial = await refused(() => app.workouts.record(session['sessionId'], blocked['plannedExerciseId'],
        {...prescribedResult(blocked), 'actualSets': 1, 'actualRepsTotal': 3, 'skipReason': 'PAIN_OR_DISCOMFORT'}));
    expect(partial, startsWith('422 SESION_BLOQUEADA_POR_SEGURIDAD'));
    log('S4 PUT /sessions/${session['sessionId']}/exercises/${blocked['plannedExerciseId']} completo → $full');
    log('S4 PUT … mismo ejercicio parcial (1 serie, 3 reps) → $partial');
    await app.workouts.record(session['sessionId'], blocked['plannedExerciseId'], notDone('PAIN_OR_DISCOMFORT'));
    log('S4 PUT … como no realizado → 200 (${app.lastSent})');
    for (final e in allowed) {
      await app.workouts.record(session['sessionId'], e['plannedExerciseId'], prescribedResult(e));
    }
    final others = exercisesOf(workout).where((e) => isUnsafeExercise(e) && e['plannedExerciseId'] != blocked['plannedExerciseId']);
    for (final e in others) {
      await app.workouts.record(session['sessionId'], e['plannedExerciseId'], notDone('PAIN_OR_DISCOMFORT'));
    }
    final finished = await app.workouts.finish(session['sessionId'], {'sessionRpe': 6, 'activeMinutes': 30});
    sessionRecordsA = {for (final r in jsonRows(finished['exercises'])) (r['plannedExerciseId'] as num).toInt()};
    expect(sessionRecordsA.length, exercisesOf(workout).length, reason: 'one record per exercise, no duplicates');
    log('S4 ${allowed.length} permitidos completados → 200; finalizar → ${finished['status']} ${finished['completionPercentage']} % '
        '(${sessionRecordsA.length} registros, uno por ejercicio)');
  }, skip: skip);

  test('S12 · a new login (app closed and reopened): the same restrictions and history, from the backend', () async {
    final app = await App.login(emailA); // a new Dio, new repositories, nothing from the previous run
    final effective = await app.pain.effective();
    expect(effective.map((e) => e.exerciseId).toSet(), containsAll(skippedIdsA));
    final plan = await app.plan();
    final done = workoutsOf(plan).firstWhere((w) => w['plannedWorkoutId'] == sessionWorkoutA);
    expect(const {'COMPLETED', 'PARTIAL'}, contains(workoutStatusOf(done)));
    final blockedNow = [for (final w in workoutsOf(plan).where(isOpenWorkout)) ...exercisesOf(w).where(painBlocked)];
    expect(blockedNow.every((e) => effective.any((x) => x.exerciseId == idOf(e))), isTrue);
    final history = await app.plans.history();
    expect(history.any((p) => p['planId'] == plan['planId']), isTrue);
    log('S12 nuevo inicio de sesión: /effective ${effective.length} exclusiones (las mismas); entrenamiento $sessionWorkoutA sigue '
        '${workoutStatusOf(done)}; ${blockedNow.length} prescripciones abiertas siguen bloqueadas; plan ${plan['planId']} en /plans');
  }, skip: skip);

  test('S6 S7 S8 S10 · identification with unrelatedExerciseIds, invalid answers, reactivation refused and authorized', () async {
    final app = await App.login(emailA);
    final request = (await app.pain.confirmationRequests()).singleWhere((r) => r.plannedWorkoutId == skippedA['plannedWorkoutId']);
    final ids = request.exercises.map((e) => e.id).toList();
    final painful = ids[0];
    final unrelated = {ids[1], ids[2]};

    // S8 (identification): what the app refuses before sending, and what the backend refuses.
    expect(identificationProblem(request, painful, {painful}), contains('no puede ser a la vez'));
    final same = await refused(() => app.pain.identify(painful, plannedWorkoutId: request.plannedWorkoutId, unrelated: {painful}));
    expect(same, startsWith('422'));
    log('S8 identificado también como no relacionado: la app lo rechaza («${identificationProblem(request, painful, {painful})}»); '
        'si se enviara → $same');
    final foreign = workoutsOf(await app.plan()).expand(exercisesOf).map(idOf).firstWhere((id) => !ids.contains(id));
    expect(identificationProblem(request, painful, {foreign}), 'Solo puedes indicar ejercicios de esta sesión.');
    final foreignRefusal = await refused(() => app.pain.identify(painful, plannedWorkoutId: request.plannedWorkoutId, unrelated: {foreign}));
    log('S8 no relacionado de otra sesión ($foreign): la app lo rechaza; si se enviara → $foreignRefusal');
    final notInSession = await refused(() => app.pain.identify(foreign, plannedWorkoutId: request.plannedWorkoutId));
    log('S8 identificar un ejercicio que no es de esa sesión ($foreign) → $notInSession');
    final stillAll = await app.effectiveIds();
    expect(stillAll, containsAll(ids), reason: 'a refused answer lifts nothing');

    // S6 + S7: the answer the app sends, exactly.
    final answer = await app.pain.identify(painful, plannedWorkoutId: request.plannedWorkoutId, unrelated: unrelated);
    log('S7 petición enviada: ${app.lastSent}');
    expect(app.lastSent, endsWith('{"confirmPain":true,"plannedWorkoutId":${request.plannedWorkoutId},"unrelatedExerciseIds":${jsonEncode(unrelated.toList()..sort())}}'));
    log('S6/S7 respuesta 200: levantados ${answer.unrelatedLifted}, no levantados ${answer.unrelatedNotLifted}, '
        'siguen excluidos ${answer.stillExcludedFromSession}, equivalentes ${answer.equivalentsExcluded}, nota «${answer.note}»');
    final effective = await app.pain.effective();
    final row = effective.firstWhere((e) => e.exerciseId == painful && e.origin == PainOrigin.direct);
    expect(row.confirmed, isTrue);
    expect(row.canIdentify, isFalse);
    expect(row.explanation, 'Lo marcaste con dolor.');
    expect({...answer.unrelatedLifted, ...answer.unrelatedNotLifted.keys}, unrelated);
    for (final id in answer.unrelatedLifted) {
      expect(effective.any((e) => e.exerciseId == id && e.origin == PainOrigin.direct), isFalse, reason: 'lifted $id');
    }
    for (final id in ids.where((id) => id != painful && !unrelated.contains(id))) {
      expect(effective.any((e) => e.exerciseId == id), isTrue, reason: 'not named, still excluded: $id');
    }
    final plan = await app.plan();
    for (final w in workoutsOf(plan).where(isOpenWorkout)) {
      for (final e in exercisesOf(w)) {
        expect(painBlocked(e), effective.any((x) => x.exerciseId == idOf(e)), reason: 'plan follows /effective: ${e['plannedExerciseId']}');
      }
    }
    log('S6 /effective: $painful confirmado (canIdentify=false), explicación «${row.explanation}»; S7 los no relacionados '
        'levantados ya no están; los no nombrados siguen; el plan releído sigue exactamente a /effective');
    final again = await refused(() => app.pain.identify(painful, plannedWorkoutId: request.plannedWorkoutId));
    expect(again, startsWith('404'));
    log('S8 identificar dos veces → $again');

    // S10 refused: the backend only reactivates with an explicit confirmation, and only a direct exclusion.
    // (A participant's profile cannot change once there is a plan, so REACTIVACION_RECHAZADA_POR_SEGURIDAD,
    // a profile restriction that appears later, cannot be produced with real flows here.)
    final unconfirmed = await refused(() => app.dio.post('/users/me/pain-exclusions/$painful/reactivation', data: {'confirmNoPain': false}));
    expect(unconfirmed, startsWith('4'));
    expect(await app.effectiveIds(), contains(painful));
    log('S10 reactivar sin confirmación explícita (confirmNoPain=false) → $unconfirmed; sigue excluido');
    final derived = (await app.pain.effective()).where((e) => e.origin != PainOrigin.direct).toList();
    for (final d in derived) {
      expect(d.canReactivate, isFalse, reason: 'the app offers no reactivation for ${d.exerciseId}');
      final refusal = await refused(() => app.pain.reactivate(d.exerciseId));
      expect(refusal, startsWith('404'));
      expect(await app.effectiveIds(), contains(d.exerciseId));
      log('S10 reactivar el derivado ${d.origin.name.toUpperCase()} ${d.exerciseId} (canReactivate=false, la app no lo ofrece) → $refusal; sigue excluido');
    }

    // S10 authorized: the identified one leaves /effective with its derived entries.
    final reactivation = await app.pain.reactivate(painful, comment: 'prueba sintética');
    final finalRows = await app.pain.effective();
    expect(finalRows.where((e) => e.exerciseId == painful || e.derivedFromExerciseId == painful), isEmpty);
    log('S10 POST /pain-exclusions/$painful/reactivation → 200 (candidatoHoy=${reactivation['candidatoHoy']}); sale de /effective con sus derivados');

    // History: the finished session is still there, as it was.
    final done = workoutsOf(await app.plan()).firstWhere((w) => w['plannedWorkoutId'] == sessionWorkoutA);
    final sessionNow = await app.workouts.current();
    expect(sessionNow, isNull);
    expect(const {'COMPLETED', 'PARTIAL'}, contains(workoutStatusOf(done)));
    log('Historial: entrenamiento $sessionWorkoutA sigue ${workoutStatusOf(done)} tras identificar y reactivar; sin sesión abierta');
  }, skip: skip);

  test('S2 S3 · equivalents and precautions: listed, explained, blocked wherever prescribed, not reactivable', () async {
    final found = <PainOrigin>{};
    final keep = <String>[];
    for (var i = 0; i < 10 && found.length < 2; i++) {
      final gym = i.isEven;
      final email = await createAccount('eq$i', gym: gym);
      final app = await App.login(email);
      final plan = await app.plan();
      final skipped = workoutsOf(plan).where(canSkipWorkout).first;
      await app.workouts.skip(skipped['plannedWorkoutId'], 'PAIN_OR_DISCOMFORT');
      final effective = await app.pain.effective();
      final derived = {for (final e in effective.where((e) => e.origin != PainOrigin.direct)) e.exerciseId: e};
      final open = workoutsOf(await app.plan()).where(isOpenWorkout).toList();
      var prescribed = 0;
      for (final e in open.expand(exercisesOf).where((e) => derived.containsKey(idOf(e)))) {
        expect(painBlocked(e), isTrue, reason: 'a derived exclusion blocks its prescription ${e['plannedExerciseId']}');
        prescribed++;
      }
      log('cuenta eq$i (${gym ? 'gimnasio' : 'casa'}): ${derived.length} derivadas; $prescribed en rutinas abiertas (todas bloqueadas)');
      for (final x in derived.values.where((x) => !found.contains(x.origin))) {
        expectPlain(x.explanation);
        expect(x.provisional, isTrue, reason: 'derived from a session not yet identified');
        expect(x.canReactivate, isFalse);
        final refusal = await refused(() => app.pain.reactivate(x.exerciseId));
        expect(refusal, startsWith('404'));
        found.add(x.origin);
        keep.add(email);
        log('${x.origin == PainOrigin.equivalent ? 'S2' : 'S3'} ${x.origin.name.toUpperCase()} ${x.exerciseId} «${x.name}» de '
            '${x.derivedFromExerciseId} «${x.derivedFromExerciseName}» (nivel ${x.equivalenceLevel}): provisional, canReactivate=false; '
            'reactivarlo → $refusal. Flutter: «${x.explanation}»');
      }
    }
    expect(found, {PainOrigin.equivalent, PainOrigin.precaution});
    final file = env['KORA_O20_DERIVED_FILE'];
    if (file != null) File(file).writeAsStringSync(keep.toSet().join('\n'));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 5)));
}
