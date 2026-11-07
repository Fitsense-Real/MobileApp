import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../app/router/app_router.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../plans/data/plan_repository.dart';
import '../data/reminder_scheduler.dart';
import '../domain/reminder_planner.dart';

/// Device-local preferences, one entry per user.
class ReminderSettingsStore {
  const ReminderSettingsStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  String _key(int userId) => 'kora_reminders_$userId';

  Future<ReminderSettings> load(int userId) async {
    try {
      final raw = await _storage.read(key: _key(userId));
      return raw == null ? const ReminderSettings() : ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReminderSettings();
    }
  }

  Future<void> save(int userId, ReminderSettings settings) async {
    try {
      await _storage.write(key: _key(userId), value: jsonEncode(settings.toJson()));
    } catch (_) {/* keep the in-memory value */}
  }
}

final reminderSettingsStoreProvider = Provider((ref) => const ReminderSettingsStore());

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  // A workout reminder opens Rutinas; the new-plan reminder opens Inicio.
  (ref) => LocalNotificationScheduler(onTap: (payload) => AppRouter.router.go(reminderRoute(payload))),
);

/// Screen opened by tapping a reminder with [payload].
String reminderRoute(String? payload) =>
    payload != null && payload.startsWith('workout:') ? '/dashboard?tab=1' : '/dashboard';

class RemindersController extends AsyncNotifier<ReminderSettings> {
  int? get _userId => ref.read(authViewModelProvider).user?.id;

  @override
  Future<ReminderSettings> build() async {
    final userId = ref.watch(authViewModelProvider.select((s) => s.user?.id));
    if (userId == null) return const ReminderSettings();
    return ref.read(reminderSettingsStoreProvider).load(userId);
  }

  /// Saves [next]. Turning reminders on asks the OS for permission; if it is
  /// denied, reminders stay off and this returns false.
  Future<bool> save(ReminderSettings next) async {
    final current = state.asData?.value ?? const ReminderSettings();
    var settings = next.copyWith(configured: true);
    var granted = true;
    if (settings.enabled && (!current.enabled || !current.configured)) {
      granted = await ref.read(reminderSchedulerProvider).requestPermission();
      if (!granted) settings = settings.copyWith(enabled: false);
    }
    final userId = _userId;
    if (userId != null) await ref.read(reminderSettingsStoreProvider).save(userId, settings);
    state = AsyncData(settings);
    return granted;
  }
}

final remindersControllerProvider =
    AsyncNotifierProvider<RemindersController, ReminderSettings>(RemindersController.new);

/// Keeps device reminders in sync with the current plan and the settings.
/// Re-runs whenever either changes (e.g. after registering a workout the
/// plan reloads and its reminders disappear). Returns how many were set.
final reminderSyncProvider = FutureProvider.autoDispose<int>((ref) async {
  final user = ref.watch(authViewModelProvider.select((s) => s.user));
  final scheduler = ref.watch(reminderSchedulerProvider);
  if (user == null) return 0;
  // Dependencies are registered before any await.
  final settingsFuture = ref.watch(remindersControllerProvider.future);
  final planFuture = ref.watch(currentPlanProvider.future);
  planFuture.ignore(); // an early return must not leave its error unhandled
  // Reminders are best effort: never fail (Riverpod would retry with timers).
  try {
    final settings = await settingsFuture;
    if (!settings.configured) {
      // First time with a plan: ask once; the answer is remembered.
      await ref.read(remindersControllerProvider.notifier).save(settings);
      return 0; // the settings change triggers a new sync
    }
    final plan = await planFuture;
    final reminders = planReminders(plan, now: scheduler.nowIn(user.timezone), settings: settings);
    if (reminders.isEmpty) {
      await scheduler.cancelAll();
    } else {
      await scheduler.replaceAll(reminders, timezone: user.timezone);
    }
    return reminders.length;
  } catch (_) {
    return 0;
  }
});
