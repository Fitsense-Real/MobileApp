import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/json.dart';
import '../../dashboard/presentation/pages/dashboard_page.dart' show displayDate;
import '../../plans/data/plan_repository.dart';
import '../data/pain_exclusion_repository.dart';
import '../domain/pain_safety.dart';
import 'pain_confirmation_sheet.dart';

/// The latest adaptation if it could not publish anything (`NO_FACTIBLE…`)
/// in the last two weeks.
Json? recentNotFeasibleAdaptation(List<Json> adaptations, {DateTime? now}) {
  final latest = [...adaptations]..sort((a, b) => '${b['weekStartDate']}'.compareTo('${a['weekStartDate']}'));
  final first = latest.firstOrNull;
  if (notFeasibleExplanation(first) == null) return null;
  final week = DateTime.tryParse('${first!['weekStartDate']}');
  if (week != null && (now ?? DateTime.now()).difference(week).inDays > 14) return null;
  return first;
}

/// Inicio: what O20 needs the user to know now.
/// - A session with pain that, after two weeks with a plan, still waits for
///   «¿qué ejercicio fue?» (`confirmationRequired`): asked actively here.
///   Earlier requests are only listed in Perfil, without insisting.
/// - An adaptation the backend could not do within the current restrictions.
class PainSafetyNotices extends ConsumerWidget {
  const PainSafetyNotices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = (ref.watch(painConfirmationRequestsProvider).asData?.value ?? const <PainConfirmationRequest>[])
        .where((r) => r.confirmationRequired)
        .toList();
    final adaptation = recentNotFeasibleAdaptation(ref.watch(planAdaptationsProvider).asData?.value ?? const []);
    if (requests.isEmpty && adaptation == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final r in requests)
        Card(
          key: Key('ask-${r.plannedWorkoutId}'),
          margin: const EdgeInsets.only(bottom: 12),
          color: const Color(0xFFF3F1E8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.eventDate == null ? '¿Recuerdas qué ejercicio te dolió?' : '¿Recuerdas qué ejercicio te dolió el ${displayDate(r.eventDate)}?',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Mientras no lo indiques, Kora no vuelve a proponer los ejercicios de esa sesión. También puedes decir cuáles no tuvieron que ver.'),
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => showPainConfirmation(context, r), child: const Text('Responder'))),
            ]),
          ),
        ),
      if (adaptation != null)
        Card(
          key: const Key('not-feasible'),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(padding: const EdgeInsets.all(14), child: Text(notFeasibleExplanation(adaptation)!)),
        ),
    ]);
  }
}
