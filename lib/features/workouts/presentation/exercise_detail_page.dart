import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/json.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../pain/data/pain_exclusion_repository.dart';
import '../../pain/domain/pain_safety.dart';
import '../data/equipment_names.dart';
import '../domain/effort_guidance.dart';
import '../domain/exercise_labels.dart';
import '../domain/workout_rules.dart';
import 'exercise_media.dart';
import 'exercise_result_dialog.dart';

/// What the person chose on the exercise screen, for the routine screen.
enum ExerciseDetailAction { reportPain }

/// Full-screen view of one exercise of the routine: the animation large (it
/// can be paused and enlarged) together with the prescription, rest,
/// equipment, muscles, the plan's effort guidance and the catalog
/// instructions, so the movement and the text are seen at the same time.
/// Previous / next move through the routine without leaving it; going back
/// returns to the routine exactly as it was.
class ExerciseDetailPage extends ConsumerStatefulWidget {
  const ExerciseDetailPage({super.key, required this.exercises, required this.initialIndex, this.guidance, this.canReportPain = false});
  final List<Json> exercises;
  final int initialIndex;
  final EffortGuidance? guidance;

  /// Shows «Tengo dolor o molestias»; the routine screen then opens the
  /// result dialog with the same O20 checks as always.
  final bool canReportPain;

  static Future<(ExerciseDetailAction, Json)?> open(BuildContext context, {required List<Json> exercises, required int index, EffortGuidance? guidance, bool canReportPain = false}) =>
      Navigator.of(context).push<(ExerciseDetailAction, Json)>(MaterialPageRoute(
          builder: (_) => ExerciseDetailPage(exercises: exercises, initialIndex: index, guidance: guidance, canReportPain: canReportPain)));

  @override
  ConsumerState<ExerciseDetailPage> createState() => _ExerciseDetailPageState();
}

class _ExerciseDetailPageState extends ConsumerState<ExerciseDetailPage> {
  late int index = widget.initialIndex.clamp(0, widget.exercises.length - 1);
  bool paused = false;

  Json get exercise => widget.exercises[index];

  void move(int delta) => setState(() { index = (index + delta).clamp(0, widget.exercises.length - 1); paused = false; });

  Future<void> enlarge(ExerciseMediaSource source) => showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: Colors.white,
          child: SafeArea(child: Column(children: [
            Align(alignment: Alignment.centerRight, child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), tooltip: 'Cerrar')),
            Expanded(child: InteractiveViewer(maxScale: 4, child: Center(child: ExerciseMedia(source: source, height: 520, paused: paused)))),
            const Padding(padding: EdgeInsets.all(16), child: Text('Pellizca para acercar.', style: TextStyle(fontSize: 14))),
          ])),
        ),
      );

  Widget fact(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 22, color: Kora.forest),
          const SizedBox(width: 12),
          Expanded(child: Text.rich(TextSpan(children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ]), style: const TextStyle(fontSize: 16, height: 1.4))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final source = ExerciseMediaSource.of(e);
    final size = MediaQuery.sizeOf(context);
    final mediaHeight = (size.height * .38).clamp(180.0, 360.0);
    final equipment = equipmentName(e['equipment'], ref.watch(equipmentNamesProvider).asData?.value ?? const {});
    final zone = bodyPartLabel(e['bodyPart']);
    final effort = widget.guidance?.forExercise(e) ?? const [];
    final effective = ref.watch(effectivePainExclusionsProvider).asData?.value ?? const [];
    final block = blockExplanation(e, effective: effective);
    final id = (e['exerciseId'] as num?)?.toInt();
    return KoraPage(
      maxWidth: 680,
      bottomNavigationBar: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(children: [
          IconButton.outlined(onPressed: index > 0 ? () => move(-1) : null, icon: const Icon(Icons.chevron_left), tooltip: 'Ejercicio anterior'),
          Expanded(child: Text('Ejercicio ${index + 1} de ${widget.exercises.length}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          IconButton.outlined(onPressed: index < widget.exercises.length - 1 ? () => move(1) : null, icon: const Icon(Icons.chevron_right), tooltip: 'Ejercicio siguiente'),
        ]),
      )),
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
        Row(children: [
          IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back), tooltip: 'Volver a la rutina'),
          Expanded(child: Text('${e['exerciseName'] ?? 'Ejercicio'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2))),
        ]),
        const SizedBox(height: 8),
        ExerciseMedia(key: ValueKey(index), source: source, height: mediaHeight, paused: paused, showAttribution: true),
        if (!source.isEmpty) Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          TextButton.icon(
            onPressed: () => setState(() => paused = !paused),
            icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(paused ? 'Reanudar animación' : 'Pausar animación'),
          ),
          TextButton.icon(onPressed: () => enlarge(source), icon: const Icon(Icons.zoom_out_map_rounded), label: const Text('Ampliar')),
        ]),
        if (block != null) Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFFBECEA), borderRadius: BorderRadius.circular(12)),
          child: Text('No disponible por ahora. $block Solo puede registrarse como no realizado.', style: const TextStyle(fontSize: 15, height: 1.4)),
        ),
        const SizedBox(height: 12),
        fact(Icons.repeat_rounded, 'Qué hacer', exercisePrescription(e)),
        if ((e['restSeconds'] as num? ?? 0) > 0) fact(Icons.hourglass_bottom_rounded, 'Descanso entre series', restLabel(e['restSeconds'] as num)),
        if (equipment != null) fact(Icons.fitness_center_rounded, 'Equipo', equipment),
        if (zone != null) fact(Icons.accessibility_new_rounded, 'Zona que trabaja', zone),
        if (e['notes'] != null) fact(Icons.info_outline_rounded, 'Indicación del plan', '${e['notes']}'),
        if (effort.isNotEmpty) KoraCard(
          color: const Color(0xFFF1F7E4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Cómo esforzarte', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            for (final text in effort) Padding(padding: const EdgeInsets.only(top: 6), child: Text(text, style: const TextStyle(fontSize: 15, height: 1.45))),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('Cómo se hace', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 8),
        if (id == null)
          const Text('El catálogo no incluye instrucciones para este ejercicio.', style: TextStyle(fontSize: 16))
        else
          ref.watch(exerciseDetailProvider(id)).when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
            error: (error, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(apiError(error), style: const TextStyle(fontSize: 15)),
              TextButton(onPressed: () => ref.invalidate(exerciseDetailProvider(id)), child: const Text('Reintentar')),
            ]),
            data: (data) {
              final main = muscleLabel(data['targetMuscle']);
              final secondary = muscleList([data['synergistMuscle'], ...(data['secondaryMuscles'] as List? ?? const [])]).where((m) => m != main).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${data['instructions'] ?? 'El catálogo no incluye instrucciones para este ejercicio.'}', style: const TextStyle(fontSize: 16, height: 1.55)),
                if (main != null || secondary.isNotEmpty) const SizedBox(height: 12),
                if (main != null) Text('Músculo principal: $main', style: const TextStyle(fontSize: 15, color: Kora.muted)),
                if (secondary.isNotEmpty) Text('Secundarios: ${secondary.join(', ')}', style: const TextStyle(fontSize: 15, color: Kora.muted)),
              ]);
            },
          ),
        if (widget.canReportPain && !isUnsafeExercise(e)) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const Key('detail-report-pain'),
            onPressed: () => Navigator.of(context).pop((ExerciseDetailAction.reportPain, e)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: const Color(0xFF9B2C1F)),
            icon: const Icon(Icons.healing_outlined),
            label: const Text('Tengo dolor o molestias'),
          ),
        ],
      ]),
    );
  }
}
