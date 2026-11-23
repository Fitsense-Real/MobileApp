import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/router/app_router.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/notification_settings.dart';
import '../data/push_messaging.dart';
import '../data/push_notifier.dart';
import 'push_controller.dart';

/// What happened with the contextual notification-permission request.
enum PushPermissionOutcome {
  /// Android already lets Kora show notifications: nothing to ask.
  alreadyGranted,

  /// Asked on an earlier run (or earlier login) on this phone: never asked
  /// again automatically. It can be turned on from Perfil → Avisos en el teléfono.
  askedBefore,

  /// The user accepted the explanation and Android granted the permission.
  granted,

  /// The user accepted the explanation, but Android's dialog was refused.
  denied,

  /// The user chose «Ahora no» in the explanation (no system dialog shown).
  declined,

  /// Not applicable: not Android, or there is no screen to show it on.
  notShown;

  /// The user said no on this phone (now or before): the shared permission
  /// must not be requested again automatically, not even by the reminders.
  bool get refused => this == denied || this == declined;
}

/// Remembers, per phone (not per account), that the explanation was shown.
abstract class PushPromptStore {
  Future<bool> asked();
  Future<void> markAsked();
}

class SecurePushPromptStore implements PushPromptStore {
  const SecurePushPromptStore();
  static const _key = 'kora_push_permission_prompted';

  @override
  Future<bool> asked() async {
    try {
      return await appSecureStorage.read(key: _key) == 'true';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markAsked() async {
    try {
      await appSecureStorage.write(key: _key, value: 'true');
    } catch (_) {}
  }
}

/// Shows the explanation and returns true for «Activar avisos», false for
/// «Ahora no», null when it could not be shown.
typedef PushPromptPresenter = Future<bool?> Function();

/// Asks for Android's notification permission once per phone, at the end of
/// the profile setup and before the first plan is requested, explaining first
/// what push notifications are for, so the PLAN_GENERATED notice of the first
/// plan can reach this phone. Independent of the workout reminders: a user
/// with reminders off still gets plan and account notices, and the answer
/// never changes the reminders' settings.
///
/// [ask] is idempotent per run: one explanation and one system dialog.
class PushPermissionPrompt {
  PushPermissionPrompt({
    required this.notifier,
    required this.store,
    required this.presenter,
    required this.onGranted,
    bool? supported,
  }) : supported = supported ?? FirebasePushMessaging.supported;

  final PushNotifier notifier;
  final PushPromptStore store;
  final PushPromptPresenter presenter;
  final Future<void> Function() onGranted;
  final bool supported;

  Future<PushPermissionOutcome>? _asking;

  /// Last outcome of this run, if any.
  PushPermissionOutcome? outcome;

  /// Whether the explanation was ever shown on this phone (any answer).
  Future<bool> shownOnThisPhone() async {
    try {
      return await store.asked();
    } catch (_) {
      return false;
    }
  }

  /// End of the profile setup, right before the first generation is
  /// requested. Never shown while a generation is already under way (it
  /// would interrupt it). With the permission already granted nothing is
  /// shown and this phone is synchronised at once. The generation itself
  /// then waits for the backend's 200/201 (FirstPlanGenerationController).
  Future<PushPermissionOutcome> beforeFirstPlan({bool generationStarted = false}) async {
    if (generationStarted) return PushPermissionOutcome.notShown;
    final outcome = await ask();
    if (outcome == PushPermissionOutcome.alreadyGranted) {
      try {
        await onGranted();
      } catch (_) {}
    }
    return outcome;
  }

  Future<PushPermissionOutcome> ask() => _asking ??= _ask().then((value) {
    outcome = value;
    // Not shown (no screen yet): allow a later attempt in this run.
    if (value == PushPermissionOutcome.notShown) _asking = null;
    return value;
  });

  Future<PushPermissionOutcome> _ask() async {
    if (!supported) return PushPermissionOutcome.notShown;
    try {
      if (await notifier.permitted()) return PushPermissionOutcome.alreadyGranted;
      if (await store.asked()) return PushPermissionOutcome.askedBefore;
      final accepted = await presenter();
      if (accepted == null) return PushPermissionOutcome.notShown;
      await store.markAsked();
      if (!accepted) return PushPermissionOutcome.declined;
      if (!await notifier.requestPermission()) return PushPermissionOutcome.denied;
      await onGranted();
      return PushPermissionOutcome.granted;
    } catch (_) {
      return PushPermissionOutcome.notShown;
    }
  }
}

/// The explanation shown before Android's dialog.
class PushPermissionSheet extends StatelessWidget {
  const PushPermissionSheet({super.key});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.notifications_active_outlined, size: 36),
        const SizedBox(height: 12),
        const Text('¿Te avisamos cuando haya novedades?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const Text('Kora te enviará un aviso cuando tu plan esté listo o se actualice, y si hay algo importante sobre la '
            'seguridad de tu cuenta. Los avisos no incluyen datos de tu salud.'),
        const SizedBox(height: 10),
        const Text('Puedes elegir qué avisos recibir en Perfil → Avisos en el teléfono. Los recordatorios de entrenamiento '
            'se configuran aparte.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Activar avisos')),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Ahora no')),
        ),
      ]),
    ),
  );
}

/// Overridden in tests.
final pushPromptStoreProvider = Provider<PushPromptStore>((ref) => const SecurePushPromptStore());

/// Shows [PushPermissionSheet] on the app's navigator; null when the app is
/// not on screen (tests that build a single page, background).
final pushPromptPresenterProvider = Provider<PushPromptPresenter>((ref) => () async {
  final context = AppRouter.navigatorKey.currentContext;
  if (context == null || !context.mounted) return null;
  final accepted = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const PushPermissionSheet(),
  );
  return accepted ?? false; // dismissed = «Ahora no»
});

final pushPermissionPromptProvider = Provider<PushPermissionPrompt>((ref) => PushPermissionPrompt(
  notifier: ref.read(pushNotifierProvider),
  store: ref.read(pushPromptStoreProvider),
  presenter: ref.read(pushPromptPresenterProvider),
  // Register this phone right away instead of waiting for the next start.
  // Started, not awaited: the profile setup goes on to the generation screen,
  // and the generation request itself waits for the backend's 200/201
  // (PushController.ensureSynced).
  onGranted: () async => unawaited(ref.read(pushControllerProvider).onResumed()),
));

/// Whether Android currently lets Kora show notifications (shared by push
/// and the workout reminders).
final notificationPermissionProvider = FutureProvider.autoDispose<bool>((ref) => ref.read(pushNotifierProvider).permitted());

/// «Activar notificaciones» (Perfil → Avisos en el teléfono, Perfil →
/// Recordatorios): Android's dialog when it may still be shown; after a
/// refusal Android only allows it from the system settings, opened instead.
/// Only the OS permission changes: no reminder or push preference is touched.
Future<void> enableNotificationPermission(WidgetRef ref) async {
  final granted = await ref.read(pushNotifierProvider).requestPermission();
  if (granted) {
    await ref.read(pushControllerProvider).onResumed();
  } else {
    await ref.read(notificationSettingsLauncherProvider).open();
  }
  ref.invalidate(notificationPermissionProvider);
}
