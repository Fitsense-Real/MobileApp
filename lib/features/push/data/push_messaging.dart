import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../domain/push_event.dart';

/// What the app needs from the push provider. Abstract so tests, web and
/// builds without Firebase configuration never touch the native plugin.
abstract class PushMessaging {
  /// False when push is not available (no google-services.json, web, no
  /// Google Play services): the rest of the app keeps working.
  Future<bool> start();

  /// FCM registration token of this installation (not the Installation ID).
  Future<String?> token();
  Stream<String> get onTokenRefresh;

  /// Messages received while the app is in the foreground (FCM does not show
  /// them by itself).
  Stream<PushEvent> get onForegroundMessage;

  /// The user tapped a notification while the app was in the background.
  Stream<PushEvent> get onOpened;

  /// The notification that launched the app from terminated, if any.
  Future<PushEvent?> initialEvent();

  /// After logout or account deletion: the old token stops working.
  Future<void> deleteToken();
}

/// Firebase Cloud Messaging (project kora-fitpe). Android only: the app is
/// published for Android and the web build is used for testing.
///
/// Tokens: Kora sends the backend the FCM **registration token**
/// (`getToken`/`onTokenRefresh`), the target of FCM HTTP v1 and of the
/// Firebase Admin SDK used from Spring Boot. firebase_messaging 17 deprecates
/// them in favour of `register()`/`onRegistered`, but those return the
/// Firebase Installation ID for the new direct-send mode, which is a
/// different identifier and not what the backend contract uses. Hence the
/// three targeted `deprecated_member_use` ignores below.
class FirebasePushMessaging implements PushMessaging {
  bool _ready = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> start() async {
    if (_ready) return true;
    if (!supported) return false;
    try {
      // On Android the configuration comes from google-services.json (the
      // Google Services Gradle plugin turns it into resources). Without that
      // file this throws and push simply stays off.
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      // Notification permission (Android 13+) is asked once by Kora's
      // reminders flow; FCM uses the same POST_NOTIFICATIONS permission.
      _ready = true;
      return true;
    } catch (e) {
      debugPrint('Notificaciones push no disponibles: $e');
      return false;
    }
  }

  PushEvent _event(RemoteMessage m) => PushEvent.fromMessage(m.data, title: m.notification?.title, body: m.notification?.body);

  @override
  // ignore: deprecated_member_use (registration token on purpose, see the class doc)
  Future<String?> token() async => _ready ? FirebaseMessaging.instance.getToken() : null;

  @override
  // ignore: deprecated_member_use (registration token on purpose, see the class doc)
  Stream<String> get onTokenRefresh => _ready ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

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

  @override
  Future<void> deleteToken() async {
    // ignore: deprecated_member_use (invalidates the registration token, see the class doc)
    if (_ready) await FirebaseMessaging.instance.deleteToken();
  }
}

/// Runs in a background isolate when a message arrives with the app in the
/// background or terminated. Messages with a `notification` part are shown by
/// Android itself (icon and channel from the manifest); nothing else to do.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
}
