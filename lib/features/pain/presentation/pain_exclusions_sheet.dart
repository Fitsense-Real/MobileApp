import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/json.dart';
import '../../dashboard/presentation/pages/dashboard_page.dart' show displayDate;
import '../data/pain_exclusion_repository.dart';

/// Perfil → Ejercicios excluidos por dolor (`GET /users/me/pain-exclusions`).
class PainExclusionsSheet extends ConsumerStatefulWidget {
  const PainExclusionsSheet({super.key});
  @override
  ConsumerState<PainExclusionsSheet> createState() => _PainExclusionsSheetState();
}

class _PainExclusionsSheetState extends ConsumerState<PainExclusionsSheet> {
  int? busyExercise;

  Future<void> reactivate(Json exclusion) async {
    final comment = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Volver a considerar'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Confirmas que ya no sientes dolor con «${exclusion['exerciseName'] ?? 'este ejercicio'}». '
              'No se agrega de inmediato: vuelve a ser candidato y el plan solo lo usará si cumple todas las reglas de seguridad.'),
          TextField(controller: comment, maxLength: 300, decoration: const InputDecoration(labelText: 'Comentario (opcional)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya no tengo dolor')),
        ],
      ),
    );
    final text = comment.text;
    comment.dispose();
    if (confirmed != true || !mounted) return;
    final exerciseId = (exclusion['exerciseId'] as num).toInt();
    setState(() => busyExercise = exerciseId);
    String message;
    try {
      final result = await ref.read(painExclusionRepositoryProvider).reactivate(exerciseId, comment: text);
      message = '${result['nota'] ?? (result['candidatoHoy'] == true ? 'El ejercicio vuelve a ser candidato.' : 'Reactivación registrada.')}';
      ref.invalidate(painExclusionsProvider);
    } catch (e) {
      message = apiError(e);
    } finally {
      if (mounted) setState(() => busyExercise = null);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(painExclusionsProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
      const Text('Ejercicios excluidos por dolor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Cuando reportas dolor, el plan deja de proponer ese ejercicio.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 16),
      rows.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Column(children: [Text(apiError(e)), TextButton(onPressed: () => ref.invalidate(painExclusionsProvider), child: const Text('Reintentar'))]),
        data: (items) => items.isEmpty
            ? const Text('No tienes ejercicios excluidos por dolor.')
            : Column(children: [
                for (final item in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text('${item['exerciseName'] ?? 'Ejercicio #${item['exerciseId']}'}'),
                      subtitle: Text([
                        painExclusionReasonLabels[item['reason']] ?? '${item['reason']}',
                        if (item['eventDate'] != null) displayDate(item['eventDate']),
                        painExclusionStatusLabels[item['status']] ?? '${item['status']}',
                      ].join(' · ')),
                      trailing: item['status'] == 'ACTIVA'
                          ? (busyExercise == (item['exerciseId'] as num?)?.toInt()
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : TextButton(onPressed: () => reactivate(item), child: const Text('Reactivar')))
                          : null,
                    ),
                  ),
              ]),
      ),
    ]);
  }
}
