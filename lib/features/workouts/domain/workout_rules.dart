// Rules mirrored from the backend so the app offers only actions the server
// accepts. Sources (Fitsense-Real/Backend):
// - planning WorkoutStatus: SCHEDULED, IN_PROGRESS, COMPLETED, PARTIAL,
//   SKIPPED, REPLACED.
// - execution WorkoutSessionCommandServiceImpl: start requires an open
//   (SCHEDULED/IN_PROGRESS) workout that is not past `expiresAt`; report
//   rejects only COMPLETED and PARTIAL, so expired (SKIPPED) workouts can be
//   reported retroactively.
// - execution WorkoutSessionExercise: completion = actual / planned, where the
//   planned total is sets × reps (SETS_REPS) or sets × seconds (DURATION).

import '../../../core/api/json.dart';

const workoutStatusLabels = {
  'SCHEDULED': 'Programado',
  'IN_PROGRESS': 'En curso',
  'COMPLETED': 'Completado',
  'PARTIAL': 'Parcial',
  'SKIPPED': 'Omitido',
  'REPLACED': 'Reemplazado',
};

String workoutStatusLabel(Object? status) =>
    workoutStatusLabels['$status'] ?? (status == null ? 'Programado' : '$status');

/// Focus codes of planning `WorkoutFocus`.
const workoutFocusLabels = {
  'FULL_BODY': 'Cuerpo completo',
  'UPPER_BODY': 'Tren superior',
  'LOWER_BODY': 'Tren inferior',
  'PUSH': 'Empuje',
  'PULL': 'Tracción',
  'LEGS': 'Piernas',
  'CORE': 'Core',
};

const sessionStatusLabels = {
  'IN_PROGRESS': 'En curso',
  'COMPLETED': 'Completada',
  'PARTIAL': 'Parcial',
  'ABANDONED': 'Abandonada',
};

String workoutStatusOf(Json workout) => '${workout['status'] ?? 'SCHEDULED'}';

bool isOpenWorkout(Json workout) =>
    const {'SCHEDULED', 'IN_PROGRESS'}.contains(workoutStatusOf(workout));

/// Whether `expiresAt` (23:59 local time of the user, sent as an offset
/// timestamp) has passed. Unknown expiry is treated as not expired.
bool isExpiredWorkout(Json workout, {DateTime? now}) {
  final expires = DateTime.tryParse('${workout['expiresAt']}');
  return expires != null && (now ?? DateTime.now()).isAfter(expires);
}

/// A live session can be started only on open, non-expired workouts.
bool canStartWorkout(Json workout, {DateTime? now}) =>
    isOpenWorkout(workout) && !isExpiredWorkout(workout, now: now);

/// Retroactive report: allowed unless the workout already counts
/// (COMPLETED/PARTIAL) or belongs to a replaced plan version.
bool canReportWorkout(Json workout) =>
    const {'SCHEDULED', 'IN_PROGRESS', 'SKIPPED'}.contains(workoutStatusOf(workout));

/// Declaring a skip only makes sense while the workout is still open.
bool canSkipWorkout(Json workout) => isOpenWorkout(workout);

bool isDurationBased(Json exercise) =>
    exercise['prescriptionType'] == 'DURATION' ||
    (exercise['prescriptionType'] == null &&
        (exercise['plannedReps'] as num? ?? 0) <= 0 &&
        (exercise['plannedDurationSeconds'] as num? ?? 0) > 0);

/// Planned total the backend uses as denominator of the exercise completion.
int plannedTotal(Json exercise) {
  final sets = (exercise['plannedSets'] as num?)?.toInt();
  if (isDurationBased(exercise)) {
    final seconds = (exercise['plannedDurationSeconds'] as num?)?.toInt() ?? 0;
    return (sets ?? 1) * seconds;
  }
  return (sets ?? 0) * ((exercise['plannedReps'] as num?)?.toInt() ?? 0);
}

/// Body for "Lo completé": exactly what was prescribed, in the units the
/// backend compares (total reps, or total seconds across all sets).
Json prescribedResult(Json exercise) {
  final duration = isDurationBased(exercise);
  return {
    'actualSets': exercise['plannedSets'] ?? (duration ? 1 : 0),
    'actualRepsTotal': duration ? 0 : plannedTotal(exercise),
    'actualDurationSeconds': duration ? plannedTotal(exercise) : 0,
    'actualLoadKg': exercise['targetLoadKg'],
    'skipReason': null,
  };
}
