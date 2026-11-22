import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../plans/data/plan_repository.dart';
import '../../reminders/presentation/reminders_controller.dart';
import '../../welcome/presentation/first_plan_generation_controller.dart';
import '../data/push_device_repository.dart';
import '../data/push_messaging.dart';
import '../data/push_notifier.dart';
import '../domain/push_event.dart';

/// Push notifications of the signed-in user:
/// - registers this device's FCM registration token with the backend at login
///   and whenever FCM rotates it;
/// - shows messages received with the app open and refreshes the plan when
///   the backend says it changed;
/// - opens the right screen when a notification is tapped;
/// - unregisters the token and deletes it before logout, so a shared phone
///   never receives the previous account's messages.
class PushController {
  PushController({required this.messaging, required this.devices, required this.notifier, required this.onPlanChanged, required this.open});

  final PushMessaging messaging;
  final PushDeviceRepository devices;
  final PushNotifier notifier;
  final void Function() onPlanChanged;
  final void Function(String route) open;

  final _subscriptions = <StreamSubscription<Object?>>[];
  Future<bool>? _started;
  int? _userId;
  String? _registeredFor;

  /// Last result, for diagnostics and tests.
  PushRegistration? lastRegistration;

  Future<bool> _start() => _started ??= () async {
    if (!await messaging.start()) return false;
    await notifier.prepare();
    _subscriptions
      ..add(messaging.onTokenRefresh.listen((token) => _register(token)))
      ..add(messaging.onForegroundMessage.listen(_foreground))
      ..add(messaging.onOpened.listen(_opened));
    final initial = await messaging.initialEvent();
    if (initial != null) _opened(initial);
    return true;
  }();

  /// Called with the signed-in user's id (null when signed out).
  Future<void> onUser(int? userId) async {
    _userId = userId;
    if (userId == null) return;
    if (!await _start()) return;
    final token = await messaging.token();
    if (token != null) await _register(token);
  }

  Future<void> _register(String token) async {
    final userId = _userId;
    if (userId == null) return;
    final key = '$userId:$token';
    if (_registeredFor == key && lastRegistration == PushRegistration.registered) return;
    lastRegistration = await devices.register(token: token, platform: 'ANDROID');
    if (lastRegistration == PushRegistration.registered) _registeredFor = key;
    // Debug builds only: the full token, to send a test message from the
    // Firebase console (docs/push/). Never printed in release.
    if (kDebugMode) debugPrint('FCM token (${lastRegistration!.name}): $token');
  }

  void _foreground(PushEvent event) {
    if (event.changesPlan) onPlanChanged();
    notifier.show(event);
  }

  void _opened(PushEvent event) {
    if (event.changesPlan) onPlanChanged();
    open(event.route);
  }

  /// Before the session ends (logout, expired session, deleted account).
  Future<void> beforeLogout() async {
    _userId = null;
    _registeredFor = null;
    final token = await messaging.token();
    if (token == null) return;
    lastRegistration = await devices.unregister(token);
    try {
      await messaging.deleteToken();
    } catch (_) {}
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
  }
}

/// Overridden in tests; the real one talks to Firebase (Android only).
final pushMessagingProvider = Provider<PushMessaging>((ref) => FirebasePushMessaging());

final pushNotifierProvider = Provider<PushNotifier>((ref) => LocalPushNotifier(onTap: (payload) => pushRouter?.call(reminderRoute(payload))));

/// Navigation used when a notification is tapped; set by the app.
void Function(String route)? pushRouter;

final pushControllerProvider = Provider<PushController>((ref) {
  final controller = PushController(
    messaging: ref.read(pushMessagingProvider),
    devices: ref.read(pushDeviceRepositoryProvider),
    notifier: ref.read(pushNotifierProvider),
    onPlanChanged: () {
      ref.invalidate(currentPlanProvider);
      final generation = ref.read(firstPlanGenerationProvider);
      if (generation.isWaiting) ref.read(firstPlanGenerationProvider.notifier).refresh();
    },
    open: (route) => pushRouter?.call(route),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
