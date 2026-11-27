import '../../../core/api/json.dart';
import 'workout_rules.dart';

/// `effortGuidance` of the weekly plan (`WeeklyTrainingPlanResource`): how
/// hard each series should feel, written by the backend. The app shows these
/// texts exactly as received and adds nothing of its own.
class EffortGuidance {
  const EffortGuidance({this.repsInReserve, this.setsRepsText, this.durationText, this.loadText});

  final String? repsInReserve, setsRepsText, durationText, loadText;

  static EffortGuidance? fromJson(Object? value) {
    if (value is! Map) return null;
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    final g = EffortGuidance(
      repsInReserve: text(value['repsInReserve']),
      setsRepsText: text(value['setsRepsText']),
      durationText: text(value['durationText']),
      loadText: text(value['loadText']),
    );
    return g.isEmpty ? null : g;
  }

  bool get isEmpty => setsRepsText == null && durationText == null && loadText == null;

  /// The texts that apply to [exercise]: the one of its prescription type and,
  /// for exercises with external load, the load text.
  List<String> forExercise(Json exercise) => [
        if (isDurationBased(exercise)) ?durationText else ?setsRepsText,
        if (!isDurationBased(exercise) && usesExternalLoad(exercise)) ?loadText,
      ];

  /// The texts that apply to a whole routine, once each.
  List<String> forRoutine(Iterable<Json> exercises) {
    final list = exercises.toList();
    return [
      if (list.any((e) => !isDurationBased(e))) ?setsRepsText,
      if (list.any(isDurationBased)) ?durationText,
      if (list.any((e) => !isDurationBased(e) && usesExternalLoad(e))) ?loadText,
    ];
  }
}

/// A suggested load, or equipment that is not the body weight.
bool usesExternalLoad(Json exercise) {
  if (exercise['targetLoadKg'] != null) return true;
  final equipment = '${exercise['equipment'] ?? ''}'.trim().toLowerCase();
  return equipment.isNotEmpty && equipment != 'body weight';
}
