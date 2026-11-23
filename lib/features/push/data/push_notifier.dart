import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../domain/push_event.dart';

/// Shows a push message while Kora is open (FCM only displays it by itself
/// when the app is in the background). Same plugin, icon and tap routing as
/// the workout reminders, which it does not touch.
abstract class PushNotifier {
  /// Creates the Android channels of the backend contract (`kora_planes`,
  /// `kora_cuenta`), which background messages also use.
  Future<void> prepare();

  /// Whether Android lets Kora show notifications (POST_NOTIFICATIONS on
  /// Android 13+, the app's notification switch before that).
  Future<bool> permitted();

  /// Shows Android's permission dialog (Android 13+). True when granted;
  /// before Android 13 it reflects the app's notification switch.
  Future<bool> requestPermission();

  Future<void> show(PushEvent event);
}

class LocalPushNotifier implements PushNotifier {
  LocalPushNotifier({FlutterLocalNotificationsPlugin? plugin, this.onTap}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String? payload)? onTap;
  Future<bool>? _initialized;

  /// The plan channel is also `default_notification_channel_id` in
  /// android/app/src/main/AndroidManifest.xml.
  static const channels = [
    AndroidNotificationChannel(PushChannels.plans, 'Tu plan',
        description: 'Tu plan listo, los ajustes y la nueva semana.'),
    AndroidNotificationChannel(PushChannels.account, 'Avisos de tu cuenta',
        description: 'Avisos de seguridad de tu cuenta de Kora.', importance: Importance.high),
  ];

  /// Channel created by earlier test builds of this feature; removed so the
  /// phone's settings only list the channels in use.
  static const legacyChannel = 'kora_avisos';

  /// Stable ids, one per grouping: a newer notice replaces the previous one
  /// of its kind, like the backend's collapseKey/tag.
  static int notificationId(PushEvent event) => event.isAccountNotice ? 900000002 : 900000001;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

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
      for (final channel in channels) {
        await _android?.createNotificationChannel(channel);
      }
      await _android?.deleteNotificationChannel(channelId: legacyChannel);
    } catch (_) {}
  }

  @override
  Future<bool> permitted() async {
    if (!await _ensureInitialized()) return false;
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!await _ensureInitialized()) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> show(PushEvent event) async {
    if (event.title == null && event.body == null) return; // data-only: nothing to show
    if (!await _ensureInitialized()) return;
    final channel = channels.firstWhere((c) => c.id == event.channelId);
    try {
      await _plugin.show(
        id: notificationId(event),
        title: event.title,
        body: event.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(channel.id, channel.name,
              channelDescription: channel.description, importance: channel.importance, tag: event.tag),
        ),
        payload: event.payload,
      );
    } catch (e) {
      debugPrint('No se pudo mostrar el aviso: $e');
    }
  }
}
