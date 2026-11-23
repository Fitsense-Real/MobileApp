import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens Android's notification settings for Kora (MainActivity.kt). After
/// the permission was denied, that is the only place to turn it back on.
class NotificationSettingsLauncher {
  const NotificationSettingsLauncher();
  static const channel = MethodChannel('pe.fit.kora/settings');

  Future<bool> open() async {
    try {
      return await channel.invokeMethod<bool>('openNotificationSettings') ?? false;
    } catch (_) {
      return false;
    }
  }
}

final notificationSettingsLauncherProvider = Provider((ref) => const NotificationSettingsLauncher());
