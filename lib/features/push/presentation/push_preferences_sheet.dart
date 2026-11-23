import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/push_device_repository.dart';
import 'push_controller.dart';
import 'push_permission_prompt.dart';

/// Perfil → Avisos en el teléfono: whether the phone lets Kora notify, and
/// which push notifications the account receives (the backend applies the
/// preferences when sending, Backend PR #82). Independent of the workout
/// reminders, which have their own sheet and are not affected.
class PushPreferencesSheet extends ConsumerStatefulWidget {
  const PushPreferencesSheet({super.key});

  @override
  ConsumerState<PushPreferencesSheet> createState() => _PushPreferencesSheetState();
}

class _PushPreferencesSheetState extends ConsumerState<PushPreferencesSheet> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the system settings: show the new state.
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(notificationPermissionProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _save(NotificationPreferences next) async {
    try {
      await ref.read(notificationPreferencesProvider.notifier).save(next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pudimos guardar tus preferencias. Revisa tu conexión e inténtalo de nuevo.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(notificationPreferencesProvider);
    final permitted = ref.watch(notificationPermissionProvider).asData?.value;
    return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), shrinkWrap: true, children: [
      const Text('Avisos en el teléfono', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Notificaciones que Kora te envía cuando cambia tu plan o hay un aviso de seguridad. No incluyen datos de tu salud. '
          'Son independientes de los recordatorios de entrenamiento.',
          style: TextStyle(color: Colors.black54)),
      if (permitted == false) ...[
        const SizedBox(height: 12),
        Container(
          key: const Key('push-permission-off'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF3F1E8), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Las notificaciones de Kora están desactivadas en este teléfono.', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Kora funciona igual, pero no podrá avisarte. Puedes activarlas cuando quieras.'),
            TextButton(onPressed: () => enableNotificationPermission(ref), child: const Text('Activar notificaciones')),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      preferences.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('No pudimos cargar tus preferencias.'),
          TextButton(onPressed: () => ref.invalidate(notificationPreferencesProvider), child: const Text('Reintentar')),
        ]),
        data: (p) => Column(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Cambios en mi plan'),
            subtitle: const Text('Plan listo, ajustes y nueva semana.'),
            value: p.planUpdates,
            onChanged: (value) => _save(p.copyWith(planUpdates: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisos de seguridad de mi cuenta'),
            subtitle: const Text('Por ejemplo, si se cambia tu contraseña.'),
            value: p.accountNotices,
            onChanged: (value) => _save(p.copyWith(accountNotices: value)),
          ),
        ]),
      ),
    ]);
  }
}
