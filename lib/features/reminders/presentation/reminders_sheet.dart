import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/reminder_planner.dart';
import 'reminders_controller.dart';

String formatTime(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Perfil → Recordatorios.
class RemindersSheet extends ConsumerWidget {
  const RemindersSheet({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref, ReminderSettings next) async {
    final granted = await ref.read(remindersControllerProvider.notifier).save(next);
    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Kora no tiene permiso para enviarte notificaciones. Actívalo en los ajustes del teléfono.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(remindersControllerProvider).asData?.value;
    return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
      const Text('Recordatorios', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Te avisamos los días que tienes entrenamiento y cuando tu plan de la semana está listo. Si ya registraste un entrenamiento, su aviso se cancela.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      if (settings == null)
        const LinearProgressIndicator()
      else ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Recordarme mis entrenamientos'),
          value: settings.enabled,
          onChanged: (value) => _save(context, ref, settings.copyWith(enabled: value)),
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
              await _save(context, ref, settings.copyWith(hour: picked.hour, minute: picked.minute));
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Avisarme a las ${formatTime(dueWarningHour, 0)} si sigue pendiente'),
          subtitle: const Text('El entrenamiento vence a las 23:59 de ese día.'),
          value: settings.dueWarning,
          onChanged: settings.enabled ? (value) => _save(context, ref, settings.copyWith(dueWarning: value)) : null,
        ),
        if (settings.enabled && settings.hour * 60 + settings.minute >= dueWarningHour * 60)
          const Text('Con un aviso a partir de las 20:00 no se envía el segundo aviso.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    ]);
  }
}
