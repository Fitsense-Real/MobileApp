import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/authentication/domain/entities/user.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/reminders/data/reminder_scheduler.dart';
import 'package:fitsense_mobile/features/reminders/domain/reminder_planner.dart';
import 'package:fitsense_mobile/features/reminders/presentation/reminders_controller.dart';
import 'package:fitsense_mobile/features/reminders/presentation/reminders_sheet.dart';

/// Thursday 2026-11-05 10:00 in the user's timezone.
final now = DateTime(2026, 11, 5, 10);

Json workout(int id, String date, {String status = 'SCHEDULED', bool blocked = false, String focus = 'LOWER_BODY'}) => {
  'plannedWorkoutId': id, 'scheduledDate': date, 'workoutName': 'Piernas $id', 'focusCode': focus,
  'expectedDurationMinutes': 40, 'status': status, 'safetyBlocked': blocked, 'exercises': [],
};

Json planWith(List<Json> workouts) => {'planId': 3, 'weekStartDate': '2026-11-02', 'weekEndDate': '2026-11-08', 'workouts': workouts};

class FakeScheduler implements ReminderScheduler {
  FakeScheduler({this.grant = true});
  bool grant;
  int permissionRequests = 0, cancels = 0;
  List<PlannedReminder>? scheduled;
  String? timezone;
  @override
  Future<bool> requestPermission() async { permissionRequests++; return grant; }
  @override
  Future<void> replaceAll(List<PlannedReminder> reminders, {String? timezone}) async { scheduled = reminders; this.timezone = timezone; }
  @override
  Future<void> cancelAll() async { cancels++; scheduled = const []; }
  @override
  DateTime nowIn(String? timezone) => now;
}

class MemoryStore extends ReminderSettingsStore {
  MemoryStore([this.value]);
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

Future<void> settle() async { for (var i = 0; i < 30; i++) { await Future<void>.delayed(Duration.zero); } }

void main() {
  group('planReminders', () {
    const settings = ReminderSettings(configured: true);

    test('a future open workout gets the day reminder and the due warning', () {
      final reminders = planReminders(planWith([workout(21, '2026-11-06')]), now: now, settings: settings);
      expect(reminders, [
        PlannedReminder(id: 42, at: DateTime(2026, 11, 6, 8), title: 'Hoy toca: Piernas 21',
            body: '40 min · Tren inferior. Ábrelo en Kora para empezar.', payload: 'workout:21'),
        PlannedReminder(id: 43, at: DateTime(2026, 11, 6, 20), title: 'Tu entrenamiento vence hoy',
            body: '«Piernas 21» vence a las 23:59. Si ya lo hiciste, regístralo en Kora.', payload: 'workout:21'),
      ]);
    });

    test('today after the reminder hour only keeps the due warning', () {
      final reminders = planReminders(planWith([workout(21, '2026-11-05')]), now: now, settings: settings);
      expect(reminders.map((r) => r.at), [DateTime(2026, 11, 5, 20)]);
    });

    test('past days and closed, replaced or blocked workouts never notify', () {
      final reminders = planReminders(planWith([
        workout(1, '2026-11-04'),
        workout(2, '2026-11-06', status: 'COMPLETED'),
        workout(3, '2026-11-06', status: 'PARTIAL'),
        workout(4, '2026-11-06', status: 'SKIPPED'),
        workout(5, '2026-11-06', status: 'REPLACED'),
        workout(6, '2026-11-06', blocked: true),
        workout(7, '2026-11-07', status: 'IN_PROGRESS'),
      ]), now: now, settings: settings);
      expect(reminders.map((r) => r.payload).toSet(), {'workout:7'});
    });

    test('disabled reminders, no plan, or an evening hour', () {
      final plan = planWith([workout(21, '2026-11-06')]);
      expect(planReminders(plan, now: now, settings: settings.copyWith(enabled: false)), isEmpty);
      expect(planReminders(null, now: now, settings: settings), isEmpty);
      final evening = planReminders(plan, now: now, settings: settings.copyWith(hour: 20, minute: 30));
      expect(evening.map((r) => r.title), ['Hoy toca: Piernas 21'], reason: 'no second warning after 20:00');
      expect(planReminders(plan, now: now, settings: settings.copyWith(dueWarning: false)).length, 1);
    });

    test('ordered by time and capped for iOS', () {
      final many = [for (var i = 0; i < 30; i++) workout(100 + i, DateTime(2026, 11, 6 + i).toIso8601String().substring(0, 10))];
      final reminders = planReminders(planWith(many.reversed.toList()), now: now, settings: settings);
      expect(reminders, hasLength(maxReminders));
      expect(reminders.first.at, DateTime(2026, 11, 6, 8));
      for (var i = 1; i < reminders.length; i++) {
        expect(reminders[i].at.isBefore(reminders[i - 1].at), isFalse);
      }
    });

    test('settings survive storage as JSON', () {
      const s = ReminderSettings(enabled: false, hour: 18, minute: 45, dueWarning: false, configured: true);
      expect(ReminderSettings.fromJson(s.toJson()), s);
      expect(ReminderSettings.fromJson({}), const ReminderSettings());
    });
  });

  group('sync with the plan', () {
    ProviderContainer container({required FakeScheduler scheduler, required MemoryStore store, required Json? Function() plan}) {
      final c = ProviderContainer(overrides: [
        authViewModelProvider.overrideWith(SignedIn.new),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        reminderSettingsStoreProvider.overrideWithValue(store),
        currentPlanProvider.overrideWith((ref) async => plan()),
      ]);
      addTearDown(c.dispose);
      c.listen(reminderSyncProvider, (_, __) {});
      return c;
    }

    test('first run asks permission once, then schedules in the user timezone', () async {
      final scheduler = FakeScheduler(); final store = MemoryStore();
      container(scheduler: scheduler, store: store, plan: () => planWith([workout(21, '2026-11-06')]));
      await settle();
      expect(scheduler.permissionRequests, 1);
      expect(store.value, const ReminderSettings(configured: true));
      expect(scheduler.scheduled, hasLength(2));
      expect(scheduler.timezone, 'America/Lima');
    });

    test('denied permission turns reminders off and schedules nothing', () async {
      final scheduler = FakeScheduler(grant: false); final store = MemoryStore();
      container(scheduler: scheduler, store: store, plan: () => planWith([workout(21, '2026-11-06')]));
      await settle();
      expect(store.value?.enabled, isFalse);
      expect(store.value?.configured, isTrue);
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.permissionRequests, 1, reason: 'the answer is remembered');
    });

    test('registering the workout removes its reminders on the next plan load', () async {
      final scheduler = FakeScheduler(); final store = MemoryStore(const ReminderSettings(configured: true));
      var status = 'SCHEDULED';
      final c = container(scheduler: scheduler, store: store, plan: () => planWith([workout(21, '2026-11-06', status: status)]));
      await settle();
      expect(scheduler.scheduled, hasLength(2));
      status = 'COMPLETED';
      c.invalidate(currentPlanProvider);
      await settle();
      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancels, 1);
      expect(scheduler.permissionRequests, 0, reason: 'already configured');
    });

    test('changing the hour reschedules', () async {
      final scheduler = FakeScheduler(); final store = MemoryStore(const ReminderSettings(configured: true));
      final c = container(scheduler: scheduler, store: store, plan: () => planWith([workout(21, '2026-11-06')]));
      await settle();
      await c.read(remindersControllerProvider.notifier).save(store.value!.copyWith(hour: 18, minute: 30));
      await settle();
      expect(scheduler.scheduled!.first.at, DateTime(2026, 11, 6, 18, 30));
      expect(store.value!.hour, 18);
    });

    test('logout cancels every reminder', () async {
      FlutterSecureStorage.setMockInitialValues({'access_token': 'jwt'});
      final scheduler = FakeScheduler();
      final c = ProviderContainer(overrides: [reminderSchedulerProvider.overrideWithValue(scheduler)]);
      addTearDown(c.dispose);
      await c.read(authViewModelProvider.notifier).logout();
      expect(scheduler.cancels, 1);
    });
  });

  group('Recordatorios sheet', () {
    Future<(FakeScheduler, MemoryStore)> open(WidgetTester tester, {bool grant = true, ReminderSettings? settings}) async {
      final scheduler = FakeScheduler(grant: grant);
      final store = MemoryStore(settings ?? const ReminderSettings(configured: true));
      await tester.pumpWidget(ProviderScope(overrides: [
        authViewModelProvider.overrideWith(SignedIn.new),
        reminderSchedulerProvider.overrideWithValue(scheduler),
        reminderSettingsStoreProvider.overrideWithValue(store),
      ], child: const MaterialApp(home: Scaffold(body: RemindersSheet()))));
      await tester.pumpAndSettle();
      return (scheduler, store);
    }

    testWidgets('shows the current settings and saves changes', (tester) async {
      final (_, store) = await open(tester);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Avisarme a las 20:00 si sigue pendiente'), findsOneWidget);
      await tester.tap(find.text('Avisarme a las 20:00 si sigue pendiente')); await tester.pumpAndSettle();
      expect(store.value?.dueWarning, isFalse);
      await tester.tap(find.text('Recordarme mis entrenamientos')); await tester.pumpAndSettle();
      expect(store.value?.enabled, isFalse);
    });

    testWidgets('turning reminders on without permission explains how to enable it', (tester) async {
      final (scheduler, store) = await open(tester, grant: false, settings: const ReminderSettings(enabled: false, configured: true));
      await tester.tap(find.text('Recordarme mis entrenamientos')); await tester.pumpAndSettle();
      expect(scheduler.permissionRequests, 1);
      expect(store.value?.enabled, isFalse);
      expect(find.textContaining('Actívalo en los ajustes del teléfono'), findsOneWidget);
    });
  });
}
