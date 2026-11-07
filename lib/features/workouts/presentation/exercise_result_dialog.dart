import 'package:flutter/material.dart';
import '../../../core/api/json.dart';
import '../domain/workout_rules.dart';

export '../domain/workout_rules.dart' show prescribedResult;

const skipReasons = {
  'LACK_OF_TIME': 'Falta de tiempo', 'FATIGUE': 'Fatiga',
  'LACK_OF_MOTIVATION': 'Falta de motivación', 'TOO_DIFFICULT': 'Demasiado difícil',
  'PAIN_OR_DISCOMFORT': 'Dolor o molestias', 'SCHEDULE_CHANGE': 'Cambio de horario', 'OTHER': 'Otro motivo',
};

String exercisePrescription(Json exercise) {
  final sets = exercise['plannedSets'];
  final reps = exercise['plannedReps'];
  final seconds = exercise['plannedDurationSeconds'];
  return [
    if (sets != null) '$sets ${sets == 1 ? 'serie' : 'series'}',
    if (isDurationBased(exercise))
      seconds is num && seconds > 0 ? '$seconds s por serie' : 'Duración no indicada en el plan'
    else
      reps is num && reps > 0 ? '$reps repeticiones por serie' : 'Repeticiones no indicadas en el plan',
    if (exercise['targetLoadKg'] != null) '${exercise['targetLoadKg']} kg',
  ].join(' · ');
}

/// Label of a session exercise. Uses the backend `status` (ExerciseOutcome:
/// COMPLETED, PARTIAL, SKIPPED) when present; drafts are classified locally.
String resultLabel(Json? result) {
  if (result == null) return 'Sin registrar';
  switch (result['status']) {
    case 'COMPLETED': return 'Completado';
    case 'PARTIAL': return 'Parcial';
    case 'SKIPPED': return 'No realizado';
  }
  final amount = ['actualSets', 'actualRepsTotal', 'actualDurationSeconds'].fold<num>(0, (sum, key) => sum + (result[key] as num? ?? 0));
  if (amount == 0) return result['skipReason'] != null ? 'No realizado' : 'Sin registrar';
  if (result['completionPercentage'] is num) return (result['completionPercentage'] as num) >= 100 ? 'Completado' : 'Parcial';
  return result['skipReason'] != null ? 'Parcial' : 'Realizado';
}

class ExerciseResultDialog extends StatefulWidget {
  const ExerciseResultDialog({super.key, required this.exercise, this.existing, this.draft = false});
  final Json exercise;
  final Json? existing;
  final bool draft;
  @override
  State<ExerciseResultDialog> createState() => _ExerciseResultDialogState();
}
class _ExerciseResultDialogState extends State<ExerciseResultDialog> {
  final form = GlobalKey<FormState>();
  static const fields = {'actualSets': 'Series realizadas', 'actualRepsTotal': 'Repeticiones totales (todas las series)', 'actualDurationSeconds': 'Duración total realizada (segundos, todas las series)', 'actualLoadKg': 'Carga utilizada (kg)'};
  late final controllers = {for (final key in fields.keys) key: TextEditingController(text: '${widget.existing?[key] ?? ''}')};
  late final bool unsafe = isUnsafeExercise(widget.exercise);
  late String? outcome = unsafe ? 'none' : null;
  String? message;
  late String? reason = widget.existing?['skipReason'] as String?;
  @override
  void dispose() { for (final controller in controllers.values) { controller.dispose(); } super.dispose(); }
  void choose(String value) => setState(() {
    outcome = value; message = null;
    if (value == 'complete' || value == 'none') {
      final defaults = prescribedResult(widget.exercise);
      for (final entry in controllers.entries) { entry.value.text = value == 'none' ? '0' : '${defaults[entry.key] ?? ''}'; }
    }
    if (value == 'complete') reason = null;
  });
  void save() {
    if (outcome == null) { setState(() => message = 'Indica si realizaste el ejercicio.'); return; }
    if (!form.currentState!.validate()) return;
    final Json body = outcome == 'complete' ? prescribedResult(widget.exercise) : outcome == 'none' ? {'actualSets': 0, 'actualRepsTotal': 0, 'actualDurationSeconds': 0, 'actualLoadKg': 0, 'skipReason': reason} : {for (final e in controllers.entries) e.key: e.key == 'actualLoadKg' ? num.tryParse(e.value.text.replaceAll(',', '.')) : num.tryParse(e.value.text.replaceAll(',', '.')) ?? 0, 'skipReason': reason};
    if (outcome != 'none' && ['actualSets', 'actualRepsTotal', 'actualDurationSeconds'].every((key) => body[key] == 0)) {
      setState(() => message = 'Registra al menos una serie, repetición o segundo realizado.'); return;
    }
    Navigator.pop(context, body);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: Text('${widget.exercise['exerciseName']}'), content: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(exercisePrescription(widget.exercise), style: const TextStyle(fontWeight: FontWeight.w700)),
    const SizedBox(height: 12),
    Text(widget.draft ? 'Completa el resultado. Se enviará cuando guardes el entrenamiento.' : 'Guardar reemplaza el resultado anterior en tu sesión.'),
    const SizedBox(height: 12),
    if (unsafe) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Este ejercicio ya no es seguro para ti (${widget.exercise['safetyBlockReason']}). Solo puedes registrarlo como no realizado.', style: TextStyle(color: Theme.of(context).colorScheme.error))),
    Wrap(spacing: 8, children: [for (final entry in {'complete': 'Lo completé', 'partial': 'Lo hice parcialmente', 'none': 'No lo hice'}.entries) if (!unsafe || entry.key == 'none') ChoiceChip(label: Text(entry.value), selected: outcome == entry.key, onSelected: (_) => choose(entry.key))]),
    if (outcome == 'complete') const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Se usarán las cantidades de tu plan. Si hiciste menos, elige parcialmente.')),
    if (outcome != 'none') for (final entry in fields.entries) Padding(padding: const EdgeInsets.only(top: 12), child: TextFormField(
      controller: controllers[entry.key], readOnly: outcome == 'complete', decoration: InputDecoration(labelText: entry.value),
      keyboardType: TextInputType.numberWithOptions(decimal: entry.key == 'actualLoadKg'), validator: (value) {
        if (value == null || value.trim().isEmpty) return null;
        final parsed = entry.key == 'actualLoadKg' ? double.tryParse(value.replaceAll(',', '.')) : int.tryParse(value);
        return parsed == null || !parsed.isFinite || parsed < 0 ? 'Escribe un número válido, mayor o igual a 0' : null;
      },
    )),
    if (outcome == 'partial' || outcome == 'none') ...[
      const SizedBox(height: 12), DropdownButtonFormField<String>(value: reason, isExpanded: true, decoration: const InputDecoration(labelText: 'Motivo'), items: [for (final e in skipReasons.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (value) => setState(() => reason = value), validator: (v) => v == null ? 'Selecciona un motivo' : null),
    ],
    if (message != null) Text(message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: save, child: Text(widget.draft ? 'Usar resultado' : 'Guardar'))]);
}
