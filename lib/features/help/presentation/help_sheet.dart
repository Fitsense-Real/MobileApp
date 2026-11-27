import 'package:material_ui/material_ui.dart';
import '../../../core/config/study_config.dart';
import '../../../shared/widgets/kora_ui.dart';

/// «Ayuda y soporte» (M-40): how to use Kora's own screens and who to contact.
/// It explains the app only: no medical advice is written here; the approved
/// safety message appears only when the study team provides it (M-24).
class HelpSheet extends StatelessWidget {
  const HelpSheet({super.key, this.contact = StudyConfig.contact, this.painSafetyMessage = StudyConfig.painSafetyMessage});
  final String contact;
  final String painSafetyMessage;

  static const questions = <(String, String)>[
    ('¿Cómo registro un entrenamiento?', 'Abre la rutina del día en Rutinas y pulsa «Comenzar entrenamiento». Al terminar cada ejercicio pulsa «Registrar ejercicio» y elige «Lo completé», «Lo hice parcialmente» o «No lo hice». Al final pulsa «Finalizar sesión».'),
    ('Hice el entrenamiento pero no lo registré', 'Abre esa rutina y pulsa «Ya lo hice · registrar entrenamiento». Indica el resultado de cada ejercicio y la fecha en que entrenaste.'),
    ('Hice solo una parte de un ejercicio', 'Elige «Lo hice parcialmente» y anota lo que hiciste en cada serie. Kora calcula el total.'),
    ('Me dolió un ejercicio', 'Pulsa «Tengo dolor o molestias» en ese ejercicio. Kora dejará de proponértelo, y también sus variantes equivalentes. Puedes revisar los ejercicios excluidos en Perfil.'),
    ('¿Cómo sé cuánto esforzarme?', 'Arriba de cada rutina, en «Cómo esforzarte hoy», y en la ficha de cada ejercicio están las indicaciones de tu plan.'),
    ('No tengo conexión a internet', 'Puedes seguir registrando: lo que no se pueda enviar queda guardado en tu teléfono hasta 48 horas. Cuando vuelva la conexión, pulsa «Reintentar envío» en la rutina.'),
    ('¿Dónde veo mi avance?', 'En Progreso verás qué parte de tu plan cumpliste cada semana y por qué cambió tu rutina. Los datos se calculan cada lunes.'),
    ('¿Cómo activo los recordatorios?', 'En Perfil → Recordatorios eliges la hora del aviso de los días con entrenamiento.'),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
      const Text('Ayuda y soporte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      for (final (question, answer) in questions) Material(
        type: MaterialType.transparency,
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          expandedAlignment: Alignment.centerLeft,
          title: Text(question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          children: [Text(answer, style: const TextStyle(fontSize: 15, height: 1.5))],
        ),
      ),
      if (painSafetyMessage.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        KoraCard(key: const Key('help-safety'), color: const Color(0xFFFBECEA), child: Text(painSafetyMessage.trim(), style: const TextStyle(fontSize: 15, height: 1.5))),
      ],
      const SizedBox(height: 16),
      KoraCard(key: const Key('help-contact'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Contacto del equipo del estudio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        SelectableText(
          contact.trim().isEmpty
              ? 'Escribe al equipo del estudio que te invitó a Kora. Indica el correo con el que creaste tu cuenta.'
              : contact.trim(),
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
      ])),
    ]),
  );
}
