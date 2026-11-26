import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/json.dart';
import '../../dashboard/presentation/pages/dashboard_page.dart' show displayDate;
import '../data/pain_exclusion_repository.dart';
import '../domain/pain_safety.dart';
import 'pain_confirmation_sheet.dart';

/// Perfil → Ejercicios excluidos por dolor (O20, Backend PR #84).
///
/// - Sessions with pain waiting for «¿qué ejercicio fue?»
///   (`/confirmation-requests`).
/// - «Te dolieron»: DIRECT confirmed, with «Ya no me duele» (`/reactivation`).
/// - «En una sesión con dolor»: DIRECT not identified yet.
/// - «También evitamos, por ser el mismo movimiento»: EQUIVALENT and
///   PRECAUTION, without an action of their own (they come back with the
///   exercise they derive from).
/// - The history of reports (`GET /pain-exclusions`).
///
/// Everything comes from the backend: nothing is unblocked locally.
class PainExclusionsSheet extends ConsumerStatefulWidget {
  const PainExclusionsSheet({super.key});
  @override
  ConsumerState<PainExclusionsSheet> createState() => _PainExclusionsSheetState();
}

class _PainExclusionsSheetState extends ConsumerState<PainExclusionsSheet> {
  int? busyExercise;

  Future<void> reactivate(int exerciseId, String name) async {
    final comment = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Volver a considerar'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Confirmas que ya no sientes dolor con «$name». '
              'No se agrega de inmediato: vuelve a ser candidato y el plan solo lo usará si cumple todas las reglas de seguridad. '
              'Sus variantes equivalentes vuelven con él.'),
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
    setState(() => busyExercise = exerciseId);
    String message;
    String? refused;
    try {
      final result = await ref.read(painExclusionRepositoryProvider).reactivate(exerciseId, comment: text);
      message = '${result['nota'] ?? (result['candidatoHoy'] == true ? 'El ejercicio vuelve a ser candidato.' : 'Reactivación registrada.')}';
    } catch (e) {
      // e.g. 422 REACTIVACION_RECHAZADA_POR_SEGURIDAD: it stays excluded.
      message = apiError(e);
      refused = reactivationRefusal(message, name);
    } finally {
      if (mounted) setState(() => busyExercise = null);
      refreshPainSafety(ref);
    }
    if (!mounted) return;
    if (refused != null) {
      // A refusal is not a confirmation: shown as such, never as a passing notice.
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
        key: const Key('reactivation-refused'),
        title: const Text('Sigue bloqueado'),
        content: Text(refused!),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget reactivateButton(EffectiveExclusion e) => busyExercise == e.exerciseId
      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
      : TextButton(onPressed: () => reactivate(e.exerciseId, e.name), child: const Text('Ya no me duele'));

  Widget heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
  );

  Widget card(EffectiveExclusion e, {Widget? trailing}) => Card(
    key: Key('effective-${e.exerciseId}'),
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      title: Text(e.name),
      subtitle: Text([e.explanation, if (e.eventDate != null) displayDate(e.eventDate)].join(' · ')),
      trailing: trailing,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final effective = ref.watch(effectivePainExclusionsProvider);
    final requests = ref.watch(painConfirmationRequestsProvider).asData?.value ?? const [];
    final history = ref.watch(painExclusionsProvider);
    return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
      const Text('Ejercicios excluidos por dolor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Cuando reportas dolor, Kora deja de proponer ese ejercicio y los que son el mismo movimiento. '
          'Nada vuelve solo: tú decides cuándo reconsiderarlo.', style: TextStyle(color: Colors.black54)),
      for (final r in requests)
        Card(
          key: Key('request-${r.plannedWorkoutId}'),
          color: r.confirmationRequired ? const Color(0xFFF3F1E8) : null,
          margin: const EdgeInsets.only(top: 12),
          child: ListTile(
            title: Text(r.eventDate == null ? 'Sesión con dolor: ¿qué ejercicio fue?' : 'Sesión del ${displayDate(r.eventDate)}: ¿qué ejercicio te dolió?'),
            subtitle: Text('${r.exercises.length} ${r.exercises.length == 1 ? 'ejercicio' : 'ejercicios'} sin proponerse mientras no lo indiques.'),
            trailing: TextButton(onPressed: () => showPainConfirmation(context, r), child: const Text('Responder')),
          ),
        ),
      effective.when(
        loading: () => const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        error: (e, _) => Column(children: [Text(apiError(e)), TextButton(onPressed: () => refreshPainSafety(ref), child: const Text('Reintentar'))]),
        data: (items) {
          final hurt = items.where((e) => e.origin == PainOrigin.direct && e.confirmed).toList();
          final session = items.where((e) => e.origin == PainOrigin.direct && !e.confirmed).toList();
          final related = items.where((e) => e.origin != PainOrigin.direct).toList();
          if (items.isEmpty) return const Padding(padding: EdgeInsets.only(top: 16), child: Text('Hoy no hay ejercicios excluidos por dolor.'));
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (hurt.isNotEmpty) ...[
              heading('Te dolieron'),
              for (final e in hurt) card(e, trailing: e.canReactivate ? reactivateButton(e) : null),
            ],
            if (session.isNotEmpty) ...[
              heading('En una sesión con dolor (sin indicar cuál)'),
              for (final e in session) card(e, trailing: e.canReactivate ? reactivateButton(e) : null),
            ],
            if (related.isNotEmpty) ...[
              heading('También evitamos, por ser el mismo movimiento'),
              for (final e in related) card(e),
            ],
          ]);
        },
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Historial de reportes'),
        children: [
          history.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text(apiError(e)),
            data: (rows) => rows.isEmpty
                ? const Text('Sin reportes de dolor.')
                : Column(children: [for (final item in rows) _historyRow(item)]),
          ),
        ],
      ),
    ]);
  }

  Widget _historyRow(Json item) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text('${item['exerciseName'] ?? 'Ejercicio #${item['exerciseId']}'}'),
    subtitle: Text([
      painExclusionReasonLabels[item['reason']] ?? 'Reporte de dolor',
      if (item['reason'] == 'DOLOR_SESION_SIN_IDENTIFICAR' && item['confirmed'] == true) 'identificado después',
      if (item['eventDate'] != null) displayDate(item['eventDate']),
      painExclusionStatusLabels[item['status']] ?? '${item['status']}',
    ].join(' · ')),
  );
}
