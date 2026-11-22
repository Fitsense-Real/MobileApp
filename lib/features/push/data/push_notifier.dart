import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../domain/push_event.dart';

/// Shows a push message while Kora is open (FCM only displays it by itself
/// when the app is in the background). Same plugin, icon and tap routing as
/// the workout reminders.
abstract class PushNotifier {
  /// Creates the Android channel that background messages also use
  /// (`default_notification_channel_id` in the manifest).
  Future<void> prepare();
  Future<void> show(PushEvent event);
}

class LocalPushNotifier implements PushNotifier {
  LocalPushNotifier({FlutterLocalNotificationsPlugin? plugin, this.onTap}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String? payload)? onTap;
  Future<bool>? _initialized;

  /// Must match android/app/src/main/AndroidManifest.xml.
  static const channelId = 'kora_avisos';
  static const channelName = 'Avisos de Kora';
  static const channelDescription = 'Tu plan listo, ajustes de la semana y avisos de tu cuenta.';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(channelId, channelName, channelDescription: channelDescription,
        importance: Importance.defaultImportance, priority: Priority.defaultPriority),
  );

  Future<bool> _ensureInitialized() => _initialized ??= () async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_kora')),
        onDidReceiveNotificationResponse: (response) => onTap?.call(response.payload),
      );
      return true;
    } catch (e) {
      debugPrint('Avisos no disponibles: $e');
      return false;
    }
  }();

  @override
  Future<void> prepare() async {
    if (!await _ensureInitialized()) return;
    try {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
        const AndroidNotificationChannel(channelId, channelName, description: channelDescription),
      );
    } catch (_) {}
  }

  @override
  Future<void> show(PushEvent event) async {
    if (event.title == null && event.body == null) return; // data-only: nothing to show
    if (!await _ensureInitialized()) return;
    try {
      await _plugin.show(
        // Above the reminder ids, unique enough for a few messages a week.
        id: 900000000 + DateTime.now().millisecondsSinceEpoch % 100000000,
        title: event.title,
        body: event.body,
        notificationDetails: _details,
        payload: event.payload,
      );
    } catch (e) {
      debugPrint('No se pudo mostrar el aviso: $e');
    }
  }
}
