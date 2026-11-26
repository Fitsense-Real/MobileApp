import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../../core/api/json.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../pain/data/pain_exclusion_repository.dart';
import '../../pain/domain/pain_safety.dart';
import '../../pain/presentation/pain_confirmation_sheet.dart';
import '../../plans/data/plan_repository.dart';
import 'package:dio/dio.dart';
import '../domain/workout_rules.dart';
import '../data/workout_repository.dart';

import 'exercise_media.dart';
import 'exercise_result_dialog.dart';
import 'session_timer.dart';

class PlannedWorkoutPage extends ConsumerStatefulWidget {
  const PlannedWorkoutPage({super.key, required this.workout});
  final Json workout;
  @override
  ConsumerState<PlannedWorkoutPage> createState() => _PlannedWorkoutPageState();
}
/// Result of confirming the routine with the backend before sending results.
enum RoutineCheck { confirmed, unreachable, outdated }

class _PlannedWorkoutPageState extends ConsumerState<PlannedWorkoutPage> {
  Json? session;
  /// The routine as the backend sees it now. Starts with what the plan list
  /// had and is re-read on open, after a skip for pain and after a 422: the
  /// backend marks the exercises that can no longer be done
  /// (`safetyBlockReason`), the app never decides it.
  late Json workout = widget.workout;
  /// The routine is no longer in the active plan (replaced by a new version).
  bool outdated = false;
  bool busy = true, closed = false, reporting = false;
  final drafts = <Object, Json>{};
  String? error;
  WorkoutRepository get repository => ref.read(workoutRepositoryProvider);
  bool get ownSession => session?['plannedWorkoutId'] == workout['plannedWorkoutId'];
  @override
  void initState() {
    super.initState();
    Future.microtask(() => act(() async { session = await repository.current(); }));
    // In the background: the screen is usable at once and updates when the
    // backend answers (a slow network never blocks registering).
    Future.microtask(refreshWorkout);
    // Back from the background: the routine may have changed meanwhile.
    lifecycle = AppLifecycleListener(onResume: refreshWorkout);
  }

  AppLifecycleListener? lifecycle;

  @override
  void dispose() {
    lifecycle?.dispose();
    super.dispose();
  }

  /// Results entered while the routine could not be confirmed with the
  /// backend: kept on this device and never sent until it is confirmed.
  final pending = <Object, Json>{};

  /// Exercises whose result is being confirmed or sent: a second action on
  /// the same exercise waits instead of sending twice.
  final sending = <Object>{};

  /// How long the app waits for the plan before giving up (and not sending).
  static const confirmLimit = Duration(seconds: 8);

  /// Re-reads the routine from the current plan (`GET /users/me/plan/current`).
  /// The open session and its records come from the backend too, so a
  /// refresh never duplicates executions.
  ///
  /// [RoutineCheck.unreachable]: no answer (no network, more than [limit],
  /// 401, 422, 5xx...). Nothing on screen changes and nothing may be sent on
  /// its basis: no answer never means «allowed».
  /// [RoutineCheck.outdated]: the routine is no longer in the active plan.
  Future<RoutineCheck> checkRoutine({Duration? limit}) async {
    final Json? plan;
    try {
      final read = ref.read(planRepositoryProvider).current();
      plan = await (limit == null ? read : read.timeout(limit));
    } catch (_) {
      return RoutineCheck.unreachable;
    }
    if (!mounted) return RoutineCheck.unreachable;
    final fresh = jsonRows(plan?['workouts'] ?? []).where((w) => w['plannedWorkoutId'] == workout['plannedWorkoutId']).firstOrNull;
    if (fresh == null) {
      // A new plan version replaced it, or there is no plan this week. A
      // closed routine keeps its history as it was; an open one can no
      // longer be recorded.
      outdated = isOpenWorkout(workout);
      return RoutineCheck.outdated;
    }
    workout = fresh;
    outdated = false;
    return RoutineCheck.confirmed;
  }

  /// [checkRoutine] in the background (on open, back from the background,
  /// after a 422): the screen shows the backend's routine as soon as it answers.
  Future<void> refreshWorkout() async {
    await checkRoutine();
    if (mounted) setState(() {});
  }

  /// The exercise as the backend has it now in this routine, or null.
  Json? freshExercise(Object plannedExerciseId) =>
      jsonRows(workout['exercises'] ?? []).where((e) => e['plannedExerciseId'] == plannedExerciseId).firstOrNull;

  static bool hasWork(Json body) => ['actualSets', 'actualRepsTotal', 'actualDurationSeconds'].any((k) => (body[k] as num? ?? 0) > 0);

  /// Why a result cannot be sent with the routine just confirmed, or null.
  String? refusal(Object plannedExerciseId, Json body) {
    final exercise = freshExercise(plannedExerciseId);
    if (exercise == null) return 'Este ejercicio ya no forma parte de tu rutina actualizada. No se envió el resultado.';
    if (isUnsafeExercise(exercise) && hasWork(body)) {
      return 'Este ejercicio tiene ahora una restricción por seguridad: solo puede registrarse como no realizado. No se envió el resultado con trabajo realizado.';
    }
    return null;
  }

  static const unreachableMessage = 'No pudimos confirmar con el servidor que tu rutina sigue vigente. '
      'Tu resultado se guardó en este teléfono y no se ha enviado. Revisa tu conexión y vuelve a intentarlo.';

  Future<void> act(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() { busy = true; error = null; });
    try { await action(); }
    catch (e) {
      if (!mounted) return;
      if (e is DioException && e.response?.statusCode == 422) {
        await onRefused(e);
      } else {
        error = apiError(e);
      }
    }
    finally { if (mounted) setState(() => busy = false); }
  }

  /// The backend refused it (e.g. SESION_BLOQUEADA_POR_SEGURIDAD: an exercise
  /// is no longer safe). Show why and read its current state again.
  Future<void> onRefused(DioException e) async {
    final blocked = apiError(e).contains('SESION_BLOQUEADA_POR_SEGURIDAD');
    error = blocked
        ? 'Este ejercicio ya no puede registrarse con trabajo realizado: tiene una restricción por seguridad. Puedes registrarlo como no realizado y seguir con el resto.'
        : apiError(e);
    refreshPainSafety(ref);
    try { session = await repository.current(); } catch (_) {}
    await checkRoutine();
  }

  Future<void> record(Json exercise) async {
    final id = exercise['plannedExerciseId'] as Object;
    if (sending.contains(id)) return;
    // Show the dialog with the routine as the backend has it now, when it answers.
    setState(() { sending.add(id); busy = true; });
    final RoutineCheck check;
    try {
      check = await checkRoutine(limit: confirmLimit);
    } finally {
      if (mounted) setState(() { sending.remove(id); busy = false; });
    }
    if (!mounted || outdated) return;
    if (check == RoutineCheck.confirmed) exercise = freshExercise(id) ?? exercise;
    final records = reporting ? drafts.values.toList() : jsonRows(session?['exercises'] ?? []);
    final existing = pending[id] ?? records.where((e) => e['plannedExerciseId'] == id).firstOrNull;
    final body = await showDialog<Json>(context: context, builder: (_) => ExerciseResultDialog(exercise: exercise, existing: existing, draft: reporting, blockReason: blockExplanation(exercise, effective: ref.read(effectivePainExclusionsProvider).asData?.value ?? const [])));
    if (body == null || !mounted) return;
    if (reporting) { setState(() => drafts[id] = {...body, 'plannedExerciseId': id}); return; }
    await send(id, body);
  }

  /// Sends one live result only after the backend confirms, just before, that
  /// the routine is current and the exercise allows it. Otherwise it is kept
  /// in [pending] (no answer) or refused (blocked, removed), never sent.
  Future<void> send(Object id, Json body) async {
    if (sending.contains(id)) return;
    setState(() { sending.add(id); busy = true; error = null; });
    try {
      final check = await checkRoutine(limit: confirmLimit);
      if (!mounted) return;
      if (check == RoutineCheck.unreachable) {
        pending[id] = body;
        error = unreachableMessage;
        return;
      }
      if (check == RoutineCheck.outdated) {
        pending.remove(id);
        error = 'Tu plan se actualizó y esta rutina ya no forma parte de él. No se envió el resultado.';
        return;
      }
      final refused = refusal(id, body);
      if (refused != null) {
        pending.remove(id);
        error = refused;
        return;
      }
      try {
        session = await repository.record(session!['sessionId'], id, body);
        pending.remove(id);
      } on DioException catch (e) {
        if (!mounted) return;
        if (e.response?.statusCode == 422) {
          pending.remove(id);
          await onRefused(e);
        } else if (e.response == null) {
          // The connection dropped while sending: kept to try again (a PUT
          // replaces the result, so repeating it never duplicates).
          pending[id] = body;
          error = 'Se perdió la conexión al enviar el resultado. Se guardó en este teléfono y no se ha enviado; vuelve a intentarlo.';
        } else {
          pending[id] = body;
          error = '${apiError(e)} Tu resultado se guardó en este teléfono y no se ha enviado.';
        }
      }
    } finally {
      if (mounted) setState(() { sending.remove(id); busy = false; });
    }
  }

  /// Tries again every result kept while the routine could not be confirmed.
  Future<void> retryPending() async {
    for (final entry in [...pending.entries]) {
      if (!mounted) return;
      await send(entry.key, entry.value);
      if (pending.containsKey(entry.key)) return; // still no answer: stop here
    }
  }
  Future<void> prepareRecord(Json exercise) async {
    if (!ownSession && !reporting) {
      final mode = await showDialog<String>(context: context, builder: (context) => SimpleDialog(title: const Text('Registrar ejercicio'), children: [
        if (canStartWorkout(workout)) SimpleDialogOption(onPressed: () => Navigator.pop(context, 'start'), child: const Text('Comenzar sesión y registrar')),
        if (canReportWorkout(workout)) SimpleDialogOption(onPressed: () => Navigator.pop(context, 'report'), child: const Text('Ya hice este entrenamiento')),
      ]));
      if (mode == null || !mounted) return;
      if (mode == 'report') { setState(() => reporting = true); }
      else {
        await act(() async { session = await repository.current(); session ??= await repository.start(workout['plannedWorkoutId']); });
        if (!mounted || !ownSession || error != null) return;
      }
    }
    if (mounted) await record(exercise);
  }
  Future<void> report() async {
    if (jsonRows(workout['exercises'] ?? []).isEmpty || jsonRows(workout['exercises'] ?? []).any((e) => !drafts.containsKey(e['plannedExerciseId']))) {
      setState(() => error = 'Indica el resultado de cada ejercicio antes de guardar.'); return;
    }
    // The routine on screen may be older than a pain report: confirm it with
    // the backend before sending. Without an answer nothing is sent and the
    // drafts stay on this device.
    setState(() { busy = true; error = null; });
    final check = await checkRoutine(limit: confirmLimit);
    if (!mounted) return;
    setState(() => busy = false);
    if (check == RoutineCheck.unreachable) {
      setState(() => error = 'No pudimos confirmar con el servidor que tu rutina sigue vigente. Tus resultados siguen guardados en este teléfono y no se han enviado. Revisa tu conexión y vuelve a pulsar «Guardar entrenamiento».');
      return;
    }
    if (check == RoutineCheck.outdated) {
      setState(() => error = 'Tu plan se actualizó y esta rutina ya no forma parte de él. No se enviaron los resultados.');
      return;
    }
    // Only the drafts that cannot be valid any more are discarded: work on an
    // exercise blocked since, or on one no longer in the routine.
    final invalid = [for (final entry in drafts.entries) if (refusal(entry.key, entry.value) != null) entry.key];
    if (invalid.isNotEmpty) {
      setState(() {
        for (final id in invalid) { drafts.remove(id); }
        error = 'Un ejercicio de esta rutina tiene ahora una restricción por seguridad. Regístralo como no realizado antes de guardar. Los demás resultados se conservan.';
      });
      return;
    }
    final exercises = jsonRows(workout['exercises'] ?? []);
    if (exercises.any((e) => !drafts.containsKey(e['plannedExerciseId']))) {
      setState(() => error = 'Indica el resultado de cada ejercicio antes de guardar.'); return;
    }
    final body = await showDialog<Json>(context: context, builder: (_) => const FinishDialog(reporting: true));
    if (body == null || !mounted) return;
    await act(() async {
      session = await repository.report(workout['plannedWorkoutId'], {...body, 'exercises': exercises.map((e) => drafts[e['plannedExerciseId']]).toList()});
      closed = true; reporting = false;
    });
  }
  Future<void> finish() async {
    final records = jsonRows(session?['exercises'] ?? []);
    if (jsonRows(workout['exercises'] ?? []).any((e) => resultLabel(records.where((r) => r['plannedExerciseId'] == e['plannedExerciseId']).firstOrNull) == 'Sin registrar')) {
      setState(() => error = 'Indica si realizaste o no cada ejercicio antes de finalizar.'); return;
    }
    final clock = sessionClock;
    final body = await showDialog<Json>(context: context, builder: (_) => FinishDialog(suggestedMinutes: clock?.suggestedActiveMinutes(DateTime.now())));
    if (body == null || !mounted) return;
    final sessionId = session!['sessionId'];
    await act(() async { session = await repository.finish(sessionId, body); closed = true; });
    if (closed) SessionClocks.clear(sessionId);
  }
  Future<void> skip() async {
    final reason = await showDialog<String>(context: context, builder: (context) => SimpleDialog(title: const Text('¿Por qué omites este entrenamiento?'), children: [
      for (final entry in skipReasons.entries) SimpleDialogOption(onPressed: () => Navigator.pop(context, entry.key), child: Text(entry.value)),
    ]));
    if (reason == null || !mounted) return;
    Json? context_;
    if (reason == 'LACK_OF_TIME') {
      // generation: optional context so the plan reacts to the real cause.
      context_ = await showDialog<Json>(context: context, builder: (_) => const LackOfTimeDialog());
      if (!mounted) return;
    }
    await act(() async { await repository.skip(workout['plannedWorkoutId'], reason, lackOfTimeContext: context_?['lackOfTimeContext'] as String?, availableMinutes: context_?['availableMinutes'] as int?); closed = true; });
    if (reason == 'PAIN_OR_DISCOMFORT' && closed && mounted) await afterPainSkip();
  }

  /// The skip excluded every exercise of the session (the backend does not
  /// know which one hurt). Re-read everything and offer, without insisting,
  /// to say which one it was.
  Future<void> afterPainSkip() async {
    refreshPainSafety(ref);
    List<PainConfirmationRequest> requests = const [];
    try { requests = await ref.read(painExclusionRepositoryProvider).confirmationRequests(); } catch (_) {}
    final request = requests.where((r) => r.plannedWorkoutId == workout['plannedWorkoutId']).firstOrNull;
    if (request == null || !mounted) return;
    final answer = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Gracias por avisar'),
      content: const Text('Kora no volverá a proponerte los ejercicios de esta sesión mientras no sepamos cuál te dolió. '
          '¿Recuerdas cuál fue? Puedes responder ahora o más tarde desde Perfil.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Más tarde')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Indicar ahora')),
      ],
    ));
    if (answer == true && mounted) await showPainConfirmation(context, request);
  }
  Future<void> abandon() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Abandonar sesión'), content: const Text('La sesión no contará como intento y el entrenamiento seguirá pendiente.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar entrenando')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonar'))]));
    if (confirmed != true || !mounted) return;
    final sessionId = session!['sessionId'];
    await act(() async { await repository.abandon(sessionId); session = null; });
    if (session == null) SessionClocks.clear(sessionId);
  }
  /// Clock of the live session, from the backend's `startedAt`.
  SessionClock? get sessionClock {
    final started = DateTime.tryParse('${session?['startedAt']}');
    return ownSession && !closed && started != null ? SessionClocks.of(session!['sessionId'], started) : null;
  }

  /// What `/effective` says about pain today, to explain each block.
  List<EffectiveExclusion> get effective => ref.watch(effectivePainExclusionsProvider).asData?.value ?? const [];

  Json? resultFor(Json exercise) => (reporting ? drafts.values : jsonRows(session?['exercises'] ?? []))
      .where((e) => e['plannedExerciseId'] == exercise['plannedExerciseId']).firstOrNull;

  Future<void> showInstructions(Json exercise) => showModalBottomSheet<void>(
    context: context, showDragHandle: true, isScrollControlled: true,
    builder: (_) => ExerciseInstructions(exerciseId: (exercise['exerciseId'] as num).toInt(), fallbackName: '${exercise['exerciseName'] ?? 'Ejercicio'}'),
  );

  @override
  Widget build(BuildContext context) {
    final effective = this.effective;
    final exercises = jsonRows(workout['exercises'] ?? [])..sort((a,b) => ((a['exerciseOrder'] as num?) ?? 0).compareTo((b['exerciseOrder'] as num?) ?? 0));
    final canStart = canStartWorkout(workout);
    final canReport = canReportWorkout(workout);
    final editable = !closed && !outdated && (ownSession || reporting || (session == null && (canStart || canReport)));
    final status = workoutStatusOf(workout);
    return PopScope(canPop: !busy, child: KoraPage(child: ListView(padding: const EdgeInsets.all(24), children: [
      Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.arrow_back), tooltip: 'Volver')),
      KoraHeading('${workout['workoutName'] ?? 'Mi entrenamiento'}', subtitle: [
        if (workout['scheduledDate'] != null) displayDay(workout['scheduledDate']),
        '${workout['expectedDurationMinutes'] ?? '—'} min',
        if (workoutFocusLabels[workout['focusCode']] != null) workoutFocusLabels[workout['focusCode']]!,
        workoutStatusLabel(status),
      ].join(' · ')), const SizedBox(height: 20),
      if (busy) const LinearProgressIndicator(),
      if (error != null) KoraCard(child: Column(children: [Text(error!), TextButton(onPressed: busy ? null : () => act(() async { session = await repository.current(); }), child: const Text('Consultar estado de sesión'))])),
      if (pending.isNotEmpty && !closed) KoraCard(key: const Key('pending-results'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(pending.length == 1
            ? '1 resultado guardado en este teléfono, sin enviar: falta confirmar tu rutina con el servidor.'
            : '${pending.length} resultados guardados en este teléfono, sin enviar: falta confirmar tu rutina con el servidor.'),
        TextButton(onPressed: busy ? null : retryPending, child: const Text('Reintentar envío')),
      ])),
      if (session != null && !ownSession) const KoraCard(child: Text('Tienes otra sesión en curso. Regresa a esa rutina para terminarla o abandonarla.')),
      if (sessionClock case final clock?) SessionTimerBar(clock: clock),
      if (outdated) const KoraCard(child: Text('Tu plan se actualizó y esta rutina ya no forma parte de él. Vuelve al inicio para ver la versión actual.')),
      if (isSafetyBlocked(workout)) KoraCard(child: Text('${workout['safetyBlockMessage'] ?? 'Este entrenamiento contiene ejercicios que ya no son seguros para ti y espera una versión corregida del plan.'}')),
      if (!closed && status == 'REPLACED') const KoraCard(child: Text('Este entrenamiento pertenece a una versión anterior del plan y fue reemplazado.')),
      if (!closed && (status == 'COMPLETED' || status == 'PARTIAL')) KoraCard(child: Text('Este entrenamiento ya está registrado como ${workoutStatusLabel(status).toLowerCase()}.')),
      if (!closed && !reporting && session == null && isOpenWorkout(workout) && isExpiredWorkout(workout)) const KoraCard(child: Text('El plazo para hacerlo en vivo venció. Si lo realizaste, puedes registrarlo.')),
      if (!closed && status == 'SKIPPED' && workout['skipReason'] != null) KoraCard(child: Text('Omitido: ${skipReasons[workout['skipReason']] ?? workout['skipReason']}. Si lo realizaste, puedes registrarlo.')),
      if (reporting) const KoraCard(child: Text('Registro de un entrenamiento ya realizado. Los resultados están pendientes de envío hasta pulsar Guardar entrenamiento.')),
      if (closed) KoraCard(child: Text(session?['completionPercentage'] == null ? 'Entrenamiento omitido.' : 'Sesión guardada · ${session!['completionPercentage']}% completado')),
      for (final exercise in exercises) Padding(padding: const EdgeInsets.only(top: 16), child: KoraCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExerciseMedia(gifPath: exercise['gifPath'], attribution: exercise['mediaAttribution'] as String?),
        const SizedBox(height: 12),
        Text('${exercise['exerciseName'] ?? 'Ejercicio'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 8),
        Text(exercisePrescription(exercise)),
        if (exercise['restSeconds'] != null) Text('Descanso: ${exercise['restSeconds']} s'),
        if (exercise['notes'] != null) Text('${exercise['notes']}'),
        if (isUnsafeExercise(exercise)) Container(
          key: Key('blocked-${exercise['plannedExerciseId']}'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFBECEA), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('No disponible por ahora', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('${blockExplanation(exercise, effective: effective)} Solo puede registrarse como no realizado; puedes seguir con el resto de la rutina.'),
          ]),
        ),
        if (sessionClock != null && !isUnsafeExercise(exercise)) Wrap(spacing: 8, children: [
          if (isDurationBased(exercise) && (exercise['plannedDurationSeconds'] as num? ?? 0) > 0)
            OutlinedButton.icon(
              onPressed: () => showCountdown(context, seconds: (exercise['plannedDurationSeconds'] as num).toInt(), title: '${exercise['exerciseName'] ?? 'Ejercicio'}', subtitle: 'Serie por tiempo'),
              icon: const Icon(Icons.timer_outlined, size: 18),
              label: Text('Serie de ${exercise['plannedDurationSeconds']} s'),
            ),
          if ((exercise['restSeconds'] as num? ?? 0) > 0)
            OutlinedButton.icon(
              onPressed: () => showCountdown(context, seconds: (exercise['restSeconds'] as num).toInt(), title: 'Descanso', subtitle: '${exercise['exerciseName'] ?? 'Ejercicio'}'),
              icon: const Icon(Icons.hourglass_bottom, size: 18),
              label: Text('Descanso ${exercise['restSeconds']} s'),
            ),
        ]),
        if (exercise['exerciseId'] is num) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => showInstructions(exercise), icon: const Icon(Icons.menu_book_outlined, size: 18), label: const Text('Ver instrucciones'))),
        Text(pending.containsKey(exercise['plannedExerciseId']) ? 'Pendiente de enviar' : resultLabel(resultFor(exercise)), style: const TextStyle(fontWeight: FontWeight.w700)),
        if (resultFor(exercise) case final result?) Text('Guardado: ${result['actualSets'] ?? '—'} series · ${result['actualRepsTotal'] ?? '—'} reps · ${result['actualDurationSeconds'] ?? '—'} s', style: const TextStyle(color: Kora.muted)),
        if (editable) Padding(padding: const EdgeInsets.only(top: 14), child: KoraButton(label: 'Registrar ejercicio', busy: busy, onPressed: session != null && !ownSession ? null : () => prepareRecord(exercise))),
      ]))),
      if (exercises.isEmpty) const Text('El servidor no incluyó ejercicios para esta rutina.'),
      const SizedBox(height: 24),
      if (reporting && !closed) KoraButton(label: 'Guardar entrenamiento', busy: busy, onPressed: report),
      if (!reporting && !closed && session == null && canReport) TextButton(onPressed: busy ? null : () => setState(() => reporting = true), child: const Text('Ya lo hice · registrar entrenamiento')),
      if (!reporting && !closed) ...[
        if (session == null && canStart) KoraButton(label: 'Comenzar entrenamiento', busy: busy, onPressed: () => act(() async {
          // Reconcile after a lost response before attempting another start.
          session = await repository.current();
          session ??= await repository.start(workout['plannedWorkoutId']);
        })),
        if (ownSession) ...[
          KoraButton(label: 'Finalizar sesión', busy: busy, onPressed: finish),
          TextButton(onPressed: busy ? null : abandon, child: const Text('Abandonar sesión')),
        ],
        if (session == null && canSkipWorkout(workout)) TextButton(onPressed: busy ? null : skip, child: const Text('Omitir entrenamiento')),
      ],
    ])));
  }
}

/// Optional context of a LACK_OF_TIME skip (`ContextoFaltaDeTiempo`).
/// Returns null when the user prefers not to answer, which the backend
/// treats as "not informed" and keeps the session.
class LackOfTimeDialog extends StatefulWidget {
  const LackOfTimeDialog({super.key});
  @override
  State<LackOfTimeDialog> createState() => _LackOfTimeDialogState();
}

class _LackOfTimeDialogState extends State<LackOfTimeDialog> {
  static const options = {
    'IMPREVISTO': 'Fue algo puntual',
    'SIN_TIEMPO_ESE_DIA': 'Ese día no tuve ningún minuto',
    'MENOS_TIEMPO_HABITUAL': 'Suelo tener menos tiempo para este entrenamiento',
  };
  String? choice;
  final minutes = TextEditingController();
  String? error;
  @override
  void dispose() { minutes.dispose(); super.dispose(); }
  void save() {
    if (choice == null) { Navigator.pop(context); return; }
    if (choice == 'MENOS_TIEMPO_HABITUAL') {
      final value = int.tryParse(minutes.text.trim());
      if (value == null || value < 15 || value > 180) { setState(() => error = 'Indica entre 15 y 180 minutos'); return; }
      Navigator.pop(context, <String, dynamic>{'lackOfTimeContext': choice, 'availableMinutes': value});
      return;
    }
    Navigator.pop(context, <String, dynamic>{'lackOfTimeContext': choice});
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sobre la falta de tiempo'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Opcional: nos ayuda a ajustar tu próxima semana.'),
      RadioGroup<String>(
        groupValue: choice,
        onChanged: (v) => setState(() { choice = v; error = null; }),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final entry in options.entries) RadioListTile<String>(contentPadding: EdgeInsets.zero, value: entry.key, title: Text(entry.value)),
        ]),
      ),
      if (choice == 'MENOS_TIEMPO_HABITUAL') TextField(controller: minutes, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Minutos que sueles tener (15–180)', errorText: error)),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Prefiero no decir')),
      FilledButton(onPressed: save, child: const Text('Continuar')),
    ],
  );
}

String displayDay(Object? value) {
  final date = DateTime.tryParse('$value');
  if (date == null) return '$value';
  const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  return '${days[date.weekday - 1]} ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
}

/// Instructions and muscles from `GET /catalog/exercises/{id}`.
class ExerciseInstructions extends ConsumerWidget {
  const ExerciseInstructions({super.key, required this.exerciseId, required this.fallbackName});
  final int exerciseId;
  final String fallbackName;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(exerciseDetailProvider(exerciseId));
    return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), child: detail.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: LinearProgressIndicator()),
      error: (e, _) => Column(mainAxisSize: MainAxisSize.min, children: [Text(apiError(e)), TextButton(onPressed: () => ref.invalidate(exerciseDetailProvider(exerciseId)), child: const Text('Reintentar'))]),
      data: (data) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('${data['name'] ?? fallbackName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text([
          if (data['targetMuscle'] != null) 'Músculo principal: ${data['targetMuscle']}',
          if ((data['secondaryMuscles'] as List?)?.isNotEmpty == true) 'Secundarios: ${(data['secondaryMuscles'] as List).join(', ')}',
        ].join('\n'), style: const TextStyle(color: Kora.muted)),
        const SizedBox(height: 16),
        Text('${data['instructions'] ?? 'El catálogo no incluye instrucciones para este ejercicio.'}', style: const TextStyle(height: 1.5)),
        if (data['mediaAttribution'] != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text('${data['mediaAttribution']}', style: const TextStyle(fontSize: 11, color: Kora.muted))),
      ]),
    )));
  }
}

class FinishDialog extends StatefulWidget {
  const FinishDialog({super.key, this.reporting = false, this.suggestedMinutes});
  final bool reporting;

  /// Active minutes measured by the session clock (pauses excluded).
  final int? suggestedMinutes;
  @override
  State<FinishDialog> createState() => _FinishDialogState();
}
class _FinishDialogState extends State<FinishDialog> {
  final form = GlobalKey<FormState>();
  late final minutes = TextEditingController(text: widget.suggestedMinutes?.toString() ?? '');
  int? rpe, satisfaction;
  DateTime? performedAt;
  Future<void> chooseDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: performedAt ?? now, firstDate: DateTime(2000), lastDate: now);
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(performedAt ?? now));
    if (time == null || !mounted) return;
    setState(() => performedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
  @override
  void dispose() { minutes.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Finalizar entrenamiento'), content: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('El progreso se calculará con los ejercicios que registraste.'),
    if (widget.reporting) FormField<DateTime>(validator: (_) => performedAt == null ? 'Selecciona cuándo entrenaste' : performedAt!.isAfter(DateTime.now()) ? 'La fecha no puede ser futura' : null, builder: (field) => Column(children: [TextButton(onPressed: chooseDate, child: Text(performedAt == null ? 'Elegir fecha y hora del entrenamiento' : '${performedAt!.day}/${performedAt!.month}/${performedAt!.year} ${TimeOfDay.fromDateTime(performedAt!).format(context)}')), if (field.hasError) Text(field.errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error))])),
    DropdownButtonFormField<int>(initialValue: rpe, decoration: const InputDecoration(labelText: 'Esfuerzo percibido (1–10)'), items: [for (var i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i'))], onChanged: (value) => setState(() => rpe = value), validator: (value) => value == null ? 'Selecciona el esfuerzo percibido' : null),
    DropdownButtonFormField<int>(initialValue: satisfaction, decoration: const InputDecoration(labelText: 'Satisfacción (opcional, 1–5)'), items: [for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i'))], onChanged: (value) => setState(() => satisfaction = value)),
    TextFormField(controller: minutes, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Minutos activos (opcional)', helperText: widget.suggestedMinutes == null ? null : 'Según el cronómetro, sin pausas'), validator: (v) => (v ?? '').isEmpty || (int.tryParse(v!) != null && int.parse(v) >= 0) ? null : 'Escribe minutos válidos'),
  ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () {
    if (!form.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{if (widget.reporting) 'performedAt': performedAt!.toUtc().toIso8601String(), 'sessionRpe': rpe, if (satisfaction != null) 'satisfaction': satisfaction, if (minutes.text.isNotEmpty) 'activeMinutes': int.parse(minutes.text)});
  }, child: const Text('Finalizar'))]);
}
