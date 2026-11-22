import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/push/data/push_device_repository.dart';
import 'package:fitsense_mobile/features/push/data/push_messaging.dart';
import 'package:fitsense_mobile/features/push/data/push_notifier.dart';
import 'package:fitsense_mobile/features/push/domain/push_event.dart';
import 'package:fitsense_mobile/features/push/presentation/push_controller.dart';
import 'package:fitsense_mobile/features/reminders/presentation/reminders_controller.dart';

// Everything simulated: no Firebase, no network.

class FakeMessaging implements PushMessaging {
  FakeMessaging({this.available = true, this.currentToken = 'tok-1', this.initial});
  final bool available;
  String? currentToken;
  final PushEvent? initial;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushEvent>.broadcast();
  final opened = StreamController<PushEvent>.broadcast();
  int starts = 0, deletes = 0;
  @override
  Future<bool> start() async { starts++; return available; }
  @override
  Future<String?> token() async => available ? currentToken : null;
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Stream<PushEvent> get onForegroundMessage => foreground.stream;
  @override
  Stream<PushEvent> get onOpened => opened.stream;
  @override
  Future<PushEvent?> initialEvent() async => initial;
  @override
  Future<void> deleteToken() async { deletes++; currentToken = null; }
}

class FakeDevices extends PushDeviceRepository {
  FakeDevices([this.answer = PushRegistration.registered]) : super(Dio());
  PushRegistration answer;
  final registered = <String>[], removed = <String>[];
  @override
  Future<PushRegistration> register({required String token, required String platform, String? appVersion, String? locale}) async {
    expect(platform, 'ANDROID');
    registered.add(token);
    return answer;
  }
  @override
  Future<PushRegistration> unregister(String token) async { removed.add(token); return PushRegistration.removed; }
}

class FakeNotifier implements PushNotifier {
  final shown = <PushEvent>[];
  int prepared = 0;
  @override
  Future<void> prepare() async => prepared++;
  @override
  Future<void> show(PushEvent event) async => shown.add(event);
}

/// Answers every request with [status] and records it.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.status);
  final int status;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode({'status': status}), status, headers: {Headers.contentTypeHeader: ['application/json']});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  group('push events (PLAN_GENERATED, PLAN_ADAPTED, WEEKLY_PLAN_READY, ACCOUNT_NOTICE)', () {
    test('each type maps to its screen and says whether the plan changed', () {
      final cases = {
        'PLAN_GENERATED': ('/account-setup', true),
        'PLAN_ADAPTED': ('/dashboard?tab=2', true),
        'WEEKLY_PLAN_READY': ('/dashboard?tab=0', true),
        'ACCOUNT_NOTICE': ('/dashboard?tab=3', false),
      };
      cases.forEach((type, expected) {
        final event = PushEvent.fromMessage({'type': type, 'planId': '42'}, title: 'Kora', body: 'Texto');
        expect(event.route, expected.$1, reason: type);
        expect(event.changesPlan, expected.$2, reason: type);
        expect(event.planId, 42);
        expect(event.payload, 'route:${expected.$1}');
      });
    });

    test('unknown or missing type: opens Inicio and does not reload the plan', () {
      for (final data in [<String, dynamic>{'type': 'OTRO'}, <String, dynamic>{}]) {
        final event = PushEvent.fromMessage(data);
        expect(event.type, PushEventType.unknown);
        expect(event.route, '/dashboard');
        expect(event.changesPlan, isFalse);
      }
      expect(PushEvent.fromMessage({'event': 'plan_adapted'}).type, PushEventType.planAdapted, reason: 'case-insensitive, also «event»');
    });

    test('a push shown with the app open is routed by the same tap handler as the reminders', () {
      expect(reminderRoute('route:/dashboard?tab=2'), '/dashboard?tab=2');
      expect(reminderRoute('workout:9'), '/dashboard?tab=1');
      expect(reminderRoute('route:https://otra.web'), '/dashboard', reason: 'only in-app routes');
      expect(reminderRoute(null), '/dashboard');
    });
  });

  group('push controller', () {
    late FakeMessaging messaging;
    late FakeDevices devices;
    late FakeNotifier notifier;
    late int planChanges;
    late List<String> opened;
    PushController build({FakeMessaging? m}) {
      messaging = m ?? FakeMessaging();
      devices = FakeDevices();
      notifier = FakeNotifier();
      planChanges = 0;
      opened = [];
      return PushController(messaging: messaging, devices: devices, notifier: notifier, onPlanChanged: () => planChanges++, open: opened.add);
    }

    test('at login the FCM registration token is sent once; a rotated token is sent again', () async {
      final c = build();
      await c.onUser(7);
      await c.onUser(7);
      expect(devices.registered, ['tok-1'], reason: 'no duplicate registrations');
      expect(notifier.prepared, 1, reason: 'channel created once');
      messaging.refresh.add('tok-2');
      await Future<void>.delayed(Duration.zero);
      expect(devices.registered, ['tok-1', 'tok-2']);
      c.dispose();
    });

    test('signed out: nothing is registered', () async {
      final c = build();
      await c.onUser(null);
      expect(messaging.starts, 0);
      expect(devices.registered, isEmpty);
    });

    test('backend without the endpoint yet: no crash, it tries again at the next login', () async {
      final c = build();
      devices.answer = PushRegistration.backendNotReady;
      await c.onUser(7);
      expect(c.lastRegistration, PushRegistration.backendNotReady);
      devices.answer = PushRegistration.registered;
      await c.onUser(7);
      expect(devices.registered, ['tok-1', 'tok-1']);
      expect(c.lastRegistration, PushRegistration.registered);
      c.dispose();
    });

    test('a message with the app open is shown and a plan event reloads the plan', () async {
      final c = build();
      await c.onUser(7);
      messaging.foreground.add(PushEvent.fromMessage({'type': 'WEEKLY_PLAN_READY'}, title: 'Tu semana está lista', body: 'Mira tu plan'));
      messaging.foreground.add(PushEvent.fromMessage({'type': 'ACCOUNT_NOTICE'}, title: 'Aviso', body: 'Revisa tu cuenta'));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.shown.map((e) => e.type), [PushEventType.weeklyPlanReady, PushEventType.accountNotice]);
      expect(planChanges, 1);
      expect(opened, isEmpty, reason: 'showing is not opening');
      c.dispose();
    });

    test('tapping a notification (background or cold start) opens its screen', () async {
      final c = build(m: FakeMessaging(initial: PushEvent.fromMessage({'type': 'PLAN_GENERATED'})));
      await c.onUser(7);
      expect(opened, ['/account-setup'], reason: 'notification that launched the app');
      messaging.opened.add(PushEvent.fromMessage({'type': 'PLAN_ADAPTED'}));
      await Future<void>.delayed(Duration.zero);
      expect(opened, ['/account-setup', '/dashboard?tab=2']);
      expect(planChanges, 2);
      c.dispose();
    });

    test('before logout the token is unregistered and deleted; a later rotation is not sent', () async {
      final c = build();
      await c.onUser(7);
      await c.beforeLogout();
      expect(devices.removed, ['tok-1']);
      expect(messaging.deletes, 1);
      messaging.refresh.add('tok-3');
      await Future<void>.delayed(Duration.zero);
      expect(devices.registered, ['tok-1'], reason: 'no account is signed in');
      c.dispose();
    });

    test('push unavailable (no google-services.json, web, no Play services): the app keeps working', () async {
      final c = build(m: FakeMessaging(available: false));
      await c.onUser(7);
      await c.beforeLogout();
      expect(devices.registered, isEmpty);
      expect(devices.removed, isEmpty);
      expect(notifier.prepared, 0);
    });
  });

  group('device registration (proposed contract)', () {
    test('PUT /users/me/push-devices with the token and platform', () async {
      final adapter = RecordingAdapter(200);
      final repo = PushDeviceRepository(Dio(BaseOptions(baseUrl: 'https://api.ejemplo.test/api/v1'))..httpClientAdapter = adapter);
      expect(await repo.register(token: 'abc:123', platform: 'ANDROID', appVersion: '1.0.0+1'), PushRegistration.registered);
      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path, '/users/me/push-devices');
      expect(adapter.requests.single.data, {'token': 'abc:123', 'platform': 'ANDROID', 'appVersion': '1.0.0+1'});
    });

    test('DELETE uses the encoded token; 404/405/501 mean the backend does not have it yet', () async {
      for (final status in [404, 405, 501]) {
        final adapter = RecordingAdapter(status);
        final repo = PushDeviceRepository(Dio(BaseOptions(baseUrl: 'https://api.ejemplo.test/api/v1'))..httpClientAdapter = adapter);
        expect(await repo.unregister('abc:1/2'), PushRegistration.backendNotReady, reason: '$status');
        expect(adapter.requests.single.path, '/users/me/push-devices/abc%3A1%2F2');
      }
      final repo = PushDeviceRepository(Dio(BaseOptions(baseUrl: 'https://api.ejemplo.test/api/v1'))..httpClientAdapter = RecordingAdapter(500));
      expect(await repo.register(token: 't', platform: 'ANDROID'), PushRegistration.failed);
    });
  });
}
