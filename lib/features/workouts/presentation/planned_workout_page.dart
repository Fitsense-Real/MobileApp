import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../../core/api/json.dart';
import '../../catalog/data/catalog_repository.dart';
import '../domain/workout_rules.dart';
import '../data/workout_repository.dart';

import 'exercise_media.dart';
import 'exercise_result_dialog.dart';

class PlannedWorkoutPage extends ConsumerStatefulWidget {
  const PlannedWorkoutPage({super.key, required this.workout});
  final Json workout;
  @override
  ConsumerState<PlannedWorkoutPage> createState() => _PlannedWorkoutPageState();
}
class _PlannedWorkoutPageState extends ConsumerState<PlannedWorkoutPage> {
  Json? session;
  bool busy = true, closed = false, reporting = false;
  final drafts = <Object, Json>{};
  String? error;
  WorkoutRepository get repository => ref.read(workoutRepositoryProvider);
  bool get ownSession => session?['plannedWorkoutId'] == widget.workout['plannedWorkoutId'];
  @override
  void initState() { super.initState(); Future.microtask(() => act(() async { session = await repository.current(); })); }
  Future<void> act(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() { busy = true; error = null; });
    try { await action(); }
    catch (e) { if (mounted) error = apiError(e); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> record(Json exercise) async {
    final records = reporting ? drafts.values.toList() : jsonRows(session?['exercises'] ?? []);
    final existing = records.where((e) => e['plannedExerciseId'] == exercise['plannedExerciseId']).firstOrNull;
    final body = await showDialog<Json>(context: context, builder: (_) => ExerciseResultDialog(exercise: exercise, existing: existing, draft: reporting));
    if (body == null || !mounted) return;
    if (reporting) { setState(() => drafts[exercise['plannedExerciseId']] = {...body, 'plannedExerciseId': exercise['plannedExerciseId']}); return; }
    await act(() async { session = await repository.record(session!['sessionId'], exercise['plannedExerciseId'], body); });
  }
  Future<void> prepareRecord(Json exercise) async {
    if (!ownSession && !reporting) {
      final mode = await showDialog<String>(context: context, builder: (context) => SimpleDialog(title: const Text('Registrar ejercicio'), children: [
        if (canStartWorkout(widget.workout)) SimpleDialogOption(onPressed: () => Navigator.pop(context, 'start'), child: const Text('Comenzar sesión y registrar')),
        if (canReportWorkout(widget.workout)) SimpleDialogOption(onPressed: () => Navigator.pop(context, 'report'), child: const Text('Ya hice este entrenamiento')),
      ]));
      if (mode == null || !mounted) return;
      if (mode == 'report') { setState(() => reporting = true); }
      else {
        await act(() async { session = await repository.current(); session ??= await repository.start(widget.workout['plannedWorkoutId']); });
        if (!mounted || !ownSession || error != null) return;
      }
    }
    if (mounted) await record(exercise);
  }
  Future<void> report() async {
    final exercises = jsonRows(widget.workout['exercises'] ?? []);
    if (exercises.isEmpty || exercises.any((e) => !drafts.containsKey(e['plannedExerciseId']))) {
      setState(() => error = 'Indica el resultado de cada ejercicio antes de guardar.'); return;
    }
    final body = await showDialog<Json>(context: context, builder: (_) => const FinishDialog(reporting: true));
    if (body == null || !mounted) return;
    await act(() async {
      session = await repository.report(widget.workout['plannedWorkoutId'], {...body, 'exercises': exercises.map((e) => drafts[e['plannedExerciseId']]).toList()});
      closed = true; reporting = false;
    });
  }
  Future<void> finish() async {
    final records = jsonRows(session?['exercises'] ?? []);
    if (jsonRows(widget.workout['exercises'] ?? []).any((e) => resultLabel(records.where((r) => r['plannedExerciseId'] == e['plannedExerciseId']).firstOrNull) == 'Sin registrar')) {
      setState(() => error = 'Indica si realizaste o no cada ejercicio antes de finalizar.'); return;
    }
    final body = await showDialog<Json>(context: context, builder: (_) => const FinishDialog());
    if (body == null || !mounted) return;
    await act(() async { session = await repository.finish(session!['sessionId'], body); closed = true; });
  }
  Future<void> skip() async {
    final reason = await showDialog<String>(context: context, builder: (context) => SimpleDialog(title: const Text('¿Por qué omites este entrenamiento?'), children: [
      for (final entry in skipReasons.entries) SimpleDialogOption(onPressed: () => Navigator.pop(context, entry.key), child: Text(entry.value)),
    ]));
    if (reason == null || !mounted) return;
    await act(() async { await repository.skip(widget.workout['plannedWorkoutId'], reason); closed = true; });
  }
  Future<void> abandon() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Abandonar sesión'), content: const Text('La sesión no contará como intento y el entrenamiento seguirá pendiente.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar entrenando')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonar'))]));
    if (confirmed != true || !mounted) return;
    await act(() async { await repository.abandon(session!['sessionId']); session = null; });
  }
  Json? resultFor(Json exercise) => (reporting ? drafts.values : jsonRows(session?['exercises'] ?? []))
      .where((e) => e['plannedExerciseId'] == exercise['plannedExerciseId']).firstOrNull;

  Future<void> showInstructions(Json exercise) => showModalBottomSheet<void>(
    context: context, showDragHandle: true, isScrollControlled: true,
    builder: (_) => ExerciseInstructions(exerciseId: (exercise['exerciseId'] as num).toInt(), fallbackName: '${exercise['exerciseName'] ?? 'Ejercicio'}'),
  );

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final exercises = jsonRows(workout['exercises'] ?? [])..sort((a,b) => ((a['exerciseOrder'] as num?) ?? 0).compareTo((b['exerciseOrder'] as num?) ?? 0));
    final canStart = canStartWorkout(workout);
    final canReport = canReportWorkout(workout);
    final editable = !closed && (ownSession || reporting || (session == null && (canStart || canReport)));
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
  const FinishDialog({super.key, this.reporting = false});
  final bool reporting;
  @override
  State<FinishDialog> createState() => _FinishDialogState();
}
class _FinishDialogState extends State<FinishDialog> {
  final form = GlobalKey<FormState>();
  final minutes = TextEditingController();
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
    DropdownButtonFormField<int>(value: rpe, decoration: const InputDecoration(labelText: 'Esfuerzo percibido (1–10)'), items: [for (var i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i'))], onChanged: (value) => setState(() => rpe = value), validator: (value) => value == null ? 'Selecciona el esfuerzo percibido' : null),
    DropdownButtonFormField<int>(value: satisfaction, decoration: const InputDecoration(labelText: 'Satisfacción (opcional, 1–5)'), items: [for (var i = 1; i <= 5; i++) DropdownMenuItem(value: i, child: Text('$i'))], onChanged: (value) => setState(() => satisfaction = value)),
    TextFormField(controller: minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minutos activos (opcional)'), validator: (v) => (v ?? '').isEmpty || (int.tryParse(v!) != null && int.parse(v) >= 0) ? null : 'Escribe minutos válidos'),
  ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: () {
    if (!form.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{if (widget.reporting) 'performedAt': performedAt!.toUtc().toIso8601String(), 'sessionRpe': rpe, if (satisfaction != null) 'satisfaction': satisfaction, if (minutes.text.isNotEmpty) 'activeMinutes': int.parse(minutes.text)});
  }, child: const Text('Finalizar'))]);
}
