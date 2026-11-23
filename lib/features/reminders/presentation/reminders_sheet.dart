import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/reminder_planner.dart';
import '../../push/presentation/push_permission_prompt.dart';
import 'reminders_controller.dart';

String formatTime(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Perfil → Recordatorios.
class RemindersSheet extends ConsumerStatefulWidget {
  const RemindersSheet({super.key});

  @override
  ConsumerState<RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends ConsumerState<RemindersSheet> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the system settings: show whether notifications are on now.
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(notificationPermissionProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _RemindersView(onSave: (next) => _save(context, ref, next));

  Future<void> _save(BuildContext context, WidgetRef ref, ReminderSettings next) async {
    final granted = await ref.read(remindersControllerProvider.notifier).save(next);
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kora no tiene permiso para enviarte notificaciones. Actívalo en los ajustes del teléfono.'),
      ));
    }
  }
}

class _RemindersView extends ConsumerWidget {
  const _RemindersView({required this.onSave});
  final Future<void> Function(ReminderSettings next) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(remindersControllerProvider).asData?.value;
    // The OS permission is shared with push notifications: if it was turned
    // off, the reminders keep their settings and the user is told why they
    // do not arrive.
    final permitted = ref.watch(notificationPermissionProvider).asData?.value;
    return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
      const Text('Recordatorios', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Te avisamos los días que tienes entrenamiento y cuando tu plan de la semana está listo. Si ya registraste un entrenamiento, su aviso se cancela.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      if (settings == null)
        const LinearProgressIndicator()
      else ...[
        if (settings.enabled && permitted == false)
          Container(
            key: const Key('reminders-permission-off'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF3F1E8), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Activa las notificaciones para recibir tus recordatorios', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Las notificaciones de Kora están desactivadas en este teléfono. Tus días, tu horario y tus '
                  'preferencias se conservan: los recordatorios llegarán en cuanto las actives.'),
              TextButton(onPressed: () => enableNotificationPermission(ref), child: const Text('Activar notificaciones')),
            ]),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Recordarme mis entrenamientos'),
          value: settings.enabled,
          onChanged: (value) => onSave(settings.copyWith(enabled: value)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          enabled: settings.enabled,
          title: const Text('Hora del aviso'),
          subtitle: const Text('El día del entrenamiento'),
          trailing: Text(formatTime(settings.hour, settings.minute), style: const TextStyle(fontWeight: FontWeight.w800)),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
              helpText: 'Hora del aviso',
            );
            if (picked != null && context.mounted) {
              await onSave(settings.copyWith(hour: picked.hour, minute: picked.minute));
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Avisarme a las ${formatTime(dueWarningHour, 0)} si sigue pendiente'),
          subtitle: const Text('El entrenamiento vence a las 23:59 de ese día.'),
          value: settings.dueWarning,
          onChanged: settings.enabled ? (value) => onSave(settings.copyWith(dueWarning: value)) : null,
        ),
        if (settings.enabled && settings.hour * 60 + settings.minute >= dueWarningHour * 60)
          const Text('Con un aviso a partir de las 20:00 no se envía el segundo aviso.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    ]);
  }
}
