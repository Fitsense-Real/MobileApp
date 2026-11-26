// O20: saves what a running backend answers, through the app's repositories, so that
// test/screenshots/o20_backend_real_capturas_test.dart draws the real screens with those exact answers.
// Skipped unless KORA_LIVE_API_BASE_URL, KORA_O20_RECORD (output folder) and KORA_O20_MODE are set.
//
//   KORA_O20_MODE=demo       read-only: the Demo Kora account (KORA_LIVE_EMAIL_A / KORA_LIVE_PASSWORD).
//                            Only GET requests: no generation, no close, no record.
//   KORA_O20_MODE=sintetica  a new synthetic participant reports pain and opens a routine with a blocked exercise.
//   KORA_O20_MODE=s9         the S9 account after two weeks with a plan (KORA_O20_STATE from o20_dos_semanas).
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/pain/domain/pain_safety.dart';
import 'package:fitsense_mobile/features/workouts/domain/workout_rules.dart';
import 'o20_validacion_live_test.dart' as live;

final env = Platform.environment;
final out = env['KORA_O20_RECORD'];
final mode = env['KORA_O20_MODE'];

void save(String name, Object? data) {
  File('$out/$mode/$name.json')..createSync(recursive: true)..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
}

Future<void> saveCommon(live.App app) async {
  save('plan_current', await app.plans.current());
  save('pain_exclusions_effective', (await app.dio.get('/users/me/pain-exclusions/effective')).data);
  save('pain_exclusions_confirmation_requests', (await app.dio.get('/users/me/pain-exclusions/confirmation-requests')).data);
  save('pain_exclusions', await app.pain.list());
  save('plan_adaptations', await app.plans.adaptations());
  save('plans', await app.plans.history());
}

void main() {
  final skip = live.base == null || out == null || mode == null ? 'needs KORA_LIVE_API_BASE_URL, KORA_O20_RECORD and KORA_O20_MODE' : false;

  test('record the backend answers: $mode', () async {
    switch (mode) {
      case 'demo':
        final token = (await Dio(BaseOptions(baseUrl: live.base!)).post('/auth/login',
            data: {'email': env['KORA_LIVE_EMAIL_A'], 'password': env['KORA_LIVE_PASSWORD']})).data['token'];
        final app = live.App(Dio(BaseOptions(baseUrl: live.base!, headers: {'Authorization': 'Bearer $token'})));
        app.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
          expect(o.method, 'GET', reason: 'the demo account is only read');
          h.next(o);
        }));
        await saveCommon(app);
        final effective = await app.pain.effective();
        final plan = (await app.plans.current())!;
        final history = await app.plans.history();
        final adaptations = await app.plans.adaptations();
        final blocked = [for (final w in live.workoutsOf(plan)) ...live.exercisesOf(w).where(isUnsafeExercise)];
        live.log('DEMO /effective: ${[for (final e in effective) '${e.origin.name.toUpperCase()} ${e.exerciseId} «${e.name}» confirmado=${e.confirmed} → «${e.explanation}»']}');
        live.log('DEMO plan vigente ${plan['planId']} (${plan['weekStartDate']}, ${plan['status']}): ${live.workoutsOf(plan).length} entrenamientos, '
            '${blocked.length} prescripciones bloqueadas; contiene el 1025: ${live.workoutsOf(plan).expand(live.exercisesOf).any((e) => live.idOf(e) == 1025)}');
        live.log('DEMO /plans: ${[for (final p in history) '${p['planId']} ${p['weekStartDate']} ${p['status']}']}');
        live.log('DEMO /plan/adaptations: ${[for (final a in adaptations) '${a['weekStartDate']} ${a['resultado']}']}');
        live.log('DEMO /confirmation-requests: ${(await app.pain.confirmationRequests()).length} pendientes');
        // Every GET the app's screens make, saved by path for the app replay test (o20_demo_app_test).
        final paths = ['/users/me', '/users/me/profile', '/users/me/plan/current', '/users/me/plans', '/users/me/plan/adaptations',
          '/users/me/plan/limitations', '/users/me/metrics/weekly', '/users/me/interventions', '/users/me/pain-exclusions',
          '/users/me/pain-exclusions/effective', '/users/me/pain-exclusions/confirmation-requests', '/sessions/current',
          '/users/me/notification-preferences', '/users/me/consents', for (final p in history) '/users/me/plan/${p['planId']}'];
        for (final path in paths) {
          final response = await app.dio.get(path, options: Options(validateStatus: (_) => true));
          save('paths/${path.replaceAll('/', '_')}', {'status': response.statusCode, 'data': response.data});
        }
        live.log('DEMO respuestas GET guardadas para la app: ${paths.length}');
        for (final p in history) {
          final full = await app.plans.byId(p['planId']);
          save('plan_${p['planId']}', full);
          final statuses = <String, int>{};
          for (final w in live.workoutsOf(full)) {
            statuses.update(workoutStatusOf(w), (n) => n + 1, ifAbsent: () => 1);
          }
          live.log('DEMO historial plan ${p['planId']}: $statuses');
        }
      case 'sintetica':
        final email = await live.createAccount('capturas', gym: false);
        final app = await live.App.login(email);
        final skipped = live.workoutsOf(await app.plan()).where(canSkipWorkout).first;
        await app.workouts.skip(skipped['plannedWorkoutId'], 'PAIN_OR_DISCOMFORT');
        final plan = await app.plan();
        final open = live.workoutsOf(plan).firstWhere((w) => canStartWorkout(w) && live.exercisesOf(w).any(live.painBlocked));
        final session = await app.workouts.start(open['plannedWorkoutId']);
        final allowed = live.exercisesOf(open).firstWhere((e) => !isUnsafeExercise(e));
        await app.workouts.record(session['sessionId'], allowed['plannedExerciseId'], prescribedResult(allowed));
        await saveCommon(app);
        save('workout', open);
        save('session_current', await app.workouts.current());
        live.log('SINTETICA entrenamiento ${open['plannedWorkoutId']} con ${live.exercisesOf(open).where(live.painBlocked).length} bloqueados; '
            'sesión ${session['sessionId']} con 1 registro');
      case 'nofactible':
        // A synthetic account whose weekly close could not adapt (read only).
        final app = await live.App.login(env['KORA_LIVE_EMAIL_A']!);
        await saveCommon(app);
        final adaptations = await app.plans.adaptations();
        for (final a in adaptations) {
          live.log('S11 GET /plan/adaptations semana ${a['weekStartDate']}: resultado=${a['resultado']} estado=${a['estado']} '
              'motivoTexto=«${a['motivoTexto']}» → Flutter: «${notFeasibleExplanation(a) ?? a['motivoTexto']}»');
        }
        expect(adaptations.any((a) => notFeasibleExplanation(a) != null), isTrue);
        live.log('S11 GET /plan/current → ${await app.plans.current() == null ? '404 (sin plan esta semana)' : 'plan'}');
      case 's9':
        final state = jsonDecode(File(env['KORA_O20_STATE']!).readAsStringSync()) as Map<String, dynamic>;
        final app = await live.App.login(state['s9']);
        await saveCommon(app);
        final requests = await app.pain.confirmationRequests();
        live.log('S9 /confirmation-requests: ${[for (final r in requests) '${r.plannedWorkoutId} ${r.eventDate} confirmationRequired=${r.confirmationRequired}']}');
        expect(requests.any((r) => r.confirmationRequired), isTrue);
        expect((await app.pain.effective()).where((e) => e.confirmationRequired && e.origin == PainOrigin.direct), isNotEmpty);
    }
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
