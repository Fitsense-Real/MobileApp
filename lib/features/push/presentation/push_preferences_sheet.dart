import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/push_device_repository.dart';
import 'push_controller.dart';

/// Perfil → Avisos en el teléfono: which push notifications the account
/// receives. The backend applies them when sending (Backend PR #82); the
/// workout reminders have their own sheet and are not affected.
class PushPreferencesSheet extends ConsumerWidget {
  const PushPreferencesSheet({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref, NotificationPreferences next) async {
    try {
      await ref.read(notificationPreferencesProvider.notifier).save(next);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pudimos guardar tus preferencias. Revisa tu conexión e inténtalo de nuevo.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), shrinkWrap: true, children: [
      const Text('Avisos en el teléfono', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Notificaciones que Kora te envía cuando cambia tu plan o hay un aviso de seguridad. No incluyen datos de tu salud.',
          style: TextStyle(color: Colors.black54)),
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
            onChanged: (value) => _save(context, ref, p.copyWith(planUpdates: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisos de seguridad de mi cuenta'),
            subtitle: const Text('Por ejemplo, si se cambia tu contraseña.'),
            value: p.accountNotices,
            onChanged: (value) => _save(context, ref, p.copyWith(accountNotices: value)),
          ),
        ]),
      ),
    ]);
  }
}
