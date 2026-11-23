import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../domain/push_event.dart';

/// What the app needs from the push provider. Abstract so tests, web and
/// builds without Firebase configuration never touch the native plugin.
abstract class PushMessaging {
  /// False when push is not available (no Firebase configuration, web): the
  /// rest of the app keeps working.
  Future<bool> start();

  /// Registers this installation with FCM. The Firebase Installation ID (FID)
  /// arrives through [onRegistered], on the first registration and on every
  /// later call (FCM re-delivers the current one).
  Future<void> register();

  /// Unregisters this installation from FCM: no message reaches it until the
  /// next [register]. The FID arrives through [onUnregistered].
  Future<void> unregister();

  Stream<String> get onRegistered;
  Stream<String> get onUnregistered;

  /// Messages received while the app is in the foreground (FCM does not show
  /// them by itself).
  Stream<PushEvent> get onForegroundMessage;

  /// The user tapped a notification while the app was in the background.
  Stream<PushEvent> get onOpened;

  /// The notification that launched the app from terminated, if any.
  Future<PushEvent?> initialEvent();
}

/// Firebase Cloud Messaging (project kora-fitpe), Android only.
///
/// Registration by **Firebase Installation ID**, as the backend requires
/// (Backend PR #82): `register()`, `onRegistered`, `unregister()` and
/// `onUnregistered` of firebase_messaging 17. The registration-token APIs
/// (`getToken`, `onTokenRefresh`, `deleteToken`) are never used; with
/// `firebase_messaging_installation_id_enabled` in the manifest the native SDK
/// disables them anyway.
class FirebasePushMessaging implements PushMessaging {
  bool _ready = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> start() async {
    if (_ready) return true;
    if (!supported) return false;
    try {
      // On Android the configuration comes from google-services.json (the
      // Google Services Gradle plugin turns it into resources).
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _ready = true;
      return true;
    } catch (e) {
      debugPrint('Notificaciones push no disponibles: $e');
      return false;
    }
  }

  PushEvent _event(RemoteMessage m) => PushEvent.fromMessage(m.data, title: m.notification?.title, body: m.notification?.body);

  @override
  Future<void> register() async {
    if (_ready) await FirebaseMessaging.instance.register();
  }

  @override
  Future<void> unregister() async {
    if (_ready) await FirebaseMessaging.instance.unregister();
  }

  @override
  Stream<String> get onRegistered => _ready ? FirebaseMessaging.instance.onRegistered : const Stream.empty();

  @override
  Stream<String> get onUnregistered => _ready ? FirebaseMessaging.instance.onUnregistered : const Stream.empty();

  @override
  Stream<PushEvent> get onForegroundMessage => _ready ? FirebaseMessaging.onMessage.map(_event) : const Stream.empty();

  @override
  Stream<PushEvent> get onOpened => _ready ? FirebaseMessaging.onMessageOpenedApp.map(_event) : const Stream.empty();

  @override
  Future<PushEvent?> initialEvent() async {
    if (!_ready) return null;
    final m = await FirebaseMessaging.instance.getInitialMessage();
    return m == null ? null : _event(m);
  }
}

/// Runs in a background isolate when a message arrives with the app in the
/// background or terminated. Messages with a `notification` part are shown by
/// Android itself (channel from the message, icon from the manifest).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}
