import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/authentication/domain/entities/user.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/push/data/push_device_repository.dart';
import 'package:fitsense_mobile/features/push/data/push_messaging.dart';
import 'package:fitsense_mobile/features/push/data/push_notifier.dart';
import 'package:fitsense_mobile/features/push/domain/push_event.dart';
import 'package:fitsense_mobile/features/push/presentation/push_controller.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/domain/generation_operation.dart';
import 'package:fitsense_mobile/features/welcome/presentation/first_plan_generation_controller.dart';
import 'support/welcome_fakes.dart';

// The phone is registered in the backend (FID + 200/201) before the automatic
// first-plan generation is requested, so PLAN_GENERATED finds an active device.

const fid = 'cR_9l0aBcD3fGh1jK2lM4n';
const fid2 = 'dQ_8k1bCdE4gHi2kL3mN5o';

class FakeMessaging implements PushMessaging {
  FakeMessaging({this.available = true, this.registerError});
  final bool available;
  Object? registerError;
  String installationId = fid;
  final registered = StreamController<String>.broadcast();
  final unregistered = StreamController<String>.broadcast();
  int registers = 0, unregisters = 0;
  @override
  Future<bool> start() async => available;
  @override
  Future<void> register() async {
    registers++;
    if (registerError != null) throw registerError!;
    scheduleMicrotask(() => registered.add(installationId));
  }
  @override
  Future<void> unregister() async => unregisters++;
  @override
  Stream<String> get onRegistered => registered.stream;
  @override
  Stream<String> get onUnregistered => unregistered.stream;
  @override
  Stream<PushEvent> get onForegroundMessage => const Stream.empty();
  @override
  Stream<PushEvent> get onOpened => const Stream.empty();
  @override
  Future<PushEvent?> initialEvent() async => null;
}

/// The backend: each PUT waits until the test answers it.
class SlowDevices extends PushDeviceRepository {
  SlowDevices(this.log) : super(Dio());
  final List<String> log;
  final pending = <Completer<PushDeviceResult>>[];
  final registered = <String>[];
  PushDeviceResult unlinkAnswer = const PushDeviceResult(PushDeviceStatus.removed);
  @override
  Future<PushDeviceResult> register({required String installationId, String? appVersion}) {
    registered.add(installationId);
    log.add('PUT');
    final answer = Completer<PushDeviceResult>();
    pending.add(answer);
    return answer.future.then((r) {
      log.add('PUT ${r.status.name}');
      return r;
    });
  }
  void answer(PushDeviceResult result) => pending.removeAt(0).complete(result);
  @override
  Future<PushDeviceResult> unregister(String installationId) async {
    log.add('DELETE');
    return unlinkAnswer;
  }
}

class FakeNotifier implements PushNotifier {
  FakeNotifier({this.allowed = true});
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

class MemoryStore implements PushInstallationStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String installationId) async => value = installationId;
  @override
  Future<void> clear() async => value = null;
}

class LoggedGeneration extends FakeGeneration {
  LoggedGeneration(this.log) : super(starts: [operation('PENDING')], finds: [operation('PROCESSING')]);
  final List<String> log;
  @override
  Future<GenerationOperation> start() {
    log.add('generation');
    return super.start();
  }
}

const ok201 = PushDeviceResult(PushDeviceStatus.registered, created: true);
const ok200 = PushDeviceResult(PushDeviceStatus.registered);

Future<void> pump() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final timeout = PushController.syncTimeout;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    PushController.syncTimeout = const Duration(milliseconds: 200);
  });
  tearDown(() => PushController.syncTimeout = timeout);

  late List<String> log;
  late FakeMessaging messaging;
  late SlowDevices devices;
  late FakeNotifier notifier;
  late MemoryStore store;
  late LoggedGeneration generation;

  (ProviderContainer, PushController) build({FakeMessaging? m, bool allowed = true}) {
    log = [];
    messaging = m ?? FakeMessaging();
    devices = SlowDevices(log);
    notifier = FakeNotifier(allowed: allowed);
    store = MemoryStore();
    generation = LoggedGeneration(log);
    final controller = PushController(messaging: messaging, devices: devices, notifier: notifier, store: store,
        onPlanChanged: () {}, open: (_) {});
    final c = ProviderContainer(overrides: [
      authViewModelProvider.overrideWith(() => SignedIn(7)),
      planGenerationRepositoryProvider.overrideWithValue(generation),
      pushControllerProvider.overrideWithValue(controller),
    ]);
    addTearDown(c.dispose);
    return (c, controller);
  }

  test('the first generation is requested only after the backend answered the PUT (201)', () async {
    final (c, push) = build();
    unawaited(push.onUser(7)); // login confirmed, JWT stored
    final starting = c.read(firstPlanGenerationProvider.notifier).start();
    await pump();
    expect(log, ['PUT'], reason: 'FID received and sent, generation still waiting');
    expect(generation.startCalls, 0, reason: 'the FID alone does not count as registered');
    devices.answer(ok201);
    await starting;
    expect(log, ['PUT', 'PUT registered', 'generation']);
    expect(push.state, PushState.registered);
    expect(store.value, fid);
  });

  test('retry after a failed generation also waits for the registration', () async {
    final (c, push) = build();
    unawaited(push.onUser(7));
    final retrying = c.read(firstPlanGenerationProvider.notifier).retry();
    await pump();
    expect(generation.startCalls, 0);
    devices.answer(ok200);
    await retrying;
    expect(log, ['PUT', 'PUT registered', 'generation']);
  });

  test('a backend error is not "registered": the generation goes on without blocking', () async {
    final (c, push) = build();
    unawaited(push.onUser(7));
    final starting = c.read(firstPlanGenerationProvider.notifier).start();
    await pump();
    devices.answer(const PushDeviceResult(PushDeviceStatus.unavailable));
    await starting;
    expect(log, ['PUT', 'PUT unavailable', 'generation']);
    expect(push.state, PushState.backendError);
  });

  test('a backend that does not answer: the generation starts after the timeout', () async {
    final (c, push) = build();
    unawaited(push.onUser(7));
    final watch = Stopwatch()..start();
    await c.read(firstPlanGenerationProvider.notifier).start();
    expect(generation.startCalls, 1);
    expect(watch.elapsed, greaterThanOrEqualTo(PushController.syncTimeout));
    expect(push.state, isNot(PushState.registered));
  });

  for (final (label, m, allowed) in [
    ('without notification permission', null, false),
    ('Firebase not available', FakeMessaging(available: false), true),
    ('FCM failing to register', FakeMessaging(registerError: Exception('SERVICE_NOT_AVAILABLE')), true),
  ]) {
    test('$label: the generation starts at once, nothing is sent', () async {
      final (c, push) = build(m: m, allowed: allowed);
      await push.onUser(7);
      final watch = Stopwatch()..start();
      await c.read(firstPlanGenerationProvider.notifier).start();
      expect(generation.startCalls, 1);
      expect(devices.registered, isEmpty);
      expect(watch.elapsed, lessThan(PushController.syncTimeout));
    });
  }

  test('no session sync started (signed out, tests, web): no waiting at all', () async {
    final (_, push) = build();
    final watch = Stopwatch()..start();
    expect(await push.ensureSynced(), PushState.idle);
    expect(watch.elapsed, lessThan(PushController.syncTimeout));
  });

  test('simultaneous syncs (login, resume, repeated onRegistered) send one PUT', () async {
    final (_, push) = build();
    unawaited(push.onUser(7));
    unawaited(push.onResumed());
    unawaited(push.onUser(7));
    await pump();
    messaging.registered.add(fid); // FCM repeats the same FID
    await pump();
    expect(devices.registered, [fid], reason: 'no duplicate request while the first is in flight');
    devices.answer(ok201);
    await pump();
    expect(await push.ensureSynced(), PushState.registered);
    await push.onUser(7);
    await pump();
    expect(devices.registered, [fid], reason: 'already registered in this run');
  });

  test('a restored session (next app start) synchronises again: one PUT, renewal 200', () async {
    final (_, first) = build();
    unawaited(first.onUser(7));
    await pump();
    devices.answer(ok201);
    await pump();
    first.dispose();
    final restored = PushController(messaging: messaging, devices: devices, notifier: notifier, store: store, onPlanChanged: () {}, open: (_) {});
    unawaited(restored.onUser(7)); // restoreSession
    await pump();
    devices.answer(ok200);
    expect(await restored.ensureSynced(), PushState.registered);
    expect(devices.registered, [fid, fid], reason: 'one per run, the backend answers 200 with the same deviceId');
    restored.dispose();
  });

  test('a new FID reported by Firebase is registered, and a generation waits for it', () async {
    final (c, push) = build();
    unawaited(push.onUser(7));
    await pump();
    devices.answer(ok201);
    await pump();
    messaging.registered.add(fid2);
    await pump();
    final starting = c.read(firstPlanGenerationProvider.notifier).start();
    await pump();
    expect(generation.startCalls, 0);
    devices.answer(ok200);
    await starting;
    expect(devices.registered, [fid, fid2]);
    expect(log.last, 'generation');
  });

  test('logout: DELETE before the JWT goes; a failed unlink is recorded and FCM still unregisters', () async {
    final (_, push) = build();
    unawaited(push.onUser(7));
    await pump();
    devices.answer(ok201);
    await pump();
    devices.unlinkAnswer = const PushDeviceResult(PushDeviceStatus.unavailable);
    await push.beforeLogout();
    expect(log.last, 'DELETE');
    expect(push.lastResult!.status, PushDeviceStatus.unavailable);
    expect(messaging.unregisters, 1, reason: 'the phone stops receiving even if the backend could not be reached');
    expect(store.value, isNull);
    expect(await push.ensureSynced(), PushState.idle);
  });

  test('only a confirmed session registers: not the account just created without a JWT', () {
    const user = User(id: 7, firstName: 'Ana', lastName: 'Demo', email: 'a@b.com', timezone: 'America/Lima');
    expect(pushSessionUserId(const AuthState(user: user)), isNull, reason: 'register: no JWT yet');
    expect(pushSessionUserId(const AuthState(isAuthenticated: true, user: user)), 7, reason: 'login or restored session');
    expect(pushSessionUserId(const AuthState()), isNull);
  });
}
