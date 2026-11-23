import 'dart:async';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/authentication/domain/entities/user.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/push/data/notification_settings.dart';
import 'package:fitsense_mobile/features/push/data/push_device_repository.dart';
import 'package:fitsense_mobile/features/push/data/push_messaging.dart';
import 'package:fitsense_mobile/features/push/data/push_notifier.dart';
import 'package:fitsense_mobile/features/push/domain/push_event.dart';
import 'package:fitsense_mobile/features/push/presentation/push_controller.dart';
import 'package:fitsense_mobile/features/push/presentation/push_permission_prompt.dart';
import 'package:fitsense_mobile/features/push/presentation/push_preferences_sheet.dart';
import 'package:fitsense_mobile/features/reminders/data/reminder_scheduler.dart';
import 'package:fitsense_mobile/features/reminders/domain/reminder_planner.dart';
import 'package:fitsense_mobile/features/reminders/presentation/reminders_controller.dart';

// Push permission independent of the workout reminders. Everything simulated.

const fid = 'cR_9l0aBcD3fGh1jK2lM4n';

/// Android's notification permission: off until the dialog grants it.
class FakeNotifier implements PushNotifier {
  FakeNotifier({this.allowed = false, this.grant = true});
  bool allowed;
  bool grant;
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

/// Counts how often the explanation is shown and answers with [answer].
class Presenter {
  Presenter([this.answer = true]);
  bool? answer;
  int shown = 0;
  Future<bool?> call() async {
    shown++;
    return answer;
  }
}

class FakeMessaging implements PushMessaging {
  final registered = StreamController<String>.broadcast();
  int registers = 0;
  @override
  Future<bool> start() async => true;
  @override
  Future<void> register() async {
    registers++;
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

class FakeDevices extends PushDeviceRepository {
  FakeDevices() : super(Dio());
  final registered = <String>[];
  @override
  Future<PushDeviceResult> register({required String installationId, String? appVersion}) async {
    registered.add(installationId);
    return const PushDeviceResult(PushDeviceStatus.registered);
  }
  @override
  Future<PushDeviceResult> unregister(String installationId) async => const PushDeviceResult(PushDeviceStatus.removed);
  @override
  Future<NotificationPreferences> preferences() async => const NotificationPreferences(planUpdates: true, accountNotices: true);
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

class FakeScheduler implements ReminderScheduler {
  int permissionRequests = 0, cancels = 0;
  List<PlannedReminder>? scheduled;
  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }
  @override
  Future<void> replaceAll(List<PlannedReminder> reminders, {String? timezone}) async => scheduled = reminders;
  @override
  Future<void> cancelAll() async {
    cancels++;
    scheduled = const [];
  }
  @override
  DateTime nowIn(String? timezone) => DateTime(2026, 11, 5, 10);
}

class ReminderStore extends ReminderSettingsStore {
  ReminderStore([this.value]);
  ReminderSettings? value;
  @override
  Future<ReminderSettings> load(int userId) async => value ?? const ReminderSettings();
  @override
  Future<void> save(int userId, ReminderSettings settings) async => value = settings;
}

class SignedIn extends AuthViewModel {
  @override
  AuthState build() => const AuthState(isAuthenticated: true, user: User(id: 7, firstName: 'Ana', lastName: 'Demo', email: 'a@b.com', timezone: 'America/Lima'));
}

class FakeLauncher extends NotificationSettingsLauncher {
  int opened = 0;
  @override
  Future<bool> open() async {
    opened++;
    return true;
  }
}

Json plan() => {'planId': 3, 'weekStartDate': '2026-11-02', 'weekEndDate': '2026-11-08', 'workouts': [
  {'plannedWorkoutId': 21, 'scheduledDate': '2026-11-06', 'workoutName': 'Piernas', 'focusCode': 'LOWER_BODY',
   'expectedDurationMinutes': 40, 'status': 'SCHEDULED', 'safetyBlocked': false, 'exercises': []},
]};

Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('contextual permission prompt (once per phone)', () {
    late FakeNotifier notifier;
    late MemoryPromptStore store;
    late Presenter presenter;
    late int grantedCallbacks;
    PushPermissionPrompt build({bool allowed = false, bool grant = true, bool asked = false, bool? answer = true, bool supported = true}) {
      notifier = FakeNotifier(allowed: allowed, grant: grant);
      store = MemoryPromptStore(asked);
      presenter = Presenter(answer);
      grantedCallbacks = 0;
      return PushPermissionPrompt(notifier: notifier, store: store, presenter: presenter.call,
          onGranted: () async => grantedCallbacks++, supported: supported);
    }

    test('explains first, then Android\'s dialog; granted registers push right away', () async {
      final prompt = build();
      expect(await prompt.ask(), PushPermissionOutcome.granted);
      expect(presenter.shown, 1);
      expect(notifier.requests, 1);
      expect(store.value, isTrue);
      expect(grantedCallbacks, 1);
    });

    test('never asked again: not in the same run, not after the next login or start', () async {
      final prompt = build(grant: false);
      expect(await prompt.ask(), PushPermissionOutcome.denied);
      expect(await prompt.ask(), PushPermissionOutcome.denied);
      final nextLogin = PushPermissionPrompt(notifier: notifier, store: store, presenter: presenter.call, onGranted: () async {}, supported: true);
      expect(await nextLogin.ask(), PushPermissionOutcome.askedBefore);
      expect(presenter.shown, 1);
      expect(notifier.requests, 1);
      expect(PushPermissionOutcome.denied.refused, isTrue);
    });

    test('«Ahora no»: no system dialog, Kora carries on, remembered', () async {
      final prompt = build(answer: false);
      expect(await prompt.ask(), PushPermissionOutcome.declined);
      expect(notifier.requests, 0);
      expect(store.value, isTrue);
      expect(grantedCallbacks, 0);
    });

    test('already allowed (Android < 13 or granted before): nothing is shown', () async {
      final prompt = build(allowed: true);
      expect(await prompt.ask(), PushPermissionOutcome.alreadyGranted);
      expect(presenter.shown, 0);
      expect(store.value, isFalse);
    });

    test('no screen to show it on: not recorded, tried again later in the run', () async {
      final prompt = build(answer: null);
      expect(await prompt.ask(), PushPermissionOutcome.notShown);
      expect(store.value, isFalse);
      presenter.answer = true;
      expect(await prompt.ask(), PushPermissionOutcome.granted);
    });

    test('outside Android nothing is asked', () async {
      final prompt = build(supported: false);
      expect(await prompt.ask(), PushPermissionOutcome.notShown);
      expect(presenter.shown, 0);
    });
  });

  group('reminders off, push on', () {
    late FakeNotifier notifier;
    late FakeScheduler scheduler;
    late ReminderStore reminders;
    late FakeMessaging messaging;
    late FakeDevices devices;
    late Presenter presenter;
    ProviderContainer container({ReminderSettings? settings, bool? answer = true, bool asked = false, bool grant = true}) {
      notifier = FakeNotifier(grant: grant);
      scheduler = FakeScheduler();
      reminders = ReminderStore(settings);
      messaging = FakeMessaging();
      devices = FakeDevices();
      presenter = Presenter(answer);
      final c = ProviderContainer(overrides: [
        authViewModelProvider.overrideWith(SignedIn.new),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        reminderSettingsStoreProvider.overrideWithValue(reminders),
        currentPlanProvider.overrideWith((ref) async => plan()),
        pushNotifierProvider.overrideWithValue(notifier),
        pushMessagingProvider.overrideWithValue(messaging),
        pushDeviceRepositoryProvider.overrideWithValue(devices),
        pushPromptStoreProvider.overrideWithValue(MemoryPromptStore(asked)),
        pushPromptPresenterProvider.overrideWithValue(presenter.call),
        pushControllerProvider.overrideWith((ref) => PushController(
          messaging: messaging, devices: devices, notifier: notifier, store: MemoryInstallationStore(),
          onPlanChanged: () {}, open: (_) {})),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('a user with reminders disabled accepts push: registered, reminders untouched', () async {
      const off = ReminderSettings(enabled: false, hour: 18, minute: 45, dueWarning: false, configured: true);
      final c = container(settings: off);
      c.listen(reminderSyncProvider, (_, _) {});
      final controller = c.read(pushControllerProvider);
      await controller.onUser(7);
      await settle();
      expect(controller.state, PushState.permissionMissing, reason: 'nothing registered before the permission');
      // First time on Inicio after the onboarding.
      expect(await c.read(pushPermissionPromptProvider).ask(), PushPermissionOutcome.granted);
      await settle();
      expect(devices.registered, [fid]);
      expect(controller.state, PushState.registered);
      // The reminders stay exactly as the user left them: off, same time, nothing scheduled, never asked.
      expect(reminders.value, off);
      expect(scheduler.permissionRequests, 0);
      expect(scheduler.scheduled, isEmpty);
    });

    test('a user with reminders disabled can enable push later from Perfil', () async {
      const off = ReminderSettings(enabled: false, configured: true);
      final c = container(settings: off, asked: true);
      final controller = c.read(pushControllerProvider);
      await controller.onUser(7);
      expect(await c.read(pushPermissionPromptProvider).ask(), PushPermissionOutcome.askedBefore, reason: 'not asked again');
      // Perfil → Avisos en el teléfono → Activar notificaciones.
      expect(await notifier.requestPermission(), isTrue);
      await controller.onResumed();
      await settle();
      expect(devices.registered, [fid]);
      expect(reminders.value, off);
    });

    test('first plan: one explanation and one system dialog for push and reminders', () async {
      final c = container();
      c.listen(reminderSyncProvider, (_, _) {});
      await settle();
      expect(presenter.shown, 1);
      expect(notifier.requests, 1, reason: 'the push explanation asked');
      // Reminders configured as before (on), their own request finds the permission granted.
      expect(reminders.value, const ReminderSettings(configured: true));
      expect(scheduler.scheduled, isNotEmpty);
    });

    test('first plan, «Ahora no»: no second dialog from the reminders, which start off', () async {
      final c = container(answer: false);
      c.listen(reminderSyncProvider, (_, _) {});
      await settle();
      expect(presenter.shown, 1);
      expect(notifier.requests, 0);
      expect(scheduler.permissionRequests, 0);
      expect(reminders.value?.configured, isTrue);
      expect(reminders.value?.enabled, isFalse);
    });

    test('first plan when the explanation cannot be shown: reminders ask as before', () async {
      final c = container(answer: null);
      c.listen(reminderSyncProvider, (_, _) {});
      await settle();
      expect(scheduler.permissionRequests, 1);
      expect(reminders.value, const ReminderSettings(configured: true));
    });
  });

  group('Perfil → Avisos en el teléfono', () {
    Future<(FakeNotifier, FakeLauncher)> open(WidgetTester tester, {required bool allowed, bool grant = false}) async {
      final notifier = FakeNotifier(allowed: allowed, grant: grant);
      final launcher = FakeLauncher();
      final devices = FakeDevices();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pushNotifierProvider.overrideWithValue(notifier),
          notificationSettingsLauncherProvider.overrideWithValue(launcher),
          pushDeviceRepositoryProvider.overrideWithValue(devices),
          pushControllerProvider.overrideWith((ref) => PushController(
            messaging: FakeMessaging(), devices: devices, notifier: notifier, store: MemoryInstallationStore(),
            onPlanChanged: () {}, open: (_) {})),
        ],
        child: const MaterialApp(home: Scaffold(body: PushPreferencesSheet())),
      ));
      await tester.pumpAndSettle();
      return (notifier, launcher);
    }

    testWidgets('notifications off: says so, and «Activar notificaciones» opens the system settings after a refusal', (tester) async {
      final (notifier, launcher) = await open(tester, allowed: false);
      expect(find.text('Las notificaciones de Kora están desactivadas en este teléfono.'), findsOneWidget);
      expect(find.text('Cambios en mi plan'), findsOneWidget, reason: 'preferences stay available');
      expect(find.text('Avisos de seguridad de mi cuenta'), findsOneWidget);
      await tester.tap(find.text('Activar notificaciones'));
      await tester.pumpAndSettle();
      expect(notifier.requests, 1);
      expect(launcher.opened, 1);
    });

    testWidgets('granted from the sheet: the notice disappears', (tester) async {
      final (_, launcher) = await open(tester, allowed: false, grant: true);
      await tester.tap(find.text('Activar notificaciones'));
      await tester.pumpAndSettle();
      expect(launcher.opened, 0);
      expect(find.byKey(const Key('push-permission-off')), findsNothing);
    });

    testWidgets('notifications on: only the two preferences', (tester) async {
      await open(tester, allowed: true);
      expect(find.byKey(const Key('push-permission-off')), findsNothing);
      expect(find.byType(SwitchListTile), findsNWidgets(2));
    });
  });

  testWidgets('the explanation: «Activar avisos» and «Ahora no»', (tester) async {
    bool? answer;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () async => answer = await showModalBottomSheet<bool>(context: context, builder: (_) => const PushPermissionSheet()),
      child: const Text('abrir'),
    )))));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tu plan esté listo o se actualice'), findsOneWidget);
    expect(find.textContaining('seguridad de tu cuenta'), findsOneWidget);
    await tester.ensureVisible(find.text('Activar avisos'));
    await tester.tap(find.text('Activar avisos'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ahora no'));
    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });
}
