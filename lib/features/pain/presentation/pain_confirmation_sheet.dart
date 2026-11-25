import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../dashboard/presentation/pages/dashboard_page.dart' show displayDate;
import '../../plans/data/plan_repository.dart';
import '../data/pain_exclusion_repository.dart';
import '../domain/pain_safety.dart';

/// After a pain-related change the backend is the only source: re-read the
/// exclusions, the pending confirmations and the plan (open sessions get
/// their `safetyBlockReason` from it).
void refreshPainSafety(WidgetRef ref) {
  ref.invalidate(painExclusionsProvider);
  ref.invalidate(effectivePainExclusionsProvider);
  ref.invalidate(painConfirmationRequestsProvider);
  ref.invalidate(currentPlanProvider);
  ref.invalidate(planAdaptationsProvider);
}

Future<void> showPainConfirmation(BuildContext context, PainConfirmationRequest request) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => SafeArea(child: PainConfirmationSheet(request: request)),
);

/// «Sesión con dolor: ¿qué ejercicio fue?» (O20). The user names the exercise
/// that hurt and, optionally, the ones of that session that had nothing to do
/// with it. Only the backend lifts exclusions; whatever it keeps stays excluded.
class PainConfirmationSheet extends ConsumerStatefulWidget {
  const PainConfirmationSheet({super.key, required this.request});
  final PainConfirmationRequest request;

  @override
  ConsumerState<PainConfirmationSheet> createState() => _PainConfirmationSheetState();
}

class _PainConfirmationSheetState extends ConsumerState<PainConfirmationSheet> {
  int? painful;
  final unrelated = <int>{};
  bool busy = false, dontRemember = false;
  String? error;
  IdentificationResult? result;

  PainConfirmationRequest get request => widget.request;
  String nameOf(int id) => request.exercises.where((e) => e.id == id).firstOrNull?.name ?? 'Ejercicio #$id';

  void choosePainful(int? id) => setState(() {
    painful = id;
    if (id != null) unrelated.remove(id); // never both
    error = null;
  });

  Future<void> send() async {
    final problem = identificationProblem(request, painful, unrelated);
    if (problem != null) return setState(() => error = problem);
    setState(() { busy = true; error = null; });
    try {
      final answer = await ref.read(painExclusionRepositoryProvider)
          .identify(painful!, plannedWorkoutId: request.plannedWorkoutId, unrelated: unrelated);
      if (!mounted) return;
      setState(() => result = answer);
    } catch (e) {
      if (mounted) setState(() => error = apiError(e));
    } finally {
      if (mounted) setState(() => busy = false);
      // Whatever happened (200, 422, 404), show the backend's current state.
      refreshPainSafety(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = result;
    return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
      Text(request.eventDate == null ? 'Sesión con dolor' : 'Sesión con dolor del ${displayDate(request.eventDate)}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      if (done != null) ..._summary(done) else ...[
        Text(request.confirmationRequired
            ? 'Reportaste dolor en esta sesión sin indicar qué ejercicio fue. Mientras no lo indiques, Kora no vuelve a proponer ninguno de ellos.'
            : 'Si recuerdas qué ejercicio te dolió, indícalo. Mientras tanto, Kora no vuelve a proponer ninguno de estos ejercicios.'),
        const SizedBox(height: 16),
        const Text('¿Qué ejercicio te dolió?', style: TextStyle(fontWeight: FontWeight.w800)),
        RadioGroup<int>(
          groupValue: painful,
          onChanged: busy ? (_) {} : choosePainful,
          child: Column(children: [
            for (final e in request.exercises)
              RadioListTile<int>(key: Key('painful-${e.id}'), contentPadding: EdgeInsets.zero, value: e.id, title: Text(e.name)),
          ]),
        ),
        const SizedBox(height: 8),
        const Text('¿Cuáles no tuvieron nada que ver? (opcional)', style: TextStyle(fontWeight: FontWeight.w800)),
        const Text('Solo marca los que estés seguro. Los que no marques seguirán sin proponerse.', style: TextStyle(color: Colors.black54)),
        for (final e in request.exercises)
          CheckboxListTile(
            key: Key('unrelated-${e.id}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: unrelated.contains(e.id),
            title: Text(e.name),
            subtitle: e.id == painful ? const Text('Es el que te dolió') : null,
            onChanged: busy || e.id == painful ? null : (v) => setState(() { v == true ? unrelated.add(e.id) : unrelated.remove(e.id); error = null; }),
          ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 12),
        FilledButton(onPressed: busy ? null : send, child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enviar')),
        TextButton(onPressed: busy ? null : () => setState(() => dontRemember = !dontRemember), child: const Text('No recuerdo cuál fue')),
        if (dontRemember)
          const Text('No pasa nada: todos siguen sin proponerse. Si alguno ya no te da molestias, puedes pedir que vuelva a considerarse desde '
              'Perfil → Ejercicios excluidos por dolor («Ya no me duele»).', style: TextStyle(color: Colors.black54)),
      ],
    ]);
  }

  List<Widget> _summary(IdentificationResult done) => [
    Text('Gracias. Registramos que te dolió «${nameOf(done.exerciseId)}». No volverá a proponerse, ni sus variantes equivalentes, hasta que pidas reactivarlo.'),
    if (done.unrelatedLifted.isNotEmpty) ...[
      const SizedBox(height: 12),
      const Text('Vuelven a poder proponerse:', style: TextStyle(fontWeight: FontWeight.w800)),
      for (final id in done.unrelatedLifted) Text('• ${nameOf(id)}'),
    ],
    if (done.unrelatedNotLifted.isNotEmpty) ...[
      const SizedBox(height: 12),
      const Text('Siguen sin proponerse por seguridad:', style: TextStyle(fontWeight: FontWeight.w800)),
      for (final e in done.unrelatedNotLifted.entries) Text('• ${nameOf(e.key)}: ${e.value}'),
    ],
    if (done.stillExcludedFromSession.isNotEmpty) ...[
      const SizedBox(height: 12),
      const Text('Siguen sin proponerse (no los marcaste como no relacionados):', style: TextStyle(fontWeight: FontWeight.w800)),
      for (final id in done.stillExcludedFromSession) Text('• ${nameOf(id)}'),
    ],
    if (done.note != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(done.note!, style: const TextStyle(color: Colors.black54))),
    const SizedBox(height: 16),
    FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Listo')),
  ];
}
