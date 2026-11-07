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

/// Reminders for the open workouts of [plan] that are still ahead of [now].
///
/// Only SCHEDULED/IN_PROGRESS workouts that are not safety-blocked get
/// reminders: completed, partial, skipped or replaced ones never notify.
/// Rescheduling on every plan refresh removes reminders of workouts that the
/// user has already registered.
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
  return reminders.take(maxReminders).toList();
}
