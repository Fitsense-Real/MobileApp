import 'package:flutter/foundation.dart';
import '../../../core/api/json.dart';
import '../../workouts/domain/workout_rules.dart' show workoutFocusLabels;

// What happened with each weekly adaptation, in plain words. Only translates what the backend sends
// (`GET /users/me/plan/adaptations` → AdaptationOutcome, and `adjustmentApplied` of each plan); it decides
// nothing and never changes the data. Codes are never shown: an unknown one gets a general text and is
// reported for diagnosis.
//
// Backend semantics (generation 98276a9):
// - `resultado` says what really happened to the week (AdaptationOutcome.de / AdaptationOutcomeQueryService).
// - `decision` (AdaptationDecision) says why the week was reviewed: NO_CHANGE, INSUFFICIENT_DATA,
//   ADAPT_LOCALIZED, ADAPT_EXPANDED. It is NOT proof that anything changed.
// - `adjustmentApplied` of a plan is the decision's name when it ordered adapting (ADAPT_LOCALIZED /
//   ADAPT_EXPANDED, «también cuando nada se cambió»), SAFETY_REPAIR for a safety repair, or an older
//   AdjustmentType (REDUCE_VOLUME…); null when nothing was ordered.
// - `motivoTexto` is the backend's neutral reason; `motivos` may hold internal validator texts and is not shown.

enum AdaptationKind {
  /// The published week changed (adjustment, safety substitution, progression, safe regeneration).
  changed,

  /// The routine was kept as it was (no order, nothing to change, or a proposal that was not applied).
  kept,

  /// No week was published (NO_FACTIBLE…).
  notFeasible,

  /// A code this version does not know.
  unknown,
}

class AdaptationText {
  const AdaptationText({required this.title, required this.kind, this.reason, this.details = const []});

  /// Natural title of the week's outcome.
  final String title;
  final AdaptationKind kind;

  /// The backend's neutral reason (`motivoTexto`), when it sends one.
  final String? reason;

  /// What changed or why, built only from the backend's data.
  final List<String> details;
}

/// `resultado` → (title, kind). Exactly the values of AdaptationOutcome and AdaptationOutcomeQueryService.
const _outcomes = <String, (String, AdaptationKind)>{
  'ADAPTACION_APLICADA': ('Se ajustó parte de tu rutina', AdaptationKind.changed),
  'REGENERACION_SEGURA_SUSTITUCION': ('Se sustituyó un ejercicio por seguridad', AdaptationKind.changed),
  'REGENERACION_SEGURA_REGLAS': ('Se preparó una semana nueva que respeta tus restricciones', AdaptationKind.changed),
  'PROGRESION_DEL_BACKEND': ('Tu rutina avanzó un paso', AdaptationKind.changed),
  'SIN_ADAPTACION': ('Tu rutina se mantiene igual', AdaptationKind.kept),
  'CONSERVACION_DELIBERADA': ('Tu rutina se mantiene igual: no había nada que cambiar', AdaptationKind.kept),
  'SIN_CAMBIOS_VALIDOS': ('Se revisó tu rutina, pero no hubo un cambio aplicable: se mantiene igual', AdaptationKind.kept),
  'RESPALDO_PROPUESTA_IA_INVALIDA': ('Se propuso un ajuste que no pasó las comprobaciones de seguridad: tu rutina se mantiene igual', AdaptationKind.kept),
  'RESPALDO_SIN_IA': ('No se pudo preparar un ajuste esa semana: tu rutina se mantiene igual', AdaptationKind.kept),
  'ACORTAMIENTO_IMPOSIBLE': ('No era posible acortar más tus sesiones: tu rutina se mantiene igual', AdaptationKind.kept),
  'REPROGRAMACION_IMPOSIBLE': ('No era posible cambiar los días de tus sesiones: tu rutina se mantiene igual', AdaptationKind.kept),
  'ADAPTACION_IMPOSIBLE': ('No había un ajuste posible dentro de tus condiciones: tu rutina se mantiene igual', AdaptationKind.kept),
  // AdaptationOutcome falls back to the raw status; RECHAZADA is the only V32 status without its own result.
  'RECHAZADA': ('Se propuso un ajuste que no se aplicó: tu rutina se mantiene igual', AdaptationKind.kept),
  'NO_FACTIBLE_POR_SEGURIDAD': ('Kora no pudo adaptar esa semana sin volver a proponer lo que te dolió', AdaptationKind.notFeasible),
  'NO_FACTIBLE': ('Kora no pudo adaptar esa semana dentro de tus restricciones', AdaptationKind.notFeasible),
};

/// `decision` (AdaptationDecision): why the week was reviewed.
const _decisions = <String, String>{
  'NO_CHANGE': 'Tus registros no mostraban baja adherencia, así que no hacía falta un ajuste.',
  'INSUFFICIENT_DATA': 'Aún faltaban entrenamientos registrados para evaluar cambios.',
  'ADAPT_LOCALIZED': 'Algunas sesiones tuvieron menos cumplimiento: Kora revisó esas sesiones.',
  'ADAPT_EXPANDED': 'Varias sesiones tuvieron menos cumplimiento: Kora revisó varias sesiones.',
};

/// Short label for the plan history, from `adjustmentApplied` when there is no adaptation record.
const _adjustments = <String, String?>{
  'ADAPT_LOCALIZED': 'Revisión de parte de tu rutina',
  'ADAPT_EXPANDED': 'Revisión de varias sesiones',
  'SAFETY_REPAIR': 'Ajustada por seguridad',
  'NONE': null,
  'NO_CHANGE': null,
  'INSUFFICIENT_DATA': null,
  'REDUCE_VOLUME': 'Menos volumen',
  'REDUCE_DURATION': 'Sesiones más cortas',
  'REDUCE_DAYS': 'Menos días',
  'LOWER_DIFFICULTY': 'Menor dificultad',
  'LOWER_LOAD': 'Menos carga',
};

/// Short labels for the plan history, per `resultado`.
const _shortOutcomes = <String, String>{
  'ADAPTACION_APLICADA': 'Rutina ajustada',
  'REGENERACION_SEGURA_SUSTITUCION': 'Sustitución por seguridad',
  'REGENERACION_SEGURA_REGLAS': 'Semana nueva por seguridad',
  'PROGRESION_DEL_BACKEND': 'Progresión',
};

/// Reports a code this version does not know, for diagnosis. Never shown to the user.
@visibleForTesting
void Function(String message) reportUnknownCode = (message) => debugPrint(message);

const _unknownTitle = 'Kora revisó tu plan de esa semana';

/// The week's outcome in plain words, from one AdaptationOutcome.
AdaptationText describeAdaptation(Json adaptation) {
  final code = '${adaptation['resultado'] ?? ''}';
  final known = _outcomes[code];
  if (known == null) reportUnknownCode('Kora: resultado de adaptación desconocido «$code» (semana ${adaptation['weekStartDate']})');
  final kind = known?.$2 ?? AdaptationKind.unknown;
  final reason = adaptation['motivoTexto'];
  return AdaptationText(
    title: known?.$1 ?? _unknownTitle,
    kind: kind,
    reason: reason is String && reason.trim().isNotEmpty ? reason.trim() : null,
    details: [
      if (kind == AdaptationKind.notFeasible) 'No se publicó una rutina nueva para esa semana.',
      ..._sessionDetails(adaptation),
      // PROGRESION_DEL_BACKEND: no order to adapt (NO_CHANGE) and good adherence; ProgresionResolver took a step.
      if (code == 'PROGRESION_DEL_BACKEND') 'Con tu buen cumplimiento, Kora subió un poco la exigencia de tu rutina.'
      else if (_decisionText(adaptation['decision']) case final why?) why,
    ],
  );
}

String? _decisionText(Object? decision) {
  if (decision == null) return null;
  final text = _decisions['$decision'];
  if (text == null) reportUnknownCode('Kora: decisión de adaptación desconocida «$decision»');
  return text;
}

List<String> _sessionDetails(Json adaptation) {
  final details = <String>[];
  final affected = adaptation['sesionAfectada'];
  if (affected is Map) {
    final date = DateTime.tryParse('${affected['fecha']}');
    final focus = workoutFocusLabels['${affected['enfoque']}'];
    if (date != null) {
      details.add('Sesión revisada: ${_day(date)}${focus == null ? '' : ' ($focus)'}.');
    }
  }
  final counts = <String, int>{};
  for (final s in jsonRows(adaptation['sesiones'] ?? const [])) {
    counts.update('${s['resultado']}', (n) => n + 1, ifAbsent: () => 1);
  }
  String sessions(int n) => n == 1 ? '1 sesión' : '$n sesiones';
  if (counts['APLICADA'] case final n?) details.add('${sessions(n)} con cambios.');
  if (counts['PROGRESADA'] case final n?) details.add('${sessions(n)} con un paso de progresión.');
  return details;
}

String _day(DateTime d) {
  const days = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  return '${days[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// Short label of a plan in the history: from the adaptation that published it when there is one (it says
/// what really happened), otherwise from `adjustmentApplied` without claiming a change. Null: nothing to say.
String? planHistoryLabel(Json plan, List<Json> adaptations) {
  final adaptation = adaptations.where((a) => a['resultingPlanId'] != null && a['resultingPlanId'] == plan['planId']).firstOrNull;
  if (adaptation != null) {
    final code = '${adaptation['resultado']}';
    if (_shortOutcomes[code] case final label?) return label;
    final text = describeAdaptation(adaptation);
    return switch (text.kind) {
      AdaptationKind.kept => 'Sin cambios',
      AdaptationKind.changed => 'Plan ajustado',
      AdaptationKind.notFeasible => null, // a published plan never comes from a NO_FACTIBLE outcome
      AdaptationKind.unknown => 'Plan revisado',
    };
  }
  final labels = <String>[];
  for (final code in '${plan['adjustmentApplied'] ?? ''}'.split(RegExp(r'[,\s]+')).where((c) => c.isNotEmpty && c != 'null')) {
    if (_adjustments.containsKey(code)) {
      if (_adjustments[code] case final label?) labels.add(label);
    } else {
      reportUnknownCode('Kora: ajuste de plan desconocido «$code» (plan ${plan['planId']})');
      labels.add('Plan ajustado');
    }
  }
  return labels.isEmpty ? null : labels.toSet().join(', ');
}

/// Every adaptation, newest week first (the history of adaptations).
List<Json> adaptationHistoryOf(List<Json> adaptations) =>
    [...adaptations]..sort((a, b) => '${b['weekStartDate']}'.compareTo('${a['weekStartDate']}'));
