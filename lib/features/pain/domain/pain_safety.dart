import '../../../core/api/json.dart';

// O20 (Backend PR #84, docs/FitSense/seguridad_o20/ESPEC_MOBILE_EXCLUSIONES.md).
// The backend decides what is excluded, why and until when; the app only
// reads it and explains it. Nothing here decides that an exercise is safe.

/// `origin` of `GET /users/me/pain-exclusions/effective`.
enum PainOrigin {
  /// The exercise has its own exclusion: it was marked with pain, or it was in
  /// a session reported with pain without saying which exercise.
  direct,

  /// A variant equivalent to a directly excluded exercise.
  equivalent,

  /// The same movement with another angle or support (incline, decline...).
  precaution,

  /// A value this version does not know: still excluded, explained generically.
  unknown;

  static PainOrigin parse(Object? value) => switch ('$value') {
    'DIRECT' => direct,
    'EQUIVALENT' => equivalent,
    'PRECAUTION' => precaution,
    _ => unknown,
  };
}

/// One exercise that is not prescribed today because of pain
/// (`EffectivePainExclusionResource`).
class EffectiveExclusion {
  const EffectiveExclusion({
    required this.exerciseId,
    required this.origin,
    this.exerciseName,
    this.confirmed = false,
    this.provisional = false,
    this.confirmationRequired = false,
    this.derivedFromExerciseId,
    this.derivedFromExerciseName,
    this.equivalenceLevel,
    this.equivalenceGroup,
    this.equivalenceJustification,
    this.sourcePlannedWorkoutId,
    this.eventDate,
    this.canIdentify = false,
    this.canReactivate = false,
  });

  factory EffectiveExclusion.fromJson(Json json) => EffectiveExclusion(
    exerciseId: (json['exerciseId'] as num).toInt(),
    exerciseName: json['exerciseName'] as String?,
    origin: PainOrigin.parse(json['origin']),
    confirmed: json['confirmed'] == true,
    provisional: json['provisional'] == true,
    confirmationRequired: json['confirmationRequired'] == true,
    derivedFromExerciseId: (json['derivedFromExerciseId'] as num?)?.toInt(),
    derivedFromExerciseName: json['derivedFromExerciseName'] as String?,
    equivalenceLevel: json['equivalenceLevel'] as String?,
    equivalenceGroup: json['equivalenceGroup'] as String?,
    equivalenceJustification: json['equivalenceJustification'] as String?,
    sourcePlannedWorkoutId: (json['sourcePlannedWorkoutId'] as num?)?.toInt(),
    eventDate: json['eventDate'] as String?,
    canIdentify: json['canIdentify'] == true,
    canReactivate: json['canReactivate'] == true,
  );

  final int exerciseId;
  final String? exerciseName;
  final PainOrigin origin;
  final bool confirmed, provisional, confirmationRequired;
  final int? derivedFromExerciseId;
  final String? derivedFromExerciseName;

  /// Technical (`VARIANTE_MISMO_EJERCICIO`, `MISMO_GESTO`, `PRECAUCION_OTRO_ANGULO`
  /// and the group of the backend's list): only for a secondary «¿por qué?».
  final String? equivalenceLevel, equivalenceGroup, equivalenceJustification;
  final int? sourcePlannedWorkoutId;
  final String? eventDate;
  final bool canIdentify, canReactivate;

  String get name => exerciseName ?? 'Ejercicio #$exerciseId';
  String get _source => derivedFromExerciseName ?? (derivedFromExerciseId == null ? 'un ejercicio que te dolió' : 'el ejercicio #$derivedFromExerciseId');

  /// Plain explanation of why the exercise is not prescribed (no codes).
  String get explanation => switch (origin) {
    PainOrigin.direct => confirmed
        ? 'Lo marcaste con dolor.'
        : 'Estaba en una sesión en la que reportaste dolor sin indicar qué ejercicio fue.',
    // Provisional: it is not known yet which exercise of that session hurt.
    PainOrigin.equivalent => provisional
        ? 'Es una variante de «$_source», de la sesión en la que reportaste dolor, mientras confirmamos qué te dolió.'
        : 'Es una variante de «$_source», que te dolió.',
    PainOrigin.precaution => provisional
        ? 'Es el mismo movimiento que «$_source», con otro ángulo o apoyo, mientras confirmamos qué te dolió.'
        : 'Es el mismo movimiento que «$_source», que te dolió, con otro ángulo o apoyo.',
    PainOrigin.unknown => 'Está relacionado con un reporte de dolor.',
  };
}

/// A session with unidentified pain waiting for the user's answer
/// (`PainConfirmationRequestResource`).
class PainConfirmationRequest {
  const PainConfirmationRequest({required this.plannedWorkoutId, required this.exercises, this.eventDate, this.confirmationRequired = false});

  factory PainConfirmationRequest.fromJson(Json json) => PainConfirmationRequest(
    plannedWorkoutId: (json['plannedWorkoutId'] as num?)?.toInt(),
    eventDate: json['eventDate'] as String?,
    confirmationRequired: json['confirmationRequired'] == true,
    exercises: [
      for (final e in jsonRows(json['exercises'] ?? const []))
        (id: (e['exerciseId'] as num).toInt(), name: (e['exerciseName'] as String?) ?? 'Ejercicio #${e['exerciseId']}'),
    ],
  );

  final int? plannedWorkoutId;
  final String? eventDate;

  /// Two weeks with a plan have passed: Kora asks actively. Otherwise it can
  /// be answered, but without insisting.
  final bool confirmationRequired;
  final List<({int id, String name})> exercises;
}

/// Validates the answer before sending it. The backend validates again (422).
/// Returns the problem to show, or null when the answer can be sent.
String? identificationProblem(PainConfirmationRequest request, int? painful, Set<int> unrelated) {
  if (painful == null) return 'Elige qué ejercicio te dolió.';
  final ids = {for (final e in request.exercises) e.id};
  if (!ids.contains(painful)) return 'Ese ejercicio no es de esta sesión.';
  if (unrelated.contains(painful)) return 'El ejercicio que te dolió no puede ser a la vez uno que no tuvo que ver.';
  if (!ids.containsAll(unrelated)) return 'Solo puedes indicar ejercicios de esta sesión.';
  return null;
}

/// Answer of `POST …/{exerciseId}/identification` (`Identificacion`).
class IdentificationResult {
  const IdentificationResult({
    required this.exerciseId,
    this.confirmedExclusions = const [],
    this.identifiedAt,
    this.equivalentsExcluded = const [],
    this.unrelatedLifted = const [],
    this.unrelatedNotLifted = const {},
    this.stillExcludedFromSession = const [],
    this.note,
  });

  factory IdentificationResult.fromJson(Json json) {
    List<int> ids(Object? v) => [for (final x in (v as List?) ?? const []) if (x is num) x.toInt()];
    final notLifted = (json['noRelacionadosNoLevantados'] as Map?) ?? const {};
    return IdentificationResult(
      exerciseId: (json['exerciseId'] as num).toInt(),
      confirmedExclusions: ids(json['exclusionesConfirmadas']),
      identifiedAt: json['identificadaEn'] as String?,
      equivalentsExcluded: ids(json['equivalentesExcluidos']),
      unrelatedLifted: ids(json['noRelacionadosLevantados']),
      unrelatedNotLifted: {for (final e in notLifted.entries) if (int.tryParse('${e.key}') case final id?) id: '${e.value}'},
      stillExcludedFromSession: ids(json['otrosDeLaSesionSiguenExcluidos']),
      note: json['nota'] as String?,
    );
  }

  final int exerciseId;
  final List<int> confirmedExclusions;
  final String? identifiedAt;

  /// Equivalents and precautions, now permanent.
  final List<int> equivalentsExcluded;

  /// Declared unrelated and lifted by the backend.
  final List<int> unrelatedLifted;

  /// Declared unrelated but kept excluded, with the backend's reason.
  final Map<int, String> unrelatedNotLifted;

  /// Not named: they stay excluded, they could also have hurt.
  final List<int> stillExcludedFromSession;
  final String? note;
}

/// Profile restrictions the backend can name in `safetyBlockReason`
/// (SafetyConflictPolicy). Several may come joined with `+`.
const _restrictionLabels = {
  'alto_impacto': 'alto impacto',
  'suelo': 'trabajo en el suelo',
  'carga_axial': 'carga sobre la columna',
  'rodillas': 'apoyo en las rodillas',
  'suspension': 'suspensión',
  'apoyo_suspendido': 'apoyo suspendido',
  'brazos_arriba': 'brazos por encima de la cabeza',
  'inversion': 'posición invertida',
};

const painBlockCode = 'dolor_registrado';

/// Why a prescription of an open session can no longer be done, from its
/// `safetyBlockReason` and, for pain, the matching entry of `/effective`.
/// Null when the backend did not block it.
String? blockExplanation(Json exercise, {List<EffectiveExclusion> effective = const []}) {
  final reason = exercise['safetyBlockReason'];
  if (reason == null) return null;
  final codes = '$reason'.split('+').map((c) => c.trim()).where((c) => c.isNotEmpty).toSet();
  final parts = <String>[];
  if (codes.remove(painBlockCode)) {
    final id = (exercise['exerciseId'] as num?)?.toInt();
    final match = effective.where((e) => e.exerciseId == id).firstOrNull;
    parts.add(match == null ? 'Está relacionado con un reporte de dolor.' : match.explanation);
  }
  if (codes.contains('catalogo_inactivo')) {
    codes.remove('catalogo_inactivo');
    parts.add('Ya no está disponible en el catálogo.');
  }
  final labels = [for (final c in codes) if (_restrictionLabels[c] case final l?) l];
  if (labels.isNotEmpty) parts.add('No es compatible con lo que indicaste en tu perfil (${labels.join(', ')}).');
  if (codes.any((c) => !_restrictionLabels.containsKey(c))) parts.add('Una revisión de seguridad lo retiró por ahora.');
  return parts.join(' ');
}

/// The restrictions a backend message names between parentheses, in plain words
/// («… choca con una restriccion de seguridad vigente (alto_impacto) …» → «alto impacto»).
List<String> _namedRestrictions(String message) => [
  for (final group in RegExp(r'\(([a-z_+, ]+)\)').allMatches(message))
    for (final code in group.group(1)!.split(RegExp(r'[+,]')).map((c) => c.trim()))
      if (_restrictionLabels[code] case final label?) label,
];

String _restrictionSentence(String message) {
  final labels = _namedRestrictions(message);
  return labels.isEmpty
      ? 'no es compatible con una restricción de seguridad vigente'
      : 'no es compatible con una restricción de seguridad vigente (${labels.join(', ')})';
}

/// The backend refused a reactivation (`REACTIVACION_RECHAZADA_POR_SEGURIDAD`): what the user reads, without
/// codes. Null for any other message.
String? reactivationRefusal(String message, String name) {
  if (!message.contains('REACTIVACION_RECHAZADA_POR_SEGURIDAD')) return null;
  final labels = _namedRestrictions(message);
  final restriction = labels.isEmpty ? 'una restricción de seguridad en tu perfil' : 'una restricción de seguridad en tu perfil (${labels.join(', ')})';
  return '«$name» todavía no puede habilitarse porque existe $restriction. '
      'Sigue bloqueado y Kora no te lo propondrá. Puedes continuar con los ejercicios permitidos.';
}

/// Why the backend did not lift an exercise declared unrelated (`noRelacionadosNoLevantados`), in plain words.
String notLiftedReason(String reason) =>
    reason.contains('choca con') || _namedRestrictions(reason).isNotEmpty ? '${_restrictionSentence(reason)[0].toUpperCase()}${_restrictionSentence(reason).substring(1)}.' : reason;

/// Results of an adaptation (`AdaptationOutcome.resultado`) that published
/// nothing: the backend could not adapt the week within the current
/// restrictions.
const notFeasibleAdaptationResults = {'NO_FACTIBLE', 'NO_FACTIBLE_POR_SEGURIDAD'};

/// Plain explanation of a not-feasible adaptation, or null for any other result.
String? notFeasibleExplanation(Json? adaptation) {
  if (adaptation == null || !notFeasibleAdaptationResults.contains(adaptation['resultado'])) return null;
  final reason = adaptation['motivoTexto'];
  return [
    'Kora no ha podido adaptar esa parte del entrenamiento debido a las restricciones actuales.',
    if (adaptation['resultado'] == 'NO_FACTIBLE_POR_SEGURIDAD') 'No vuelve a proponer lo que te dolió ni lo sustituye por algo que no sea seguro.',
    if (reason is String && reason.trim().isNotEmpty) reason.trim(),
  ].join(' ');
}
