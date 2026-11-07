import '../../../core/api/json.dart';
import '../../workouts/domain/workout_rules.dart';

/// Per-user reminder preferences, stored on the device.
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.hour = 8,
    this.minute = 0,
    this.dueWarning = true,
    this.configured = false,
  });

  /// Master switch for every workout reminder.
  final bool enabled;

  /// Local time of the "Hoy toca…" reminder on the workout day.
  final int hour, minute;

  /// Extra warning at [dueWarningHour] when the workout is still pending,
  /// before it expires at 23:59 (the backend's `expiresAt`).
  final bool dueWarning;

  /// False until the user (or the first-run permission prompt) decided.
  final bool configured;

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute, bool? dueWarning, bool? configured}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        dueWarning: dueWarning ?? this.dueWarning,
        configured: configured ?? this.configured,
      );

  Json toJson() => {'enabled': enabled, 'hour': hour, 'minute': minute, 'dueWarning': dueWarning, 'configured': configured};

  factory ReminderSettings.fromJson(Json json) => ReminderSettings(
    enabled: json['enabled'] != false,
    hour: ((json['hour'] as num?)?.toInt() ?? 8).clamp(0, 23),
    minute: ((json['minute'] as num?)?.toInt() ?? 0).clamp(0, 59),
    dueWarning: json['dueWarning'] != false,
    configured: json['configured'] == true,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled && other.hour == hour && other.minute == minute &&
      other.dueWarning == dueWarning && other.configured == configured;

  @override
  int get hashCode => Object.hash(enabled, hour, minute, dueWarning, configured);
}

/// Hour of the "vence hoy" warning: late enough to have trained, early enough
/// to still do it or register it before 23:59.
const dueWarningHour = 20;

/// iOS keeps at most 64 pending notifications; stay well below.
const maxReminders = 20;

/// Fixed ids of the "new plan" reminders. Workout ids map below 1e9, so
/// these never collide with them.
const nextPlanReminderId = 1999999990;
const nextPlanFollowUpId = 1999999991;
const nextPlanPayload = 'plan:next';

/// One notification to schedule. [at] is a wall-clock time in the user's
/// timezone (the same one the backend uses for `scheduledDate`/`expiresAt`).
class PlannedReminder {
  const PlannedReminder({required this.id, required this.at, required this.title, required this.body, required this.payload});
  final int id;
  final DateTime at;
  final String title, body, payload;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder && other.id == id && other.at == at && other.title == title &&
      other.body == body && other.payload == payload;

  @override
  int get hashCode => Object.hash(id, at, title, body, payload);

  @override
  String toString() => 'PlannedReminder($id, $at, $title)';
}

/// Reminders for the open workouts of [plan] that are still ahead of [now],
/// plus the "new plan" reminders for the week after it.
///
/// Only SCHEDULED/IN_PROGRESS workouts that are not safety-blocked get
/// reminders: completed, partial, skipped or replaced ones never notify.
/// Rescheduling on every plan refresh removes reminders of workouts that the
/// user has already registered.
///
/// The app only knows the plan it last downloaded: the backend generates the
/// next one on Monday while the app may be closed. So the Monday after
/// [plan] ends (and Wednesday, if the app was still not opened) a reminder
/// invites the user to open Kora; opening it downloads the new plan and
/// replaces every reminder, these two included.
List<PlannedReminder> planReminders(Json? plan, {required DateTime now, required ReminderSettings settings}) {
  if (plan == null || !settings.enabled) return const [];
  final reminders = <PlannedReminder>[];
  final workouts = jsonRows(plan['workouts'])
    ..sort((a, b) => '${a['scheduledDate']}'.compareTo('${b['scheduledDate']}'));
  for (final workout in workouts) {
    if (!isOpenWorkout(workout) || isSafetyBlocked(workout)) continue;
    final day = DateTime.tryParse('${workout['scheduledDate']}');
    final id = (workout['plannedWorkoutId'] as num?)?.toInt();
    if (day == null || id == null) continue;
    final name = '${workout['workoutName'] ?? 'tu entrenamiento'}';
    final focus = workoutFocusLabels['${workout['focusCode']}'];
    final minutes = workout['expectedDurationMinutes'];
    final details = [if (minutes != null) '$minutes min', ?focus].join(' · ');
    final baseId = (id % 500000000) * 2; // Android notification ids are 32-bit.

    final dayAt = DateTime(day.year, day.month, day.day, settings.hour, settings.minute);
    if (dayAt.isAfter(now)) {
      reminders.add(PlannedReminder(
        id: baseId,
        at: dayAt,
        title: 'Hoy toca: $name',
        body: details.isEmpty ? 'Ábrelo en Kora para empezar.' : '$details. Ábrelo en Kora para empezar.',
        payload: 'workout:$id',
      ));
    }

    final dueAt = DateTime(day.year, day.month, day.day, dueWarningHour);
    final reminderBeforeDue = settings.hour * 60 + settings.minute < dueWarningHour * 60;
    if (settings.dueWarning && reminderBeforeDue && dueAt.isAfter(now)) {
      reminders.add(PlannedReminder(
        id: baseId + 1,
        at: dueAt,
        title: 'Tu entrenamiento vence hoy',
        body: '«$name» vence a las 23:59. Si ya lo hiciste, regístralo en Kora.',
        payload: 'workout:$id',
      ));
    }
  }
  reminders.sort((a, b) => a.at.compareTo(b.at));
  final next = nextPlanReminders(plan, now: now, settings: settings);
  // The chain to the next week must survive the cap.
  return [...reminders.take(maxReminders - next.length), ...next];
}

/// "Your new plan is ready" on the Monday after [plan] ends, and a follow-up
/// on Wednesday, both at the user's reminder time.
List<PlannedReminder> nextPlanReminders(Json plan, {required DateTime now, required ReminderSettings settings}) {
  final end = DateTime.tryParse('${plan['weekEndDate']}');
  if (end == null) return const [];
  final monday = DateTime(end.year, end.month, end.day + 1);
  return [
    PlannedReminder(
      id: nextPlanReminderId,
      at: DateTime(monday.year, monday.month, monday.day, settings.hour, settings.minute),
      title: 'Tu plan de esta semana está listo',
      body: 'Abre Kora para ver tus entrenamientos y activar sus recordatorios.',
      payload: nextPlanPayload,
    ),
    PlannedReminder(
      id: nextPlanFollowUpId,
      at: DateTime(monday.year, monday.month, monday.day + 2, settings.hour, settings.minute),
      title: 'Aún no revisas tu plan de esta semana',
      body: 'Tus entrenamientos te esperan en Kora. Ábrela para verlos.',
      payload: nextPlanPayload,
    ),
  ].where((r) => r.at.isAfter(now)).toList();
}
