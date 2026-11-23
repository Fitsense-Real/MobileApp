import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/onboarding/presentation/onboarding_page.dart';
import 'package:fitsense_mobile/features/push/data/push_device_repository.dart';
import 'package:fitsense_mobile/features/push/data/push_messaging.dart';
import 'package:fitsense_mobile/features/push/data/push_notifier.dart';
import 'package:fitsense_mobile/features/push/domain/push_event.dart';
import 'package:fitsense_mobile/features/push/presentation/push_controller.dart';
import 'package:fitsense_mobile/features/push/presentation/push_permission_prompt.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/domain/generation_operation.dart';
import 'package:fitsense_mobile/features/welcome/presentation/welcome_routes.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/welcome_fakes.dart';

// The push explanation at the end of the profile setup, before the first plan
// is requested, so its PLAN_GENERATED notice can reach the phone. Simulated:
// no backend, no Firebase, no network. The session stays signed in throughout.

const fid = 'cR_9l0aBcD3fGh1jK2lM4n';

class FakeMessaging implements PushMessaging {
  FakeMessaging({this.registerError});
  Object? registerError;
  final registered = StreamController<String>.broadcast();
  int registers = 0;
  @override
  Future<bool> start() async => true;
  @override
  Future<void> register() async {
    registers++;
    if (registerError != null) throw registerError!;
    scheduleMicrotask(() => registered.add(fid));
  }
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

/// The backend: each PUT waits until the test answers it.
class SlowDevices extends PushDeviceRepository {
  SlowDevices(this.log) : super(Dio());
  final List<String> log;
  final pending = <Completer<PushDeviceResult>>[];
  @override
  Future<PushDeviceResult> register({required String installationId, String? appVersion}) {
    log.add('PUT');
    final answer = Completer<PushDeviceResult>();
    pending.add(answer);
    return answer.future.then((r) {
      log.add('PUT ${r.status.name}');
      return r;
    });
  }
  void answer([PushDeviceResult result = const PushDeviceResult(PushDeviceStatus.registered, created: true)]) =>
      pending.removeAt(0).complete(result);
  @override
  Future<PushDeviceResult> unregister(String installationId) async => const PushDeviceResult(PushDeviceStatus.removed);
}

class FakeNotifier implements PushNotifier {
  FakeNotifier({this.allowed = false, this.grant = true});
  bool allowed, grant;
  int requests = 0;
  @override
  Future<void> prepare() async {}
  @override
  Future<bool> permitted() async => allowed;
  @override
  Future<bool> requestPermission() async {
    requests++;
    if (grant) allowed = true;
    return grant;
  }
  @override
  Future<void> show(PushEvent event) async {}
}

class MemoryPromptStore implements PushPromptStore {
  MemoryPromptStore([this.value = false]);
  bool value;
  @override
  Future<bool> asked() async => value;
  @override
  Future<void> markAsked() async => value = true;
}

class MemoryInstallationStore implements PushInstallationStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String installationId) async => value = installationId;
  @override
  Future<void> clear() async => value = null;
}

/// The explanation sheet: answered by the test.
class Presenter {
  int shown = 0;
  Completer<bool?>? open;
  Future<bool?> call() {
    shown++;
    return (open = Completer<bool?>()).future;
  }
}

class Profile extends ProfileRepository {
  Profile(this.log) : super(Dio());
  final List<String> log;
  @override
  Future<Map<String, dynamic>?> fetch() async => null;
  @override
  Future<List<Equipment>> equipment() async => const [Equipment(bodyWeightCode, 'Peso corporal', false)];
  @override
  Future<Map<String, dynamic>?> save(Map<String, dynamic> body, {required bool exists}) async {
    log.add('profile');
    return body;
  }
}

class Generation extends FakeGeneration {
  Generation(this.log) : super(starts: [operation('PENDING')], finds: [operation('PROCESSING')]);
  final List<String> log;
  @override
  Future<GenerationOperation> start() {
    log.add('generation');
    return super.start();
  }
}

class World {
  World({bool allowed = false, bool grant = true, bool asked = false, Object? registerError}) {
    messaging = FakeMessaging(registerError: registerError);
    devices = SlowDevices(log);
    notifier = FakeNotifier(allowed: allowed, grant: grant);
    promptStore = MemoryPromptStore(asked);
    push = PushController(messaging: messaging, devices: devices, notifier: notifier, store: MemoryInstallationStore(),
        onPlanChanged: () {}, open: (_) {});
    generation = Generation(log);
  }
  final log = <String>[];
  late final FakeMessaging messaging;
  late final SlowDevices devices;
  late final FakeNotifier notifier;
  late final MemoryPromptStore promptStore;
  late final PushController push;
  late final Generation generation;
  final presenter = Presenter();

  List<Override> get overrides => [
    authViewModelProvider.overrideWith(SignedIn.new),
    pushControllerProvider.overrideWithValue(push),
    pushNotifierProvider.overrideWithValue(notifier),
    pushMessagingProvider.overrideWithValue(messaging),
    pushPromptStoreProvider.overrideWithValue(promptStore),
    pushPromptPresenterProvider.overrideWithValue(presenter.call),
    planGenerationRepositoryProvider.overrideWithValue(generation),
    profileRepositoryProvider.overrideWithValue(Profile(log)),
  ];
}

Future<void> pumpOnboarding(WidgetTester tester, World world) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: '/onboarding', routes: [
    GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
    GoRoute(path: welcomeTourRoute, builder: (_, _) => const Scaffold(body: Text('Recorrido del usuario'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: world.overrides,
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light, locale: const Locale('es'),
        supportedLocales: const [Locale('es')], localizationsDelegates: GlobalMaterialLocalizations.delegates),
  ));
  await tester.pumpAndSettle();
}

Finder list() => find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text).hitTestable(), 200, scrollable: list());
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// The profile steps with valid data, then «Generar mi plan».
Future<void> fillAndGenerate(WidgetTester tester) async {
  tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text = 'Moverme más';
  await tapText(tester, 'Continuar');
  tester.widget<TextFormField>(find.descendant(of: find.byKey(const ValueKey('Estatura (cm)')), matching: find.byType(TextFormField))).controller!.text = '170';
  tester.widget<TextFormField>(find.descendant(of: find.byKey(const ValueKey('Peso actual (kg)')), matching: find.byType(TextFormField))).controller!.text = '70';
  tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('birthday')), matching: find.byType(EditableText))).controller.text = '1995-05-20';
  await tapText(tester, 'Continuar');
  await tapText(tester, 'Continuar');
  await tester.tap(find.widgetWithText(ChoiceChip, 'Casa'));
  await tester.pumpAndSettle();
  await tapText(tester, 'Continuar');
  await tester.scrollUntilVisible(find.text('Generar mi plan').hitTestable(), 200, scrollable: list());
  await tester.tap(find.text('Generar mi plan'));
  await tester.pump();
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('end of the profile setup, before the first plan', () {
    testWidgets('new user accepts: sheet, Android dialog, PUT 201, and only then the generation', (tester) async {
      final w = World();
      await w.push.onUser(7); // confirmed session (JWT stored), kept signed in throughout
      await pumpOnboarding(tester, w);
      await fillAndGenerate(tester);
      expect(w.presenter.shown, 1, reason: 'shown before anything is requested');
      expect(find.text('Generando...'), findsNothing, reason: 'the 30 s screen starts after the answer');
      expect(w.log, isEmpty);
      w.presenter.open!.complete(true);
      await settle(tester);
      expect(w.notifier.requests, 1);
      expect(find.text('Generando...'), findsOneWidget);
      expect(w.log, ['PUT', 'profile'], reason: 'the generation waits for the backend: the FID alone is not enough');
      expect(w.generation.startCalls, 0);
      w.devices.answer();
      await settle(tester);
      expect(w.log, ['PUT', 'profile', 'PUT registered', 'generation']);
      expect(w.push.state, PushState.registered);
      expect(w.promptStore.value, isTrue);
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('permission already granted (restored session, Android 12): no sheet, synchronised directly', (tester) async {
      final w = World(allowed: true);
      unawaited(w.push.onUser(7)); // restored session: its sync starts at app start
      await pumpOnboarding(tester, w);
      await fillAndGenerate(tester);
      await settle(tester);
      expect(w.presenter.shown, 0);
      expect(w.generation.startCalls, 0, reason: 'waits for the 200/201');
      w.devices.answer(const PushDeviceResult(PushDeviceStatus.registered));
      await settle(tester);
      expect(w.log.where((e) => e == 'PUT'), hasLength(1), reason: 'session sync and direct sync share one PUT');
      expect(w.log.last, 'generation');
      await tester.pump(const Duration(seconds: 31));
    });

    for (final (label, answer, grant) in [('«Ahora no»', false, true), ('Android refused', true, false)]) {
      testWidgets('$label: the generation goes on normally, nothing registered', (tester) async {
        final w = World(grant: grant);
        await w.push.onUser(7);
        await pumpOnboarding(tester, w);
        await fillAndGenerate(tester);
        w.presenter.open!.complete(answer);
        await settle(tester);
        expect(w.log, ['profile', 'generation']);
        expect(w.notifier.requests, answer ? 1 : 0);
        expect(find.text('Generando...'), findsOneWidget);
        await tester.pump(const Duration(seconds: 31));
      });
    }

    testWidgets('Firebase failing after «Activar avisos»: the generation goes on', (tester) async {
      final w = World(registerError: Exception('SERVICE_NOT_AVAILABLE'));
      await w.push.onUser(7);
      await pumpOnboarding(tester, w);
      await fillAndGenerate(tester);
      w.presenter.open!.complete(true);
      await settle(tester);
      expect(w.log, ['profile', 'generation']);
      expect(w.push.state, PushState.notRegisteredWithFcm);
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('already asked on this phone: not shown again', (tester) async {
      final w = World(asked: true);
      await w.push.onUser(7);
      await pumpOnboarding(tester, w);
      await fillAndGenerate(tester);
      await settle(tester);
      expect(w.presenter.shown, 0);
      expect(w.log, ['profile', 'generation']);
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('a generation already under way (app reopened mid-generation): not interrupted, no sheet', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'kora_welcome_7': jsonEncode({'operationId': operationId})});
      final w = World();
      await w.push.onUser(7);
      await pumpOnboarding(tester, w);
      await fillAndGenerate(tester);
      await settle(tester);
      expect(w.presenter.shown, 0);
      expect(find.text('Generando...'), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
    });
  });

  test('without a confirmed session (account just created, no JWT) accepting never sends a PUT', () async {
    final w = World();
    // No onUser: register() leaves the user signed out until the login.
    final prompt = PushPermissionPrompt(notifier: w.notifier, store: w.promptStore, presenter: () async => true,
        onGranted: () => w.push.onResumed(), supported: true);
    expect(await prompt.beforeFirstPlan(), PushPermissionOutcome.granted);
    await Future<void>.delayed(Duration.zero);
    expect(w.log, isEmpty);
    expect(w.messaging.registers, 0);
  });

  test('generation already started: beforeFirstPlan shows nothing and asks nothing', () async {
    final w = World();
    final prompt = PushPermissionPrompt(notifier: w.notifier, store: w.promptStore, presenter: w.presenter.call,
        onGranted: () async {}, supported: true);
    expect(await prompt.beforeFirstPlan(generationStarted: true), PushPermissionOutcome.notShown);
    expect(w.presenter.shown, 0);
    expect(w.notifier.requests, 0);
    expect(w.promptStore.value, isFalse, reason: 'still owed for a later first plan');
  });
}
