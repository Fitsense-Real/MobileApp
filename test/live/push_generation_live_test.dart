// Live check, against a running backend (Fitsense-Real/Backend PR #82), that the
// first-plan generation is requested only after this phone is registered.
// Skipped unless KORA_LIVE_API_BASE_URL is set; synthetic account and FID only.
//
//   KORA_LIVE_API_BASE_URL=http://localhost:8080/api/v1 KORA_LIVE_EMAIL_A=... KORA_LIVE_EMAIL_B=... \
//   KORA_LIVE_EMAIL_C=... KORA_LIVE_PASSWORD=... KORA_LIVE_FID_A=... KORA_LIVE_FID_B=... KORA_LIVE_FID_C=... flutter test test/live/push_generation_live_test.dart
//
// A, B and C are accounts with a profile and no plan, each on its own phone (its own FID).
// Every account stays signed in from login to generation.
//
// Uses the app's real PushPermissionPrompt (end of the profile setup), PushController,
// PushDeviceRepository, FirstPlanGenerationController and PlanGenerationRepository. Only
// Firebase and Android are simulated: the stand-in hands over the phone's FID through
// onRegistered, as FCM does, and the sheet and the system dialog answer as each case says.
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/push/data/push_device_repository.dart';
import 'package:fitsense_mobile/features/push/data/push_messaging.dart';
import 'package:fitsense_mobile/features/push/data/push_notifier.dart';
import 'package:fitsense_mobile/features/push/domain/push_event.dart';
import 'package:fitsense_mobile/features/push/presentation/push_controller.dart';
import 'package:fitsense_mobile/features/push/presentation/push_permission_prompt.dart';
import 'package:fitsense_mobile/features/welcome/domain/generation_operation.dart';
import 'package:fitsense_mobile/features/welcome/presentation/first_plan_generation_controller.dart';
import '../support/welcome_fakes.dart' show SignedIn;

final env = Platform.environment;
final base = env['KORA_LIVE_API_BASE_URL'];

/// FCM on one phone: hands over that phone's FID through onRegistered.
class FirebaseStandIn implements PushMessaging {
  FirebaseStandIn(this.fid);
  final String fid;
  final registered = StreamController<String>.broadcast();
  @override
  Future<bool> start() async => true;
  @override
  Future<void> register() async => scheduleMicrotask(() => registered.add(fid));
  @override
  Future<void> unregister() async {}
  @override
  Stream<String> get onRegistered => registered.stream;
  @override
  Stream<String> get onUnregistered => const Stream.empty();
  @override
  Stream<PushEvent> get onForegroundMessage => const Stream.empty();
  @override
  Stream<PushEvent> get onOpened => const Stream.empty();
  @override
  Future<PushEvent?> initialEvent() async => null;
}

/// Android's notification permission (granted by the dialog unless [refuse]).
class Permission implements PushNotifier {
  Permission({this.allowed = false});
  bool allowed;
  @override
  Future<void> prepare() async {}
  @override
  Future<bool> permitted() async => allowed;
  @override
  Future<bool> requestPermission() async => allowed = true;
  @override
  Future<void> show(PushEvent event) async {}
}

class NeverAsked implements PushPromptStore {
  bool value = false;
  @override
  Future<bool> asked() async => value;
  @override
  Future<void> markAsked() async => value = true;
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

/// Records when each request leaves the app, in order.
class Order extends Interceptor {
  final sent = <String>[];
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    sent.add('${options.method} ${options.path}');
    handler.next(options);
  }
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    sent.add('${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}');
    handler.next(response);
  }
}

Future<String> login(String email) async =>
    (await Dio(BaseOptions(baseUrl: base!)).post('/auth/login', data: {'email': email, 'password': env['KORA_LIVE_PASSWORD']})).data['token'] as String;

/// What the app does for one account, signed in the whole time: the session
/// listener syncs push, the end of the profile setup shows the explanation
/// (answered with [answer]; null = already granted, nothing shown), and the
/// first plan is requested. Returns the order of the requests that left the app.
Future<(List<String>, PushController, PushDeviceRepository)> firstPlan(String email, String fid, {required bool? answer}) async {
  final order = Order();
  final dio = Dio(BaseOptions(baseUrl: base!, contentType: Headers.jsonContentType,
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer ${await login(email)}'}))..interceptors.add(order);
  final devices = PushDeviceRepository(dio);
  final permission = Permission(allowed: answer == null);
  final push = PushController(messaging: FirebaseStandIn(fid), devices: devices, notifier: permission, store: MemoryStore(),
      onPlanChanged: () {}, open: (_) {}, appVersion: '1.0.0+1');
  final c = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    authViewModelProvider.overrideWith(() => SignedIn(7)),
    pushControllerProvider.overrideWithValue(push),
    pushNotifierProvider.overrideWithValue(permission),
    pushPromptStoreProvider.overrideWithValue(NeverAsked()),
    pushPromptPresenterProvider.overrideWithValue(() async => answer),
  ]);
  addTearDown(c.dispose);
  unawaited(push.onUser(7)); // confirmed login, JWT stored
  final outcome = await c.read(pushPermissionPromptProvider).beforeFirstPlan();
  expect(outcome, switch (answer) {
    null => PushPermissionOutcome.alreadyGranted,
    true => PushPermissionOutcome.granted,
    false => PushPermissionOutcome.declined,
  });
  await c.read(firstPlanGenerationProvider.notifier).start();
  expect(c.read(firstPlanGenerationProvider).operation?.status, isNot(GenerationStatus.failed));
  return (order.sent, push, devices);
}

void main() {
  final skip = base == null ? 'KORA_LIVE_API_BASE_URL not set (needs a running backend)' : false;

  test('A · permission already granted: no sheet, synchronised directly, PUT 201 before the generation; restored session renews', () async {
    final (sent, push, devices) = await firstPlan(env['KORA_LIVE_EMAIL_A']!, env['KORA_LIVE_FID_A']!, answer: null);
    expect(push.state, PushState.registered);
    expect(sent.indexOf('POST /users/me/plan/generation'), greaterThan(sent.indexOf('201 PUT /users/me/push-devices')), reason: sent.join(', '));
    // Next app start, session restored: the same FID again (200), no duplicate.
    final restored = PushController(messaging: FirebaseStandIn(env['KORA_LIVE_FID_A']!), devices: devices, notifier: Permission(allowed: true), store: MemoryStore(),
        onPlanChanged: () {}, open: (_) {}, appVersion: '1.0.0+1');
    unawaited(restored.onUser(7));
    expect(await restored.ensureSynced(), PushState.registered);
    expect(restored.lastResult!.created, isFalse);
    expect(await devices.devices(), hasLength(1));
  }, skip: skip);

  test('B · new user accepts the sheet: Android permission, PUT 201, and only then the generation', () async {
    final (sent, push, _) = await firstPlan(env['KORA_LIVE_EMAIL_B']!, env['KORA_LIVE_FID_B']!, answer: true);
    expect(push.state, PushState.registered);
    expect(push.lastResult!.created, isTrue);
    expect(sent.indexOf('POST /users/me/plan/generation'), greaterThan(sent.indexOf('201 PUT /users/me/push-devices')), reason: sent.join(', '));
  }, skip: skip);

  test('C · new user picks «Ahora no»: the generation goes on, no device', () async {
    final (sent, push, _) = await firstPlan(env['KORA_LIVE_EMAIL_C']!, env['KORA_LIVE_FID_C']!, answer: false);
    expect(push.state, PushState.permissionMissing);
    expect(sent.where((r) => r.contains('push-devices')), isEmpty);
    expect(sent, contains('POST /users/me/plan/generation'));
  }, skip: base == null ? 'KORA_LIVE_API_BASE_URL not set (needs a running backend)' : false);
}
