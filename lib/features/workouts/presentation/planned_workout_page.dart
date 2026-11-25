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
    Future.microtask(() async { await refreshWorkout(); if (mounted) setState(() {}); });
  }

  /// Re-reads the routine from the current plan (`GET /users/me/plan/current`).
  /// The open session and its records come from the backend too, so a
  /// refresh never duplicates executions.
  Future<void> refreshWorkout() async {
    final Json? plan;
    try {
      plan = await ref.read(planRepositoryProvider).current();
    } catch (_) {
      return; // without connection: keep what is on screen; the backend still checks every record
    }
    final fresh = jsonRows(plan?['workouts'] ?? []).where((w) => w['plannedWorkoutId'] == workout['plannedWorkoutId']).firstOrNull;
    if (!mounted) return;
    if (fresh == null) {
      // Only an open routine can leave the active plan (a new version
      // replaced it); a closed one keeps its history as it was.
      outdated = isOpenWorkout(workout) && plan != null;
      return;
    }
    workout = fresh;
    outdated = false;
    // A draft with work for an exercise that is now blocked cannot be sent.
    for (final e in jsonRows(workout['exercises'] ?? [])) {
      final draft = drafts[e['plannedExerciseId']];
      if (isUnsafeExercise(e) && draft != null && ['actualSets', 'actualRepsTotal', 'actualDurationSeconds'].any((k) => (draft[k] as num? ?? 0) > 0)) {
        drafts.remove(e['plannedExerciseId']);
      }
    }
  }

  Future<void> act(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() { busy = true; error = null; });
    try { await action(); }
    catch (e) {
      if (!mounted) return;
      if (e is DioException && e.response?.statusCode == 422) {
        // The backend refused it (e.g. SESION_BLOQUEADA_POR_SEGURIDAD: an
        // exercise is no longer safe). Show why and its current state.
        final blocked = apiError(e).contains('SESION_BLOQUEADA_POR_SEGURIDAD');
        error = blocked
            ? 'Este ejercicio ya no puede registrarse con trabajo realizado: tiene una restricción por seguridad. Puedes registrarlo como no realizado y seguir con el resto.'
            : apiError(e);
        refreshPainSafety(ref);
        try { session = await repository.current(); await refreshWorkout(); } catch (_) {}
      } else {
        error = apiError(e);
      }
    }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> record(Json exercise) async {
    final records = reporting ? drafts.values.toList() : jsonRows(session?['exercises'] ?? []);
    final existing = records.where((e) => e['plannedExerciseId'] == exercise['plannedExerciseId']).firstOrNull;
    final body = await showDialog<Json>(context: context, builder: (_) => ExerciseResultDialog(exercise: exercise, existing: existing, draft: reporting, blockReason: blockExplanation(exercise, effective: ref.read(effectivePainExclusionsProvider).asData?.value ?? const [])));
    if (body == null || !mounted) return;
    if (reporting) { setState(() => drafts[exercise['plannedExerciseId']] = {...body, 'plannedExerciseId': exercise['plannedExerciseId']}); return; }
    await act(() async { session = await repository.record(session!['sessionId'], exercise['plannedExerciseId'], body); });
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
    final exercises = jsonRows(workout['exercises'] ?? []);
    if (exercises.isEmpty || exercises.any((e) => !drafts.containsKey(e['plannedExerciseId']))) {
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
        Text(resultLabel(resultFor(exercise)), style: const TextStyle(fontWeight: FontWeight.w700)),
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
