// O20, scenario 9 and 11 against a running backend, across two REAL weekly closes. Skipped unless
// KORA_LIVE_API_BASE_URL and KORA_O20_STAGE are set. The weeks pass with the backend's own clock
// (libfaketime on the backend process only); nothing is written to the database by hand:
//
//   stage=prepare  (real date)      two synthetic participants report pain; state saved to KORA_O20_STATE
//   backend restarted at Monday 07/12 07:29 UTC (02:29 in Lima): the overdue task (:30) and the weekly
//   close (03:00 Lima) run as in production
//   stage=check1                    one week with a plan after the pain: still not asked actively
//   backend restarted at Monday 14/12 07:29 UTC
//   stage=check2                    two weeks with a plan: confirmationRequired, nothing lifted
//
// The rules engine generates (AI off): no Replicate, no OpenAI.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/pain/domain/pain_safety.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_safety_notices.dart';
import 'package:fitsense_mobile/features/workouts/domain/workout_rules.dart';
import 'o20_validacion_live_test.dart' as live;

final stage = Platform.environment['KORA_O20_STAGE'];
final stateFile = Platform.environment['KORA_O20_STATE'];

void main() {
  final skip = live.base == null || stage == null || stateFile == null ? 'needs KORA_LIVE_API_BASE_URL, KORA_O20_STAGE and KORA_O20_STATE' : false;

  test('O20 two weeks with a plan: $stage', () async {
    if (stage == 'prepare') {
      // S9: one session with unidentified pain. S11: every workout of a home plan skipped for pain.
      final s9 = await live.createAccount('s9', gym: true);
      final s11 = await live.createAccount('s11', gym: false);
      final a9 = await live.App.login(s9), a11 = await live.App.login(s11);
      final skipped = live.workoutsOf(await a9.plan()).where(canSkipWorkout).first;
      await a9.workouts.skip(skipped['plannedWorkoutId'], 'PAIN_OR_DISCOMFORT');
      for (final w in live.workoutsOf(await a11.plan()).where(canSkipWorkout)) {
        await a11.workouts.skip(w['plannedWorkoutId'], 'PAIN_OR_DISCOMFORT');
      }
      final r9 = (await a9.pain.confirmationRequests()).single;
      live.log('S9 preparar: sesión ${r9.plannedWorkoutId} del ${r9.eventDate} omitida por dolor, ${r9.exercises.length} ejercicios, '
          'confirmationRequired=${r9.confirmationRequired}; /effective ${(await a9.effectiveIds()).length}');
      live.log('S11 preparar: todas las sesiones de la cuenta s11 omitidas por dolor; /effective ${(await a11.effectiveIds()).length}');
      File(stateFile!).writeAsStringSync(jsonEncode({'s9': s9, 's11': s11, 'workout': r9.plannedWorkoutId, 'event': r9.eventDate,
        'excluded': (await a9.effectiveIds()).toList()}));
      return;
    }
    final state = jsonDecode(File(stateFile!).readAsStringSync()) as Map<String, dynamic>;
    final a9 = await live.App.login(state['s9']), a11 = await live.App.login(state['s11']);
    final excluded = {for (final id in state['excluded'] as List) id as int};
    final plan = await a9.plan();
    final history = await a9.plans.history();
    final request = (await a9.pain.confirmationRequests()).where((r) => r.plannedWorkoutId == state['workout']).single;
    final effective = await a9.pain.effective();
    final prescribed = {for (final w in live.workoutsOf(plan)) ...live.exercisesOf(w).map(live.idOf)};
    live.log('$stage: plan vigente ${plan['planId']} semana ${plan['weekStartDate']} (${plan['generationSource']}); '
        '${history.length} planes en /plans');
    expect({for (final e in effective) e.exerciseId}, containsAll(excluded), reason: 'nothing lifted by time');
    expect(prescribed.intersection(excluded), isEmpty, reason: 'the new plan prescribes none of them');
    live.log('$stage: /effective sigue con las ${excluded.length} exclusiones de la sesión del ${state['event']}; '
        'el plan nuevo no prescribe ninguna (${prescribed.length} ejercicios prescritos)');
    if (stage == 'check1') {
      expect(request.confirmationRequired, isFalse);
      live.log('check1: una semana con plan tras el dolor → confirmationRequired=false (Inicio no pregunta todavía)');
    } else {
      expect(request.confirmationRequired, isTrue);
      final direct = effective.where((e) => e.origin == PainOrigin.direct && excluded.contains(e.exerciseId));
      expect(direct.every((e) => e.confirmationRequired && !e.confirmed && e.canIdentify), isTrue);
      final asked = [request].where((r) => r.confirmationRequired);
      live.log('S9 check2: dos semanas con plan → GET /confirmation-requests confirmationRequired=true; /effective: '
          '${direct.length} DIRECT con confirmationRequired=true, siguen excluidas; Inicio muestra «¿Recuerdas qué ejercicio te dolió el …?» '
          '(${asked.length} aviso)');
    }
    // S11: what the weekly close did with each account.
    for (final (name, app) in [('s9', a9), ('s11', a11)]) {
      final adaptations = await app.plans.adaptations();
      for (final a in adaptations) {
        live.log('$stage adaptación $name semana ${a['weekStartDate']}: resultado=${a['resultado']} '
            '«${a['motivoTexto'] ?? ''}»${notFeasibleExplanation(a) == null ? '' : ' → Flutter: «${notFeasibleExplanation(a)}»'}');
      }
      final current = await app.plans.current();
      live.log('$stage $name: plan vigente ${current?['planId'] ?? 'ninguno'} ${current?['weekStartDate'] ?? ''}');
      final notice = recentNotFeasibleAdaptation(adaptations, now: DateTime.parse(current?['weekStartDate'] ?? '${plan['weekStartDate']}'));
      if (notice != null) live.log('S11 $name: Inicio muestra el aviso NO_FACTIBLE de la semana ${notice['weekStartDate']}');
    }
  }, skip: skip, timeout: const Timeout(Duration(minutes: 3)));
}
