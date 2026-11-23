// Live check, against a running backend (Fitsense-Real/Backend PR #82), that the
// first-plan generation is requested only after this phone is registered.
// Skipped unless KORA_LIVE_API_BASE_URL is set; synthetic account and FID only.
//
//   KORA_LIVE_API_BASE_URL=http://localhost:8080/api/v1 KORA_LIVE_EMAIL_A=... KORA_LIVE_PASSWORD=... \
//   KORA_LIVE_FID=... flutter test test/live/push_generation_live_test.dart
//
// Uses the app's real PushController, PushDeviceRepository, FirstPlanGenerationController
// and PlanGenerationRepository. Only Firebase is simulated: it hands over KORA_LIVE_FID
// through onRegistered, as FCM does on the phone.
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
import 'package:fitsense_mobile/features/welcome/domain/generation_operation.dart';
import 'package:fitsense_mobile/features/welcome/presentation/first_plan_generation_controller.dart';
import '../support/welcome_fakes.dart' show SignedIn;

final env = Platform.environment;
final base = env['KORA_LIVE_API_BASE_URL'];

class FirebaseStandIn implements PushMessaging {
  final registered = StreamController<String>.broadcast();
  @override
  Future<bool> start() async => true;
  @override
  Future<void> register() async => scheduleMicrotask(() => registered.add(env['KORA_LIVE_FID']!));
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

class Allowed implements PushNotifier {
  @override
  Future<void> prepare() async {}
  @override
  Future<bool> permitted() async => true;
  @override
  Future<bool> requestPermission() async => true;
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

void main() {
  test('login → FID → PUT 201 → only then the first-plan generation; restored session renews without duplicates', () async {
    final login = await Dio(BaseOptions(baseUrl: base!)).post('/auth/login', data: {'email': env['KORA_LIVE_EMAIL_A'], 'password': env['KORA_LIVE_PASSWORD']});
    final order = Order();
    final dio = Dio(BaseOptions(baseUrl: base!, contentType: Headers.jsonContentType,
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer ${login.data['token']}'}))..interceptors.add(order);
    final devices = PushDeviceRepository(dio);
    final store = MemoryStore();
    PushController controller() => PushController(messaging: FirebaseStandIn(), devices: devices, notifier: Allowed(), store: store,
        onPlanChanged: () {}, open: (_) {}, appVersion: '1.0.0+1');
    final push = controller();
    final c = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      authViewModelProvider.overrideWith(() => SignedIn(7)),
      pushControllerProvider.overrideWithValue(push),
    ]);
    addTearDown(c.dispose);

    // What the app does after login: the session listener syncs push, and account
    // setup starts the first plan right away.
    unawaited(push.onUser(7));
    await c.read(firstPlanGenerationProvider.notifier).start();
    expect(push.state, PushState.registered);
    expect(push.lastResult!.created, isTrue, reason: '201: first registration of this phone');
    final put = order.sent.indexOf('201 PUT /users/me/push-devices');
    final generation = order.sent.indexOf('POST /users/me/plan/generation');
    expect(put, isNonNegative, reason: order.sent.join(', '));
    expect(generation, greaterThan(put), reason: 'generation requested after the backend confirmed the device: ${order.sent.join(', ')}');
    expect(c.read(firstPlanGenerationProvider).operation?.status, isNot(GenerationStatus.failed));

    // Next app start, session restored: the same FID is synchronised again (200).
    final restored = controller();
    unawaited(restored.onUser(7));
    expect(await restored.ensureSynced(), PushState.registered);
    expect(restored.lastResult!.created, isFalse, reason: '200: renewal, not a new device');
    final active = await devices.devices();
    expect(active, hasLength(1), reason: 'no duplicate registrations');
    expect(active.single.receivesNotifications, isTrue);
    restored.dispose();
    push.dispose();
  }, skip: base == null ? 'KORA_LIVE_API_BASE_URL not set (needs a running backend)' : false);
}
