// O20, live: the app's pain code against a running backend (Fitsense-Real/Backend
// generation with PR #84). Skipped unless KORA_LIVE_API_BASE_URL is set; one
// synthetic account with a profile and a plan (rules engine, no AI).
//
//   KORA_LIVE_API_BASE_URL=http://localhost:8080/api/v1 KORA_LIVE_EMAIL_A=... KORA_LIVE_PASSWORD=... \
//   flutter test test/live/pain_o20_live_test.dart
//
// Uses the app's real PainExclusionRepository, PlanRepository and WorkoutRepository,
// the app's blockExplanation and identificationProblem. Prints what the backend answered.
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

// ignore: avoid_print
void log(String line) => print('O20 $line');

void main() {
  test('pain skip → /effective, blocked prescriptions, 422, identification with unrelated, reactivation', () async {
    final login = await Dio(BaseOptions(baseUrl: base!)).post('/auth/login', data: {'email': env['KORA_LIVE_EMAIL_A'], 'password': env['KORA_LIVE_PASSWORD']});
    final dio = Dio(BaseOptions(baseUrl: base!, contentType: Headers.jsonContentType, headers: {'Authorization': 'Bearer ${login.data['token']}'}));
    final pain = PainExclusionRepository(dio), plans = PlanRepository(dio), workouts = WorkoutRepository(dio);
    List<Json> rows(Json? plan) => jsonRows(plan?['workouts'] ?? []);
    List<Json> exercises(Json w) => jsonRows(w['exercises']);

    // 1. Skip an open workout for pain, without saying which exercise.
    final before = (await plans.current())!;
    final open = rows(before).where(canSkipWorkout).toList();
    final skipped = open.first;
    final skippedIds = {for (final e in exercises(skipped)) (e['exerciseId'] as num).toInt()};
    await workouts.skip(skipped['plannedWorkoutId'], 'PAIN_OR_DISCOMFORT');
    log('omisión por dolor: entrenamiento ${skipped['plannedWorkoutId']} con ejercicios ${skippedIds.toList()..sort()}');

    // 2. /effective: every exercise of the session, DIRECT and not confirmed; plus equivalents/precautions.
    final effective = await pain.effective();
    final direct = effective.where((e) => e.origin == PainOrigin.direct).toList();
    expect({for (final e in direct) e.exerciseId}, containsAll(skippedIds));
    expect(direct.every((e) => !e.confirmed && e.canIdentify && e.canReactivate), isTrue);
    final derived = effective.where((e) => e.origin != PainOrigin.direct).toList();
    expect(derived.every((e) => e.provisional && !e.canReactivate && e.derivedFromExerciseId != null), isTrue);
    log('/effective: ${direct.length} DIRECT sin confirmar, ${derived.where((e) => e.origin == PainOrigin.equivalent).length} EQUIVALENT y '
        '${derived.where((e) => e.origin == PainOrigin.precaution).length} PRECAUTION provisionales');
    for (final e in derived.take(3)) {
      log('  ${e.origin.name} ${e.exerciseId} «${e.name}»: ${e.explanation}');
    }

    // 3. /confirmation-requests lists the session (confirmationRequired false right after the skip).
    final requests = await pain.confirmationRequests();
    final request = requests.firstWhere((r) => r.plannedWorkoutId == skipped['plannedWorkoutId']);
    expect(request.confirmationRequired, isFalse);
    expect({for (final e in request.exercises) e.id}, skippedIds);
    log('/confirmation-requests: sesión ${request.plannedWorkoutId} ${request.eventDate}, confirmationRequired=${request.confirmationRequired}, ${request.exercises.length} ejercicios');

    // 4. Plan re-read: exactly the prescriptions of open workouts whose exercise is in /effective carry dolor_registrado.
    final after = (await plans.current())!;
    final excludedIds = {for (final e in effective) e.exerciseId};
    final openAfter = rows(after).where(isOpenWorkout).toList();
    var blockedCount = 0;
    Json? blockedWorkout, blockedExercise;
    for (final w in openAfter) {
      for (final e in exercises(w)) {
        final painBlocked = '${e['safetyBlockReason']}'.contains(painBlockCode);
        expect(painBlocked, excludedIds.contains((e['exerciseId'] as num).toInt()), reason: 'prescription ${e['plannedExerciseId']}');
        if (painBlocked) {
          blockedCount++;
          if (canStartWorkout(w) && blockedWorkout == null) { blockedWorkout = w; blockedExercise = e; }
        }
      }
      expect(w['safetyBlocked'], isFalse, reason: 'one painful exercise does not block the whole session');
    }
    log('plan releído (${after['planId']} v${after['planVersion']}): ${openAfter.length} entrenamientos abiertos, $blockedCount prescripciones con dolor_registrado = exactamente las de /effective');

    // 5. An open session with a blocked exercise: work → 422; as not done → 200; the rest normally.
    if (blockedWorkout != null) {
      final session = await workouts.start(blockedWorkout['plannedWorkoutId']);
      log('explicación en la app: «${blockExplanation(blockedExercise!, effective: effective)}»');
      try {
        await workouts.record(session['sessionId'], blockedExercise['plannedExerciseId'], prescribedResult(blockedExercise));
        fail('work on a blocked exercise was accepted');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 422);
        expect('${e.response?.data}', contains('SESION_BLOQUEADA_POR_SEGURIDAD'));
        log('trabajo en ejercicio bloqueado ${blockedExercise['plannedExerciseId']} → 422 SESION_BLOQUEADA_POR_SEGURIDAD');
      }
      final skippedOne = await workouts.record(session['sessionId'], blockedExercise['plannedExerciseId'],
          {'actualSets': 0, 'actualRepsTotal': 0, 'actualDurationSeconds': 0, 'actualLoadKg': 0, 'skipReason': 'PAIN_OR_DISCOMFORT'});
      final allowed = exercises(blockedWorkout).where((e) => !isUnsafeExercise(e)).firstOrNull;
      if (allowed != null) await workouts.record(session['sessionId'], allowed['plannedExerciseId'], prescribedResult(allowed));
      log('como no realizado → 200 (${jsonRows(skippedOne['exercises']).length} registro); permitido ${allowed?['plannedExerciseId']} → 200');
      await workouts.abandon(session['sessionId']);
    } else {
      log('ningún entrenamiento abierto que se pueda empezar repite los ejercicios excluidos (paso 5 sin caso)');
    }

    // 6. Identification: 422 when the identified one is also «unrelated»; 200 with real unrelated ones.
    final ids = request.exercises.map((e) => e.id).toList();
    final painful = ids.first;
    final unrelated = ids.length > 1 ? {ids[1]} : <int>{};
    expect(identificationProblem(request, painful, {painful}), isNotNull, reason: 'the app refuses it before sending');
    try {
      await pain.identify(painful, plannedWorkoutId: request.plannedWorkoutId, unrelated: {painful});
      fail('the backend accepted the identified exercise as unrelated');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 422);
      log('identificado también como no relacionado → 422 «${e.response?.data is Map ? (e.response!.data as Map)['message'] : e.response?.data}»');
    }
    final answer = await pain.identify(painful, plannedWorkoutId: request.plannedWorkoutId, unrelated: unrelated);
    log('identificación ($painful, no relacionados $unrelated) → 200: levantados ${answer.unrelatedLifted}, no levantados ${answer.unrelatedNotLifted}, '
        'siguen excluidos ${answer.stillExcludedFromSession}, equivalentes ${answer.equivalentsExcluded.length}');
    final identified = await pain.effective();
    final row = identified.firstWhere((e) => e.exerciseId == painful);
    expect(row.confirmed, isTrue);
    expect(row.canIdentify, isFalse);
    for (final id in answer.unrelatedLifted) {
      expect(identified.where((e) => e.exerciseId == id && e.origin == PainOrigin.direct), isEmpty, reason: 'lifted: $id');
    }
    for (final id in answer.stillExcludedFromSession) {
      expect(identified.any((e) => e.exerciseId == id), isTrue, reason: 'still excluded: $id');
    }
    expect((await pain.confirmationRequests()).where((r) => r.plannedWorkoutId == skipped['plannedWorkoutId'] && r.exercises.any((e) => e.id == painful)), isEmpty);
    try {
      await pain.identify(painful, plannedWorkoutId: request.plannedWorkoutId);
      fail('identified twice');
    } on DioException catch (e) {
      expect(e.response?.statusCode, 404);
      log('identificar dos veces → 404');
    }

    // 7. Reactivation of the identified one: it and its derived entries leave /effective.
    final derivedFromPainful = identified.where((e) => e.derivedFromExerciseId == painful).map((e) => e.exerciseId).toSet();
    final reactivation = await pain.reactivate(painful, comment: 'prueba sintética');
    final finalRows = await pain.effective();
    expect(finalRows.where((e) => e.exerciseId == painful && e.origin == PainOrigin.direct), isEmpty);
    expect(finalRows.where((e) => e.derivedFromExerciseId == painful), isEmpty);
    log('reactivación de $painful → 200 (candidatoHoy=${reactivation['candidatoHoy']}); salen también sus ${derivedFromPainful.length} derivados; '
        'quedan ${finalRows.length} exclusiones efectivas');
  }, skip: base == null ? 'KORA_LIVE_API_BASE_URL not set (needs a running backend)' : false);
}
