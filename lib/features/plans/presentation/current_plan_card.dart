import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../data/plan_repository.dart';

class CurrentPlanCard extends ConsumerWidget {
  const CurrentPlanCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref.watch(currentPlanProvider).when(
    loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LinearProgressIndicator()),
    error: (error, _) => KoraCard(child: Column(children: [Text(apiError(error)), TextButton(onPressed: () => ref.invalidate(currentPlanProvider), child: const Text('Reintentar carga del plan'))])),
    data: (plan) {
      if (plan == null) return const SizedBox.shrink();
      final workouts = (plan['workouts'] as List? ?? []).whereType<Map>();
      return Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: KoraCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tu plan personalizado', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (plan['weekStartDate'] != null) Text('Semana del ${plan['weekStartDate']}', style: const TextStyle(color: Kora.muted)),
        for (final workout in workouts) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.fitness_center, color: Kora.sage), title: Text(workout['workoutName'] as String? ?? 'Entrenamiento'), subtitle: Text('${workout['scheduledDate'] ?? ''} · ${workout['expectedDurationMinutes'] ?? '—'} min')),
        if (workouts.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('El servidor guardó tu plan sin sesiones disponibles.')),
      ])));
    },
  );
}
