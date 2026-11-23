import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/network/auth_interceptor.dart';
import 'package:fitsense_mobile/features/push/data/push_device_repository.dart';
import 'package:fitsense_mobile/features/push/data/push_messaging.dart';
import 'package:fitsense_mobile/features/push/data/push_notifier.dart';
import 'package:fitsense_mobile/features/push/domain/push_event.dart';
import 'package:fitsense_mobile/features/push/presentation/push_controller.dart';
import 'package:fitsense_mobile/features/reminders/presentation/reminders_controller.dart';

// Everything simulated: no Firebase, no network. The HTTP shapes come from
// Fitsense-Real/Backend PR #82, docs/FitSense/notificaciones_push/EJEMPLOS_REALES_HTTP.md.

const fid = 'cR_9l0aBcD3fGh1jK2lM4n'; // the FID of the backend examples
const fid2 = 'dQ_8k1bCdE4gHi2kL3mN5o';
const fcmToken = 'dXy7:APA91bHPRgkF3JUikC4ENAHEeMrd41Zxv3hVZjC9KtT8OvPVGJ-hQMRKRrZuJAEcl7B338qju59zJMjw2DELjzEvxwYv7hH5Ynpc1ODQ0aT4U4OFEeco8ohsN5PjL1iC2dNtk2BAokeMCg2ZXKqpc8FXKmhX94kIxQ';

Map<String, dynamic> backendData(String type, {String? eventId, String? notice}) => {
  'schemaVersion': '1',
  'eventType': type,
  'eventId': eventId ?? '6f1c2d4e-0000-4000-8000-00000000000${type.length % 10}',
  if (type != 'ACCOUNT_NOTICE') 'resourceType': 'PLAN',
  if (type != 'ACCOUNT_NOTICE') 'resourceId': '42',
  'targetScreen': type == 'ACCOUNT_NOTICE' ? 'ACCOUNT_SECURITY' : 'WEEKLY_PLAN',
  'createdAt': '2026-11-22T14:05:00Z',
  'noticeCode': ?notice,
};

Future<void> pump() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// FCM as the native SDK behaves: register() (re)delivers the current FID
/// through onRegistered; unregister() delivers it through onUnregistered.
class FakeMessaging implements PushMessaging {
  FakeMessaging({this.available = true, this.installationId = fid, this.initial, this.registerError, this.log});
  final bool available;
  String installationId;
  final PushEvent? initial;
  Object? registerError;
  final List<String>? log;
  final registered = StreamController<String>.broadcast();
  final unregistered = StreamController<String>.broadcast();
  final foreground = StreamController<PushEvent>.broadcast();
  final opened = StreamController<PushEvent>.broadcast();
  int starts = 0, registers = 0, unregisters = 0;

  @override
  Future<bool> start() async {
    starts++;
    return available;
  }

  @override
  Future<void> register() async {
    registers++;
    if (registerError != null) throw registerError!;
    scheduleMicrotask(() => registered.add(installationId));
  }

  @override
  Future<void> unregister() async {
    unregisters++;
    log?.add('fcm unregister');
    if (deferUnregistered) {
      pendingUnregistered.add(installationId);
    } else {
      scheduleMicrotask(() => unregistered.add(installationId));
    }
  }

  /// Native confirmations delivered later (see [deferUnregistered]).
  bool deferUnregistered = false;
  final pendingUnregistered = <String>[];

  @override
  Stream<String> get onRegistered => registered.stream;
  @override
  Stream<String> get onUnregistered => unregistered.stream;
  @override
  Stream<PushEvent> get onForegroundMessage => foreground.stream;
  @override
  Stream<PushEvent> get onOpened => opened.stream;
  @override
  Future<PushEvent?> initialEvent() async => initial;
}

class FakeDevices extends PushDeviceRepository {
  FakeDevices({this.log}) : super(Dio());
  final List<String>? log;
  PushDeviceResult answer = const PushDeviceResult(PushDeviceStatus.registered);
  final registered = <String>[], removed = <String>[];

  @override
  Future<PushDeviceResult> register({required String installationId, String? appVersion}) async {
    registered.add(installationId);
    log?.add('PUT $installationId');
    return answer;
  }

  @override
  Future<PushDeviceResult> unregister(String installationId) async {
    removed.add(installationId);
    log?.add('DELETE $installationId');
    return const PushDeviceResult(PushDeviceStatus.removed);
  }
}

class FakeNotifier implements PushNotifier {
  FakeNotifier({this.allowed = true});
  bool allowed;
  final shown = <PushEvent>[];
  int prepared = 0;
  @override
  Future<void> prepare() async => prepared++;
  @override
  Future<bool> permitted() async => allowed;
  @override
  Future<void> show(PushEvent event) async => shown.add(event);
}

class MemoryStore implements PushInstallationStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String installationId) async => value = installationId;
  @override
  Future<void> clear() async => value = null;
}

/// Answers like the backend and records what the app sent.
class BackendAdapter implements HttpClientAdapter {
  BackendAdapter(this.answers);
  final List<(int, Object?)> answers;
  final requests = <RequestOptions>[];
  bool offline = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (offline) throw const SocketException('sin conexión');
    final (status, body) = answers.length > 1 ? answers.removeAt(0) : answers.first;
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), status,
        headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

const device201 = {
  'deviceId': 1, 'installationIdHint': 'cR_9…', 'platform': 'ANDROID', 'appVersion': '1.0.0+12',
  'registeredAt': '2026-11-22T23:34:00.505315Z', 'lastSeenAt': '2026-11-22T23:34:00.505315Z', 'receivesNotifications': true,
};

Map<String, dynamic> error400(String code) => {
  'timestamp': '2026-11-22T23:34:00.552730548Z', 'status': 400, 'error': 'Bad Request', 'message': '…', 'details': [code],
};

(PushDeviceRepository, BackendAdapter) repository(List<(int, Object?)> answers, {String base = 'https://api.ejemplo.test/api/v1'}) {
  final adapter = BackendAdapter(answers);
  // Same base options as DioClient: the base URL already ends in /api/v1.
  final dio = Dio(BaseOptions(baseUrl: base, contentType: Headers.jsonContentType))..httpClientAdapter = adapter;
  return (PushDeviceRepository(dio), adapter);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('push events (Backend PR #82, schemaVersion 1)', () {
    test('the four events: screen, channel, grouping and whether the plan changed', () {
      final cases = {
        'PLAN_GENERATED': ('/account-setup', true, 'kora_planes', 'plan_semana'),
        'PLAN_ADAPTED': ('/dashboard?tab=0', true, 'kora_planes', 'plan_semana'),
        'WEEKLY_PLAN_READY': ('/dashboard?tab=0', true, 'kora_planes', 'plan_semana'),
        'ACCOUNT_NOTICE': ('/dashboard?tab=3', false, 'kora_cuenta', 'aviso_cuenta'),
      };
      cases.forEach((type, expected) {
        final event = PushEvent.fromMessage(backendData(type, notice: type == 'ACCOUNT_NOTICE' ? 'PASSWORD_CHANGED' : null),
            title: 'Kora', body: 'Texto');
        expect(event.route, expected.$1, reason: type);
        expect(event.changesPlan, expected.$2, reason: type);
        expect(event.channelId, expected.$3, reason: type);
        expect(event.tag, expected.$4, reason: type);
        expect(event.payload, 'route:${expected.$1}');
        expect(event.schemaVersion, '1');
        expect(event.eventId, isNotNull);
      });
    });

    test('all the data keys of the contract are read', () {
      final plan = PushEvent.fromMessage(backendData('PLAN_ADAPTED', eventId: 'e-1'));
      expect(plan.type, PushEventType.planAdapted);
      expect(plan.target, PushTarget.weeklyPlan);
      expect(plan.eventId, 'e-1');
      expect(plan.resourceType, 'PLAN');
      expect(plan.resourceId, 42);
      final notice = PushEvent.fromMessage(backendData('ACCOUNT_NOTICE', notice: 'PASSWORD_CHANGED'));
      expect(notice.target, PushTarget.accountSecurity);
      expect(notice.noticeCode, 'PASSWORD_CHANGED');
      expect(notice.resourceId, isNull);
    });

    test('an unknown eventType is routed by targetScreen; with neither, Inicio', () {
      expect(PushEvent.fromMessage({'eventType': 'NUEVO', 'targetScreen': 'WEEKLY_PLAN'}).route, '/dashboard?tab=0');
      final security = PushEvent.fromMessage({'eventType': 'NUEVO', 'targetScreen': 'ACCOUNT_SECURITY'});
      expect(security.route, '/dashboard?tab=3');
      expect(security.channelId, 'kora_cuenta');
      for (final data in [<String, dynamic>{'eventType': 'OTRO'}, <String, dynamic>{}]) {
        final event = PushEvent.fromMessage(data);
        expect(event.type, PushEventType.unknown);
        expect(event.route, '/dashboard');
        expect(event.changesPlan, isFalse);
      }
      expect(PushEvent.fromMessage({'type': 'PLAN_ADAPTED'}).type, PushEventType.unknown, reason: 'only the contract key eventType');
    });

    test('a push shown with the app open is routed by the same tap handler as the reminders', () {
      expect(reminderRoute('route:/dashboard?tab=3'), '/dashboard?tab=3');
      expect(reminderRoute('workout:9'), '/dashboard?tab=1');
      expect(reminderRoute('route:https://otra.web'), '/dashboard', reason: 'only in-app routes');
      expect(reminderRoute(null), '/dashboard');
    });
  });

  group('HTTP contract (EJEMPLOS_REALES_HTTP.md)', () {
    test('PUT /api/v1/users/me/push-devices with exactly installationId, platform, appId, appVersion', () async {
      final (repo, adapter) = repository([(201, device201)]);
      final result = await repo.register(installationId: fid, appVersion: '1.0.0+12');
      final request = adapter.requests.single;
      expect(request.method, 'PUT');
      expect(request.uri.toString(), 'https://api.ejemplo.test/api/v1/users/me/push-devices', reason: '/api/v1 exactly once');
      expect(jsonEncode(request.data), '{"installationId":"$fid","platform":"ANDROID","appId":"pe.fit.kora","appVersion":"1.0.0+12"}');
      expect(result.status, PushDeviceStatus.registered);
      expect(result.created, isTrue);
      expect(result.device!.installationIdHint, 'cR_9…');
      expect(result.device!.receivesNotifications, isTrue);
    });

    test('appVersion is optional; a repeated PUT is a 200 renewal', () async {
      final (repo, adapter) = repository([(200, {...device201, 'appVersion': null})]);
      final result = await repo.register(installationId: fid);
      expect(jsonEncode(adapter.requests.single.data), '{"installationId":"$fid","platform":"ANDROID","appId":"pe.fit.kora"}');
      expect(result.status, PushDeviceStatus.registered);
      expect(result.created, isFalse);
    });

    test('a base URL with a trailing slash still has /api/v1 once', () async {
      final (repo, adapter) = repository([(200, device201)], base: 'https://api.ejemplo.test/api/v1/');
      await repo.register(installationId: fid);
      expect(adapter.requests.single.uri.toString(), 'https://api.ejemplo.test/api/v1/users/me/push-devices');
    });

    test('DELETE /api/v1/users/me/push-devices carries the FID in the body (204), quietly on 401', () async {
      final (repo, adapter) = repository([(204, null)]);
      final result = await repo.unregister(fid);
      final request = adapter.requests.single;
      expect(request.method, 'DELETE');
      expect(request.uri.toString(), 'https://api.ejemplo.test/api/v1/users/me/push-devices');
      expect(jsonEncode(request.data), '{"installationId":"$fid"}');
      expect(result.status, PushDeviceStatus.removed);
      expect(request.extra[AuthInterceptor.quietUnauthorized], isTrue);
      final unauthorized = DioException(
        requestOptions: request..headers['Authorization'] = 'Bearer x',
        response: Response(requestOptions: request, statusCode: 401),
      );
      expect(AuthInterceptor.isExpiredSession(unauthorized), isFalse, reason: 'unlinking at logout must not start another logout');
    });

    test('refusals keep the backend code (details[0])', () async {
      for (final code in ['IDENTIFICADOR_PUSH_INVALIDO', 'APLICACION_NO_ADMITIDA', 'PLATAFORMA_NO_ADMITIDA', 'CUENTA_NO_ACTIVA']) {
        final (repo, _) = repository([(400, error400(code))]);
        final result = await repo.register(installationId: fid);
        expect(result.status, PushDeviceStatus.rejected);
        expect(result.code, code);
      }
    });

    test('401, 404/405/501, 5xx and no connection', () async {
      final unauthorized = {'timestamp': 't', 'message': 'Se requiere un token valido.', 'error': 'Unauthorized', 'status': 401};
      expect((await repository([(401, unauthorized)]).$1.register(installationId: fid)).status, PushDeviceStatus.unauthorized);
      for (final status in [404, 405, 501]) {
        expect((await repository([(status, null)]).$1.register(installationId: fid)).status, PushDeviceStatus.backendNotReady, reason: '$status');
      }
      expect((await repository([(500, null)]).$1.register(installationId: fid)).status, PushDeviceStatus.unavailable);
      final (repo, adapter) = repository([(200, device201)]);
      adapter.offline = true;
      expect((await repo.register(installationId: fid)).status, PushDeviceStatus.unavailable);
      expect((await repo.unregister(fid)).status, PushDeviceStatus.unavailable);
    });

    test('409 (two simultaneous PUTs of the same FID) is retried once', () async {
      final (repo, adapter) = repository([(409, null), (200, device201)]);
      expect((await repo.register(installationId: fid)).status, PushDeviceStatus.registered);
      expect(adapter.requests, hasLength(2));
      final (repo2, adapter2) = repository([(409, null)]);
      expect((await repo2.register(installationId: fid)).status, PushDeviceStatus.unavailable);
      expect(adapter2.requests, hasLength(2), reason: 'only one retry');
    });

    test('GET devices: the full FID never comes back; receivesNotifications=false after a password change', () async {
      final (repo, adapter) = repository([(200, [ {...device201, 'receivesNotifications': false} ])]);
      final devices = await repo.devices();
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.uri.path, '/api/v1/users/me/push-devices');
      expect(devices.single.deviceId, 1);
      expect(devices.single.installationIdHint, 'cR_9…');
      expect(devices.single.receivesNotifications, isFalse);
    });

    test('notification preferences: GET and PUT with both fields', () async {
      final (repo, adapter) = repository([(200, {'planUpdates': true, 'accountNotices': true}), (200, {'planUpdates': false, 'accountNotices': true})]);
      expect(await repo.preferences(), const NotificationPreferences(planUpdates: true, accountNotices: true));
      final saved = await repo.savePreferences(const NotificationPreferences(planUpdates: false, accountNotices: true));
      expect(saved, const NotificationPreferences(planUpdates: false, accountNotices: true));
      expect(adapter.requests.map((r) => '${r.method} ${r.uri.path}'),
          ['GET /api/v1/users/me/notification-preferences', 'PUT /api/v1/users/me/notification-preferences']);
      expect(jsonEncode(adapter.requests.last.data), '{"planUpdates":false,"accountNotices":true}');
    });

    test('only Firebase Installation IDs are sent, never an FCM registration token', () {
      expect(PushDeviceRepository.isInstallationId(fid), isTrue);
      expect(PushDeviceRepository.isInstallationId(fcmToken), isFalse);
      expect(PushDeviceRepository.isInstallationId('corto'), isFalse);
      expect(PushDeviceRepository.isInstallationId(null), isFalse);
      expect(PushDeviceRepository.appId, 'pe.fit.kora');
    });
  });

  group('push controller: session lifecycle', () {
    late FakeMessaging messaging;
    late FakeDevices devices;
    late FakeNotifier notifier;
    late MemoryStore store;
    late int planChanges;
    late List<String> opened;
    late List<String> log;
    PushController build({FakeMessaging? m, FakeNotifier? n, MemoryStore? s}) {
      log = [];
      messaging = m ?? FakeMessaging(log: log);
      devices = FakeDevices(log: log);
      notifier = n ?? FakeNotifier();
      store = s ?? MemoryStore();
      planChanges = 0;
      opened = [];
      return PushController(messaging: messaging, devices: devices, notifier: notifier, store: store,
          onPlanChanged: () => planChanges++, open: opened.add);
    }

    test('after login: register() with FCM, then PUT with the FID from onRegistered', () async {
      final c = build();
      await c.onUser(7);
      await pump();
      expect(messaging.registers, 1);
      expect(devices.registered, [fid]);
      expect(c.state, PushState.registered);
      expect(store.value, fid);
      expect(notifier.prepared, 1, reason: 'channels created once');
      await c.onUser(7);
      await pump();
      expect(devices.registered, [fid], reason: 'same account, same FID: no duplicate PUT in this run');
      c.dispose();
    });

    test('every start with a session renews the registration (PUT again)', () async {
      final first = build();
      await first.onUser(7);
      await pump();
      first.dispose();
      final next = PushController(messaging: messaging, devices: devices, notifier: notifier, store: store, onPlanChanged: () {}, open: (_) {});
      await next.onUser(7);
      await pump();
      expect(devices.registered, [fid, fid]);
      next.dispose();
    });

    test('a new FID from onRegistered is registered', () async {
      final c = build();
      await c.onUser(7);
      await pump();
      messaging.registered.add(fid2);
      await pump();
      expect(devices.registered, [fid, fid2]);
      c.dispose();
    });

    test('another account on the same phone registers the FID for itself', () async {
      final c = build();
      await c.onUser(7);
      await pump();
      await c.beforeLogout();
      await c.onUser(8);
      await pump();
      expect(log, ['PUT $fid', 'DELETE $fid', 'fcm unregister', 'PUT $fid']);
      c.dispose();
    });

    test('the confirmation of our own unregister arriving after the next login does not unlink the new account', () async {
      final c = build();
      messaging.deferUnregistered = true;
      await c.onUser(7);
      await pump();
      await c.beforeLogout();
      await c.onUser(8);
      await pump();
      messaging.pendingUnregistered.forEach(messaging.unregistered.add);
      await pump();
      expect(log, ['PUT $fid', 'DELETE $fid', 'fcm unregister', 'PUT $fid']);
      expect(c.state, PushState.registered);
      c.dispose();
    });

    test('logout: DELETE with the FID first (JWT still valid), then FCM unregister; nothing is sent afterwards', () async {
      final c = build();
      await c.onUser(7);
      await pump();
      await c.beforeLogout();
      await pump();
      expect(log, ['PUT $fid', 'DELETE $fid', 'fcm unregister'], reason: 'onUnregistered after logout does not DELETE again');
      expect(store.value, isNull);
      messaging.registered.add(fid2);
      await pump();
      expect(devices.registered, [fid], reason: 'no account signed in');
      expect(c.state, PushState.idle);
      c.dispose();
    });

    test('logout in a run that did not register: the stored FID is unlinked', () async {
      final c = build(n: FakeNotifier(allowed: false), s: MemoryStore()..value = fid);
      await c.onUser(7);
      await c.beforeLogout();
      expect(devices.removed, [fid]);
      expect(messaging.unregisters, 1);
      c.dispose();
    });

    test('logout never initialises Firebase just to unregister (push not started in this run)', () async {
      final c = build(s: MemoryStore()..value = fid);
      await c.beforeLogout();
      expect(messaging.starts, 0);
      expect(messaging.unregisters, 0);
      expect(devices.removed, [fid], reason: 'the backend link is still removed');
      c.dispose();
    });

    test('onUnregistered while signed in unlinks that FID', () async {
      final c = build();
      await c.onUser(7);
      await pump();
      messaging.unregistered.add(fid);
      await pump();
      expect(devices.removed, [fid]);
      c.dispose();
    });

    test('without notification permission nothing is registered; allowing it registers on resume', () async {
      final c = build(n: FakeNotifier(allowed: false));
      await c.onUser(7);
      await pump();
      expect(messaging.registers, 0);
      expect(c.state, PushState.permissionMissing);
      notifier.allowed = true;
      await c.onResumed();
      await pump();
      expect(devices.registered, [fid]);
      expect(c.state, PushState.registered);
      c.dispose();
    });

    test('Firebase failing does not block login; it is retried on resume', () async {
      final c = build(m: FakeMessaging(registerError: Exception('SERVICE_NOT_AVAILABLE')));
      await expectLater(c.onUser(7), completes);
      expect(c.state, PushState.notRegisteredWithFcm);
      messaging.registerError = null;
      await c.onResumed();
      await pump();
      expect(devices.registered, [fid]);
      c.dispose();
    });

    test('an FCM registration token (old Google Play services) is never sent to the backend', () async {
      final c = build(m: FakeMessaging(installationId: fcmToken));
      await c.onUser(7);
      await pump();
      expect(devices.registered, isEmpty);
      expect(c.state, PushState.notRegisteredWithFcm);
      c.dispose();
    });

    test('backend unreachable or refusing: recorded, retried on resume', () async {
      final c = build();
      devices.answer = const PushDeviceResult(PushDeviceStatus.unavailable);
      await c.onUser(7);
      await pump();
      expect(c.state, PushState.backendError);
      devices.answer = const PushDeviceResult(PushDeviceStatus.registered);
      await c.onResumed();
      await pump();
      expect(devices.registered, [fid, fid]);
      expect(c.state, PushState.registered);
      c.dispose();
    });

    test('push unavailable (web, no Firebase): the app keeps working', () async {
      final c = build(m: FakeMessaging(available: false));
      await c.onUser(7);
      await c.beforeLogout();
      expect(c.state, PushState.idle);
      expect(devices.registered, isEmpty);
      expect(notifier.prepared, 0);
    });
  });

  group('push controller: messages', () {
    late FakeMessaging messaging;
    late FakeNotifier notifier;
    late int planChanges;
    late List<String> opened;
    PushController build({FakeMessaging? m}) {
      messaging = m ?? FakeMessaging();
      notifier = FakeNotifier();
      planChanges = 0;
      opened = [];
      return PushController(messaging: messaging, devices: FakeDevices(), notifier: notifier, store: MemoryStore(),
          onPlanChanged: () => planChanges++, open: opened.add);
    }

    test('with the app open: shown, plan reloaded for plan events, duplicates (same eventId) dropped', () async {
      final c = build();
      await c.onUser(7);
      final weekly = PushEvent.fromMessage(backendData('WEEKLY_PLAN_READY', eventId: 'e-1'), title: 'Tu nueva semana está lista', body: '…');
      messaging.foreground
        ..add(weekly)
        ..add(weekly)
        ..add(PushEvent.fromMessage(backendData('ACCOUNT_NOTICE', eventId: 'e-2', notice: 'PASSWORD_CHANGED'), title: 'Aviso de seguridad', body: '…'));
      await pump();
      expect(notifier.shown.map((e) => e.type), [PushEventType.weeklyPlanReady, PushEventType.accountNotice]);
      expect(planChanges, 1);
      expect(opened, isEmpty, reason: 'showing is not opening');
      c.dispose();
    });

    test('tapping a notification (cold start or background) opens its screen once', () async {
      final launch = PushEvent.fromMessage(backendData('PLAN_GENERATED', eventId: 'e-3'));
      final c = build(m: FakeMessaging(initial: launch));
      await c.onUser(7);
      expect(opened, ['/account-setup']);
      messaging.opened
        ..add(launch)
        ..add(PushEvent.fromMessage(backendData('PLAN_ADAPTED', eventId: 'e-4')))
        ..add(PushEvent.fromMessage(backendData('ACCOUNT_NOTICE', eventId: 'e-5')));
      await pump();
      expect(opened, ['/account-setup', '/dashboard?tab=0', '/dashboard?tab=3']);
      expect(planChanges, 2);
      c.dispose();
    });
  });

  group('Android channels of the contract', () {
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
          'areNotificationsEnabled' => true,
          _ => null,
        };
      });
    });
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    test('kora_planes and kora_cuenta are created and the old test channel removed', () async {
      final notifier = LocalPushNotifier();
      await notifier.prepare();
      expect(await notifier.permitted(), isTrue);
      final created = calls.where((c) => c.method == 'createNotificationChannel').map((c) => (c.arguments as Map)['id']);
      expect(created, ['kora_planes', 'kora_cuenta']);
      expect(calls.where((c) => c.method == 'deleteNotificationChannel').map((c) => c.arguments), ['kora_avisos']);
    });

    test('a message shown with the app open uses its channel and the backend grouping', () async {
      final notifier = LocalPushNotifier();
      await notifier.show(PushEvent.fromMessage(backendData('PLAN_ADAPTED'), title: 'Ajustamos tu plan', body: 'Revisa los cambios'));
      await notifier.show(PushEvent.fromMessage(backendData('ACCOUNT_NOTICE'), title: 'Aviso de seguridad', body: '…'));
      final shows = calls.where((c) => c.method == 'show').map((c) => c.arguments as Map).toList();
      expect(shows.map((s) => (s['platformSpecifics'] as Map)['channelId']), ['kora_planes', 'kora_cuenta']);
      expect(shows.map((s) => (s['platformSpecifics'] as Map)['tag']), ['plan_semana', 'aviso_cuenta']);
      expect(shows.map((s) => s['id']), [900000001, 900000002], reason: 'a newer notice replaces the previous one of its kind');
      expect(shows.first['payload'], 'route:/dashboard?tab=0');
    });
  });
}
