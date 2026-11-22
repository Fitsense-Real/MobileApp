import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/reminders/data/reminder_scheduler.dart';
import 'package:fitsense_mobile/features/reminders/domain/reminder_planner.dart';

/// What the app sends to the native Android plugin when it schedules a
/// reminder. Guards the flutter_local_notifications upgrade (19 → 23, named
/// parameters since 20): same channel, icon, time zone, inexact mode, payload.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'requestNotificationsPermission' => true,
        _ => null,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('initialises once with the app icon and asks for the Android 13+ permission', () async {
    final scheduler = LocalNotificationScheduler();
    expect(await scheduler.requestPermission(), isTrue);
    await scheduler.cancelAll();
    expect(calls.map((c) => c.method), ['initialize', 'requestNotificationsPermission', 'cancelAll']);
    expect((calls.first.arguments as Map)['defaultIcon'], '@mipmap/ic_launcher');
  });

  test('schedules each reminder at its wall-clock time in the user time zone, inexact, with its payload', () async {
    final scheduler = LocalNotificationScheduler();
    await scheduler.replaceAll([
      PlannedReminder(id: 101, at: DateTime(2030, 3, 4, 7, 30), title: 'Hoy toca entrenar', body: 'Fuerza · 45 min', payload: 'workout:9'),
      PlannedReminder(id: 102, at: DateTime(2030, 3, 6, 19, 0), title: 'Te espera tu rutina', body: 'Cardio · 30 min', payload: 'workout:10'),
    ], timezone: 'America/Lima');

    expect(calls.map((c) => c.method), ['initialize', 'cancelAll', 'zonedSchedule', 'zonedSchedule']);
    final first = calls[2].arguments as Map;
    expect(first['id'], 101);
    expect(first['title'], 'Hoy toca entrenar');
    expect(first['body'], 'Fuerza · 45 min');
    expect(first['payload'], 'workout:9');
    expect(first['timeZoneName'], 'America/Lima');
    expect(first['scheduledDateTime'], '2030-03-04T07:30:00');
    final android = first['platformSpecifics'] as Map;
    expect(android['channelId'], 'workout_reminders');
    expect(android['channelName'], 'Recordatorios de entrenamiento');
    expect(android['scheduleMode'], 'inexactAllowWhileIdle', reason: 'no SCHEDULE_EXACT_ALARM permission needed');
    expect((calls[3].arguments as Map)['scheduledDateTime'], '2030-03-06T19:00:00');
  });

  test('an unknown time zone falls back to America/Lima instead of failing', () async {
    final scheduler = LocalNotificationScheduler();
    await scheduler.replaceAll([
      PlannedReminder(id: 1, at: DateTime(2030, 1, 2, 8), title: 't', body: 'b', payload: 'workout:1'),
    ], timezone: 'Marte/Olympus');
    expect((calls.last.arguments as Map)['timeZoneName'], 'America/Lima');
  });
}
