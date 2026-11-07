import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../domain/reminder_planner.dart';

/// Schedules device notifications. Abstract so tests and unsupported
/// platforms (web, desktop) never touch the native plugin.
abstract class ReminderScheduler {
  /// Asks the OS for permission (Android 13+, iOS). True when granted.
  Future<bool> requestPermission();

  /// Replaces every pending reminder with [reminders], interpreting their
  /// wall-clock times in [timezone] (IANA, e.g. America/Lima).
  Future<void> replaceAll(List<PlannedReminder> reminders, {String? timezone});

  Future<void> cancelAll();

  /// Current wall-clock time in [timezone].
  DateTime nowIn(String? timezone);
}

/// Called with the payload (`workout:<id>`) when the user taps a reminder.
typedef ReminderTapHandler = void Function(String? payload);

class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin, this.onTap})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final ReminderTapHandler? onTap;
  bool _timezonesLoaded = false;
  Future<bool>? _initialized;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'workout_reminders',
      'Recordatorios de entrenamiento',
      channelDescription: 'Avisos del entrenamiento del día y de los que vencen hoy.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  void _loadTimezones() {
    if (_timezonesLoaded) return;
    tzdata.initializeTimeZones();
    _timezonesLoaded = true;
  }

  tz.Location _location(String? timezone) {
    _loadTimezones();
    try {
      return tz.getLocation(timezone ?? 'America/Lima');
    } catch (_) {
      return tz.getLocation('America/Lima');
    }
  }

  Future<bool> _ensureInitialized() => _initialized ??= () async {
    if (!_supported) return false;
    try {
      _loadTimezones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Permission is requested explicitly, never at plugin start.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => onTap?.call(response.payload),
      );
      return true;
    } catch (e) {
      debugPrint('Recordatorios no disponibles: $e');
      return false;
    }
  }();

  @override
  DateTime nowIn(String? timezone) {
    final now = tz.TZDateTime.now(_location(timezone));
    return DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _ensureInitialized()) return false;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await _plugin
                .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                ?.requestNotificationsPermission() ??
            false;
      }
      return await _plugin
              .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders, {String? timezone}) async {
    if (!await _ensureInitialized()) return;
    try {
      await _plugin.cancelAll();
      final location = _location(timezone);
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          r.id,
          r.title,
          r.body,
          tz.TZDateTime(location, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute),
          _details,
          // Inexact: no SCHEDULE_EXACT_ALARM permission; a few minutes of
          // slack is fine for a training reminder.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: r.payload,
        );
      }
    } catch (e) {
      debugPrint('No se pudieron programar los recordatorios: $e');
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!await _ensureInitialized()) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }
}
