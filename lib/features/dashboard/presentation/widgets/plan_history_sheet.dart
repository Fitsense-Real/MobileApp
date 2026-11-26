import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/api/json.dart';
import '../../../../shared/widgets/kora_ui.dart';
import '../../../plans/data/plan_repository.dart';
import '../../../plans/domain/adaptation_text.dart';
import '../../../workouts/domain/workout_rules.dart';
import '../pages/dashboard_page.dart' show displayDate, trainingDay;

const planStatusLabels = {'ACTIVE': 'Vigente', 'COMPLETED': 'Completado', 'REPLACED': 'Reemplazado'};
/// `GET /users/me/plans`: every week and version, including replaced ones.
class PlanHistorySheet extends ConsumerWidget {
  const PlanHistorySheet({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(planHistoryProvider);
    // What really happened to each week (GET /users/me/plan/adaptations); without it, the plan's own field.
    final adaptations = ref.watch(planAdaptationsProvider).asData?.value ?? const <Json>[];
    return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
      const Text('Historial de planes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      history.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Column(children: [Text(apiError(e)), TextButton(onPressed: () => ref.invalidate(planHistoryProvider), child: const Text('Reintentar'))]),
        data: (rows) => rows.isEmpty
            ? const Text('Todavía no tienes planes generados.')
            : Column(children: [
                for (final plan in rows)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text('Semana del ${displayDate(plan['weekStartDate'])} · v${plan['planVersion'] ?? 1}'),
                      subtitle: Text([
                        planStatusLabels[plan['status']] ?? '${plan['status']}',
                        '${plan['plannedDaysCount'] ?? '—'} días',
                        if (planHistoryLabel(plan, adaptations) case final label?) label,
                      ].join(' · ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: plan['planId'] is num
                          ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlanVersionPage(planId: (plan['planId'] as num).toInt())))
                          : null,
                    ),
                  ),
              ]),
      ),
    ]);
  }
}

/// Read-only view of one plan version (`GET /users/me/plan/{id}`).
class PlanVersionPage extends ConsumerWidget {
  const PlanVersionPage({super.key, required this.planId});
  final int planId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planByIdProvider(planId));
    final adaptation = (ref.watch(planAdaptationsProvider).asData?.value ?? const <Json>[])
        .where((a) => a['resultingPlanId'] == planId).firstOrNull;
    return KoraPage(child: ListView(padding: const EdgeInsets.all(24), children: [
      Align(alignment: Alignment.centerLeft, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back), tooltip: 'Volver')),
      plan.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => KoraCard(child: Column(children: [Text(apiError(e)), TextButton(onPressed: () => ref.invalidate(planByIdProvider(planId)), child: const Text('Reintentar'))])),
        data: (data) {
          final workouts = jsonRows(data['workouts'])..sort((a, b) => '${a['scheduledDate']}'.compareTo('${b['scheduledDate']}'));
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KoraHeading('Semana del ${displayDate(data['weekStartDate'])}', subtitle: 'Versión ${data['planVersion'] ?? 1} · ${planStatusLabels[data['status']] ?? data['status']}'),
            if (adaptation != null) Padding(padding: const EdgeInsets.only(top: 12), child: AdaptationCard(adaptation: adaptation))
            else if (data['adjustmentReason'] != null) Padding(padding: const EdgeInsets.only(top: 12), child: KoraCard(child: Text('${data['adjustmentReason']}'))),
            const SizedBox(height: 12),
            if (workouts.isEmpty) const Text('Este plan no tiene entrenamientos.'),
            for (final workout in workouts)
              Padding(padding: const EdgeInsets.only(top: 12), child: KoraCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${workout['workoutName'] ?? 'Entrenamiento'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${trainingDay(workout['scheduledDate'])} · ${workoutStatusLabel(workout['status'])}', style: const TextStyle(color: Kora.muted)),
                Text('${jsonRows(workout['exercises']).length} ejercicios · ${workout['expectedDurationMinutes'] ?? '—'} min', style: const TextStyle(color: Kora.muted)),
              ]))),
          ]);
        },
      ),
    ]));
  }
}

/// One week's adaptation in plain words: title, the backend's reason and what changed.
class AdaptationCard extends StatelessWidget {
  const AdaptationCard({super.key, required this.adaptation, this.showWeek = false});
  final Json adaptation;
  final bool showWeek;
  @override
  Widget build(BuildContext context) {
    final text = describeAdaptation(adaptation);
    final icon = switch (text.kind) {
      AdaptationKind.changed => Icons.tune,
      AdaptationKind.kept => Icons.check_circle_outline,
      AdaptationKind.notFeasible => Icons.info_outline,
      AdaptationKind.unknown => Icons.history,
    };
    return KoraCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: Kora.sage),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (showWeek) Text('Semana del ${displayDate(adaptation['weekStartDate'])}', style: const TextStyle(color: Kora.muted, fontSize: 12)),
        Text(text.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        if (text.reason case final reason?) Padding(padding: const EdgeInsets.only(top: 4), child: Text(reason)),
        for (final detail in text.details) Padding(padding: const EdgeInsets.only(top: 4), child: Text(detail, style: const TextStyle(color: Kora.muted))),
      ])),
    ]));
  }
}
