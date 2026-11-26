// O20 closing checks against a running backend (isolated database, synthetic accounts, AI off). Skipped
// unless KORA_LIVE_API_BASE_URL, KORA_O20_CIERRE (state written by the preparation script) and
// KORA_O20_STAGE are set. Optional KORA_O20_RECORD: folder where the backend's answers are saved for the
// screenshots.
//
//   stage=equivalentes  scenarios 2 and 3 in a session ALREADY OPEN. The plan is the rules engine's; four of
//                       its prescriptions were seeded by SQL (declared in the state file) so that the open
//                       session holds an equivalent variant (13 of 1054) and a precaution by angle (899 of 1138)
//                       of two exercises of another session. The pain report, the derivation, the block and
//                       every answer are the backend's own.
//   stage=rechazo       REACTIVACION_RECHAZADA_POR_SEGURIDAD: a participant who turned 60 (backend clock after
//                       01/12/2026) asks to reactivate a high-impact exercise excluded for pain.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/pain/domain/pain_safety.dart';
import 'package:fitsense_mobile/features/workouts/domain/workout_rules.dart';
import 'o20_validacion_live_test.dart' as live;

final env = Platform.environment;
final stage = env['KORA_O20_STAGE'];
final stateFile = env['KORA_O20_CIERRE'];
final record = env['KORA_O20_RECORD'];

void save(String folder, String name, Object? data) {
  if (record == null) return;
  File('$record/$folder/$name.json')..createSync(recursive: true)..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
}

Future<String> refusedWith(Future<Object?> Function() call) => live.refused(call);

void main() {
  final skip = live.base == null || stateFile == null || stage == null ? 'needs KORA_LIVE_API_BASE_URL, KORA_O20_CIERRE and KORA_O20_STAGE' : false;
  Map<String, dynamic> state() => jsonDecode(File(stateFile!).readAsStringSync()) as Map<String, dynamic>;

  test('scenarios 2 and 3 in an open session: equivalent and precaution blocked by the backend', () async {
    final s = state()['equivalentes'] as Map<String, dynamic>;
    live.log('S2/S3 semilla declarada (base aislada, cuenta sintética): ${(s['semilla'] as List).join(' ')}');
    final app = await live.App.login(s['email']);
    Json w2Of(Json plan) => live.workoutsOf(plan).firstWhere((w) => w['plannedWorkoutId'] == s['w2']);
    Json byExercise(Json w, int id) => live.exercisesOf(w).firstWhere((e) => live.idOf(e) == id);

    // The session of W2 is opened first: the equivalent and the precaution are still allowed.
    final before = w2Of(await app.plan());
    expect(isUnsafeExercise(byExercise(before, 13)), isFalse);
    expect(isUnsafeExercise(byExercise(before, 899)), isFalse);
    final session = await app.workouts.start(s['w2']);
    final allowed = live.exercisesOf(before).firstWhere((e) => ![13, 899].contains(live.idOf(e)));
    await app.workouts.record(session['sessionId'], allowed['plannedExerciseId'], prescribedResult(allowed));
    live.log('S2/S3 sesión ${session['sessionId']} abierta en el entrenamiento ${s['w2']}: 13 «${byExercise(before, 13)['exerciseName']}» y 899 '
        '«${byExercise(before, 899)['exerciseName']}» sin bloqueo; 1 ejercicio permitido ya registrado');

    // Pain in another session (W1, with 1054 and 1138), without saying which exercise.
    await app.workouts.skip(s['w1'], 'PAIN_OR_DISCOMFORT');
    final effective = await app.pain.effective();
    final eq = effective.firstWhere((e) => e.exerciseId == 13);
    final pr = effective.firstWhere((e) => e.exerciseId == 899);
    expect(eq.origin, PainOrigin.equivalent);
    expect(eq.derivedFromExerciseId, 1054);
    expect(pr.origin, PainOrigin.precaution);
    expect(pr.derivedFromExerciseId, 1138);
    live.log('S2/S3 POST /workouts/${s['w1']}/skip (dolor) → /effective: EQUIVALENT 13 de 1054 (${eq.equivalenceLevel}), '
        'PRECAUTION 899 de 1138 (${pr.equivalenceLevel}), ambas provisionales');

    // The app reads the plan again: both prescriptions of the open session are blocked; the rest is not.
    final w2 = w2Of(await app.plan());
    expect(workoutStatusOf(w2), 'IN_PROGRESS');
    expect(w2['safetyBlocked'], isFalse);
    for (final (scenario, id, x) in [('S2', 13, eq), ('S3', 899, pr)]) {
      final e = byExercise(w2, id);
      expect(live.painBlocked(e), isTrue);
      final text = blockExplanation(e, effective: effective)!;
      live.expectPlain(text);
      expect(text, x.explanation);
      final full = await refusedWith(() => app.workouts.record(session['sessionId'], e['plannedExerciseId'], prescribedResult(e)));
      expect(full, startsWith('422 SESION_BLOQUEADA_POR_SEGURIDAD'));
      final partial = await refusedWith(() => app.workouts.record(session['sessionId'], e['plannedExerciseId'],
          {...prescribedResult(e), 'actualSets': 1, 'actualRepsTotal': 4, 'skipReason': 'FATIGUE'}));
      expect(partial, startsWith('422 SESION_BLOQUEADA_POR_SEGURIDAD'));
      await app.workouts.record(session['sessionId'], e['plannedExerciseId'], live.notDone('PAIN_OR_DISCOMFORT'));
      live.log('$scenario prescripción ${e['plannedExerciseId']} (ejercicio $id) en la sesión abierta: safetyBlockReason=${e['safetyBlockReason']}; '
          'completo → $full; parcial → $partial; no realizado → 200. Flutter: «No disponible por ahora. $text»');
    }
    expect(live.exercisesOf(w2).where((e) => !live.painBlocked(e)).every((e) => e['safetyBlockReason'] == null), isTrue);
    save('equivalentes', 'plan_current', await app.plans.current());
    save('equivalentes', 'workout', w2);
    save('equivalentes', 'session_current', await app.workouts.current());
    save('equivalentes', 'pain_exclusions_effective', (await app.dio.get('/users/me/pain-exclusions/effective')).data);
    save('equivalentes', 'pain_exclusions_confirmation_requests', (await app.dio.get('/users/me/pain-exclusions/confirmation-requests')).data);
    save('equivalentes', 'pain_exclusions', await app.pain.list());
    save('equivalentes', 'plan_adaptations', await app.plans.adaptations());

    // Reopening (a new login): still blocked; the open session keeps its records, without duplicates.
    final again = await live.App.login(s['email']);
    final reopened = w2Of(await again.plan());
    expect(live.painBlocked(byExercise(reopened, 13)) && live.painBlocked(byExercise(reopened, 899)), isTrue);
    final open = (await again.workouts.current())!;
    final records = jsonRows(open['exercises']);
    expect(records.map((r) => r['plannedExerciseId']).toSet().length, records.length);
    live.log('S2/S3 nuevo inicio de sesión: 13 y 899 siguen bloqueados; la sesión ${open['sessionId']} sigue abierta con ${records.length} registros, sin duplicados');

    // An answer that does not name them lifts nothing: identify another exercise of W1 as the painful one.
    final request = (await again.pain.confirmationRequests()).firstWhere((r) => r.plannedWorkoutId == s['w1']);
    final other = request.exercises.firstWhere((e) => e.id != 1054 && e.id != 1138).id;
    final answer = await again.pain.identify(other, plannedWorkoutId: request.plannedWorkoutId);
    final after = w2Of(await again.plan());
    expect(live.painBlocked(byExercise(after, 13)) && live.painBlocked(byExercise(after, 899)), isTrue);
    live.log('S2/S3 identificar $other como el que dolió, sin nombrar 1054 ni 1138 → siguen excluidos ${answer.stillExcludedFromSession}; '
        '13 y 899 siguen bloqueados en la sesión abierta');
  }, skip: skip == false && stage != 'equivalentes' ? 'stage $stage' : skip, timeout: const Timeout(Duration(minutes: 2)));

  test('REACTIVACION_RECHAZADA_POR_SEGURIDAD: the exercise stays excluded, by every route', () async {
    final s = state()['rechazo'] as Map<String, dynamic>;
    final target = s['exerciseId'] as int;
    final app = await live.App.login(s['email']);
    final historyBefore = await app.pain.list();
    final plansBefore = [for (final p in await app.plans.history()) '${p['planId']} ${p['status']}'];
    final row = (await app.pain.effective()).firstWhere((e) => e.exerciseId == target);
    expect(row.origin, PainOrigin.direct);
    expect(row.canReactivate, isTrue, reason: 'the app offers «Ya no me duele»: only the backend can refuse it');

    final refusal = await refusedWith(() => app.pain.reactivate(target, comment: 'prueba sintética'));
    expect(refusal, startsWith('422 REACTIVACION_RECHAZADA_POR_SEGURIDAD'));
    save('rechazo', 'reactivation_422', {'status': 422, 'message': refusal.substring(4)});
    final still = await app.pain.effective();
    expect(still.any((e) => e.exerciseId == target), isTrue);
    live.log('REACTIVACIÓN POST /pain-exclusions/$target/reactivation (60 años, alto impacto «${s['exerciseName']}») → $refusal; '
        'sigue en /effective');

    // Another route: declaring it «unrelated» while identifying another exercise of the session.
    final request = (await app.pain.confirmationRequests()).firstWhere((r) => r.plannedWorkoutId == s['workout']);
    final painful = request.exercises.firstWhere((e) => e.id != target).id;
    final answer = await app.pain.identify(painful, plannedWorkoutId: request.plannedWorkoutId, unrelated: {target});
    expect(answer.unrelatedLifted, isNot(contains(target)));
    expect(answer.unrelatedNotLifted.keys, contains(target));
    expect((await app.pain.effective()).any((e) => e.exerciseId == target), isTrue);
    live.log('REACTIVACIÓN por otra vía: identificar $painful y declarar $target «no relacionado» → noRelacionadosNoLevantados '
        '{$target: «${answer.unrelatedNotLifted[target]}»}; sigue en /effective');
    save('rechazo', 'identification', {'noRelacionadosNoLevantados': {'$target': answer.unrelatedNotLifted[target]}});

    // History unchanged: the same rows (now one confirmed) and the same plans.
    final historyAfter = await app.pain.list();
    expect(historyAfter.length, historyBefore.length);
    expect([for (final p in await app.plans.history()) '${p['planId']} ${p['status']}'], plansBefore);
    save('rechazo', 'pain_exclusions_effective', (await app.dio.get('/users/me/pain-exclusions/effective')).data);
    save('rechazo', 'pain_exclusions_confirmation_requests', (await app.dio.get('/users/me/pain-exclusions/confirmation-requests')).data);
    save('rechazo', 'pain_exclusions', historyAfter);
    live.log('REACTIVACIÓN historial: ${historyAfter.length} filas (igual que antes), planes $plansBefore sin cambios');
  }, skip: skip == false && stage != 'rechazo' ? 'stage $stage' : skip, timeout: const Timeout(Duration(minutes: 2)));
}
