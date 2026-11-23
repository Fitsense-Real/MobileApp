import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/secure_storage.dart';
import '../../authentication/presentation/state/auth_state.dart';
import '../../plans/data/plan_repository.dart';
import '../../reminders/presentation/reminders_controller.dart';
import '../../welcome/presentation/first_plan_generation_controller.dart';
import '../data/push_device_repository.dart';
import '../data/push_messaging.dart';
import '../data/push_notifier.dart';
import '../domain/push_event.dart';

/// Where push stands for the signed-in user (diagnostics, tests and the
/// preferences sheet).
enum PushState {
  /// Signed out, or not started yet.
  idle,

  /// No Firebase on this build or platform (web, CI, no configuration).
  unavailable,

  /// Android does not let Kora show notifications: nothing is registered
  /// until the user allows them (checked again when the app comes back).
  permissionMissing,

  /// FCM did not give an Installation ID: Google Play services older than the
  /// direct-send version, or a registration error. Retried on the next start.
  notRegisteredWithFcm,

  /// The backend has this phone for this account.
  registered,

  /// The backend refused or could not be reached; retried on the next start.
  backendError,
}

/// Remembers the last FID sent to the backend, so logout can unlink it even
/// in a run where FCM was not asked again.
abstract class PushInstallationStore {
  Future<String?> read();
  Future<void> write(String installationId);
  Future<void> clear();
}

class SecurePushInstallationStore implements PushInstallationStore {
  const SecurePushInstallationStore();
  static const _key = 'kora_push_installation_id';

  @override
  Future<String?> read() async {
    try {
      return await appSecureStorage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String installationId) async {
    try {
      await appSecureStorage.write(key: _key, value: installationId);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await appSecureStorage.delete(key: _key);
    } catch (_) {}
  }
}

/// Push notifications of the signed-in user (Backend PR #82 contract):
/// - after login and on every start with a session, `register()` with FCM;
///   each `onRegistered(fid)` is sent with `PUT /users/me/push-devices`;
/// - `onUnregistered(fid)` → `DELETE` with that FID;
/// - before logout: `DELETE` with the FID while the JWT is still valid, then
///   `unregister()` with FCM, so a shared phone never receives the previous
///   account's notifications even if the backend could not be reached;
/// - messages: dropped when repeated (`eventId`), shown while the app is open
///   (FCM does not), the plan reloaded when it changed, and a tap opens the
///   screen of `targetScreen`.
///
/// Nothing here can block login: every failure is recorded in [state] and
/// retried on the next start or when the app comes back to the foreground.
class PushController {
  PushController({
    required this.messaging,
    required this.devices,
    required this.notifier,
    required this.onPlanChanged,
    required this.open,
    this.store = const SecurePushInstallationStore(),
    this.appVersion,
  });

  final PushMessaging messaging;
  final PushDeviceRepository devices;
  final PushNotifier notifier;
  final PushInstallationStore store;
  final void Function() onPlanChanged;
  final void Function(String route) open;
  final String? appVersion;

  final _subscriptions = <StreamSubscription<Object?>>[];
  Future<bool>? _started;
  int? _userId;
  String? _installationId;
  String? _registeredFor;
  int _ownUnregisters = 0;
  final _shown = _RecentIds();
  final _opened = _RecentIds();

  PushState state = PushState.idle;

  /// Last backend answer, for diagnostics and tests.
  PushDeviceResult? lastResult;

  Future<bool> _start() => _started ??= () async {
    if (!await messaging.start()) return false;
    await notifier.prepare();
    _subscriptions
      ..add(messaging.onRegistered.listen(_onRegistered))
      ..add(messaging.onUnregistered.listen(_onUnregistered))
      ..add(messaging.onForegroundMessage.listen(_foreground))
      ..add(messaging.onOpened.listen(_openedEvent));
    final initial = await messaging.initialEvent();
    if (initial != null) _openedEvent(initial);
    return true;
  }();

  /// How long the first-plan generation waits for this phone's registration
  /// (FID from FCM + the backend's 200/201) before going on without it.
  static Duration syncTimeout = const Duration(seconds: 10);

  /// The registration attempt in progress for the signed-in user: completes
  /// with the resulting [state] once the backend answered (or the attempt
  /// ended without registering). Shared, so concurrent callers never start a
  /// second one.
  Future<PushState>? _sync;
  Completer<PushState>? _waitingForFid;

  /// PUT in flight, by `user:FID`: a repeated onRegistered joins it.
  (String, Future<void>)? _putting;

  /// Called with the user of a confirmed session, with its JWT stored (null
  /// when signed out): after login and when a stored session is restored.
  Future<void> onUser(int? userId) async {
    if (userId != _userId) _registeredFor = null; // another account: register again
    _userId = userId;
    if (userId == null) {
      state = PushState.idle;
      return;
    }
    await _syncNow();
  }

  /// The app came back to the foreground: retry what is missing (permission
  /// granted from the system dialog or settings, network back).
  Future<void> onResumed() async {
    if (_userId == null || state == PushState.registered || state == PushState.unavailable) return;
    await _syncNow();
  }

  /// Waits for the registration that the session started (at most
  /// [syncTimeout]) and returns how it ended. Used before the automatic
  /// first-plan generation, so PLAN_GENERATED finds this phone registered.
  /// Never starts Firebase by itself and never throws: without a session,
  /// without permission or with Firebase or the backend failing it returns
  /// at once (or at the timeout) and the app carries on.
  Future<PushState> ensureSynced() async {
    final sync = _sync;
    if (_userId == null || sync == null) return state;
    return sync.timeout(syncTimeout, onTimeout: () {
      debugPrint('Registro push sin respuesta a tiempo (${state.name}); la app continúa y se reintentará.');
      return state;
    });
  }

  Future<PushState> _syncNow() => _sync = _register().catchError((Object e) {
    debugPrint('Registro push no disponible: $e');
    return state = PushState.notRegisteredWithFcm;
  });

  Future<PushState> _register() async {
    if (!await _start()) return state = PushState.unavailable;
    if (!await notifier.permitted()) {
      debugPrint('Registro push pendiente: sin permiso de notificaciones.');
      return state = PushState.permissionMissing;
    }
    // FCM answers through onRegistered (also when already registered); the
    // attempt is only over once the backend answered the PUT.
    final waiter = _waitingForFid ??= Completer<PushState>();
    try {
      await messaging.register();
    } catch (e) {
      if (identical(_waitingForFid, waiter)) _waitingForFid = null;
      debugPrint('Registro FCM no disponible: $e');
      return state = PushState.notRegisteredWithFcm;
    }
    return waiter.future;
  }

  Future<void> _onRegistered(String installationId) async {
    final work = _registerInstallation(installationId);
    // A new FID reported by Firebase on its own is also "the" sync to wait for.
    if (_waitingForFid == null && _userId != null) _sync = work.then((_) => state, onError: (_) => state);
    try {
      await work;
    } finally {
      final waiter = _waitingForFid;
      _waitingForFid = null;
      if (waiter != null && !waiter.isCompleted) waiter.complete(state);
    }
  }

  Future<void> _registerInstallation(String installationId) async {
    final userId = _userId;
    if (userId == null) return;
    if (!PushDeviceRepository.isInstallationId(installationId)) {
      // A registration token instead of an FID (Google Play services without
      // direct send): the backend would refuse it, so it is not sent.
      state = PushState.notRegisteredWithFcm;
      debugPrint('FCM no entregó un Installation ID; no se registra en el backend.');
      return;
    }
    _installationId = installationId;
    final key = '$userId:$installationId';
    if (_registeredFor == key && state == PushState.registered) return;
    final putting = _putting;
    if (putting != null && putting.$1 == key) return putting.$2; // same PUT in flight: join it
    final put = _put(userId, installationId, key);
    _putting = (key, put);
    try {
      await put;
    } finally {
      if (identical(_putting?.$2, put)) _putting = null;
    }
  }

  Future<void> _put(int userId, String installationId, String key) async {
    final result = await devices.register(installationId: installationId, appVersion: appVersion);
    if (_userId != userId) return; // logged out meanwhile
    lastResult = result;
    if (result.status == PushDeviceStatus.registered) {
      _registeredFor = key;
      state = PushState.registered;
      await store.write(installationId);
    } else {
      state = PushState.backendError;
      debugPrint('El backend no registró este teléfono (${result.status.name}${result.code == null ? '' : ' ${result.code}'}); se reintentará.');
    }
    // Debug builds only: the FID, to follow the end-to-end test
    // (docs/push/PRUEBAS_PUSH_E_IDENTIFICADOR.md). Never printed in release.
    if (kDebugMode) debugPrint('FCM installation ID (${result.status.name}${result.code == null ? '' : ' ${result.code}'}): $installationId');
  }

  Future<void> _onUnregistered(String installationId) async {
    // The confirmation of our own unregister() at logout can arrive after the
    // next account has signed in: it must not unlink that account.
    if (_ownUnregisters > 0) {
      _ownUnregisters--;
      return;
    }
    if (_installationId == installationId) _installationId = null;
    _registeredFor = null;
    if (_userId == null) return;
    state = PushState.idle;
    if (PushDeviceRepository.isInstallationId(installationId)) lastResult = await devices.unregister(installationId);
  }

  void _foreground(PushEvent event) {
    if (!_shown.add(event.eventId)) return;
    if (event.changesPlan) onPlanChanged();
    notifier.show(event);
  }

  void _openedEvent(PushEvent event) {
    if (!_opened.add(event.eventId)) return;
    if (event.changesPlan) onPlanChanged();
    open(event.route);
  }

  /// Before the session ends (logout, expired session, deleted account),
  /// while the JWT is still stored.
  Future<void> beforeLogout() async {
    _userId = null;
    _registeredFor = null;
    _sync = null;
    state = PushState.idle;
    final installationId = _installationId ?? await store.read();
    _installationId = null;
    if (PushDeviceRepository.isInstallationId(installationId)) {
      lastResult = await devices.unregister(installationId!);
      if (lastResult!.status != PushDeviceStatus.removed) {
        // Recorded so the failure is visible; the phone still stops receiving:
        // FCM unregister below, and the backend unlinks the FID on the next
        // send (UNREGISTERED) or when another account registers it.
        debugPrint('No se pudo desvincular este teléfono en el backend (${lastResult!.status.name}); se anula el registro en FCM.');
      }
    }
    await store.clear();
    // Whatever the backend answered, FCM stops delivering to this phone until
    // the next login registers it again.
    var asked = false;
    try {
      // Only if push was started in this run (it always is with a session:
      // onUser starts it). Never initialise Firebase just to log out.
      final started = _started;
      if (started != null && await started) {
        _ownUnregisters++;
        asked = true;
        await messaging.unregister();
      }
    } catch (_) {
      if (asked) _ownUnregisters--; // no confirmation will come
    }
  }

  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
  }
}

/// The last event ids seen, to drop repeated deliveries of the same event.
class _RecentIds {
  final _ids = <String>{}; // insertion-ordered (LinkedHashSet)

  /// False when [id] was already seen. Events without an id always pass.
  bool add(String? id) {
    if (id == null) return true;
    if (!_ids.add(id)) return false;
    if (_ids.length > 50) _ids.remove(_ids.first);
    return true;
  }
}

/// The user whose phone push registers: only a confirmed session, with its
/// JWT stored (login or restored session). The account just created by
/// register has no JWT yet, so nothing is sent for it until it logs in.
int? pushSessionUserId(AuthState auth) => auth.isAuthenticated ? auth.user?.id : null;

/// Overridden in tests; the real one talks to Firebase (Android only).
final pushMessagingProvider = Provider<PushMessaging>((ref) => FirebasePushMessaging());

final pushNotifierProvider = Provider<PushNotifier>((ref) => LocalPushNotifier(onTap: (payload) => pushRouter?.call(reminderRoute(payload))));

/// Navigation used when a notification is tapped; set by the app.
void Function(String route)? pushRouter;

final pushControllerProvider = Provider<PushController>((ref) {
  final controller = PushController(
    messaging: ref.read(pushMessagingProvider),
    devices: ref.read(pushDeviceRepositoryProvider),
    notifier: ref.read(pushNotifierProvider),
    onPlanChanged: () {
      ref.invalidate(currentPlanProvider);
      final generation = ref.read(firstPlanGenerationProvider);
      if (generation.isWaiting) ref.read(firstPlanGenerationProvider.notifier).refresh();
    },
    open: (route) => pushRouter?.call(route),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Perfil → Avisos en el teléfono: the account's notification preferences
/// (applied by the backend when sending).
class NotificationPreferencesController extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() => ref.read(pushDeviceRepositoryProvider).preferences();

  /// Saves both categories; on failure the previous value stays and the error is rethrown.
  Future<void> save(NotificationPreferences next) async {
    final previous = state.value;
    state = AsyncData(next);
    try {
      state = AsyncData(await ref.read(pushDeviceRepositoryProvider).savePreferences(next));
    } catch (_) {
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }
}

final notificationPreferencesProvider =
    AsyncNotifierProvider.autoDispose<NotificationPreferencesController, NotificationPreferences>(NotificationPreferencesController.new);
