import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/api/api_error.dart';
import '../../../core/api/json.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../../shared/widgets/mascot/kora_mascot.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../dashboard/presentation/pages/dashboard_page.dart' show displayDate;
import '../../plans/data/plan_repository.dart';
import '../domain/generation_operation.dart';
import 'first_plan_generation_controller.dart';

/// After the tour: shows the real state of the first-plan generation.
/// Never shows percentages or promised times, and always offers a way out.
class FirstPlanResultPage extends ConsumerStatefulWidget {
  const FirstPlanResultPage({super.key});
  @override
  ConsumerState<FirstPlanResultPage> createState() => _FirstPlanResultPageState();
}

class _FirstPlanResultPageState extends ConsumerState<FirstPlanResultPage> {
  Json? plan;
  String? planError;
  bool loadingPlan = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(firstPlanGenerationProvider.notifier).start());
  }

  Future<void> _loadPlan(int planId) async {
    if (loadingPlan || plan != null) return;
    setState(() { loadingPlan = true; planError = null; });
    try {
      final loaded = await ref.read(planRepositoryProvider).byId(planId);
      if (!mounted) return;
      ref.read(generatedPlanProvider.notifier).setPlan(loaded);
      ref.invalidate(currentPlanProvider);
      setState(() => plan = loaded);
    } catch (e) {
      if (mounted) setState(() => planError = apiError(e));
    } finally {
      if (mounted) setState(() => loadingPlan = false);
    }
  }

  Future<void> _openPlan() async {
    await ref.read(firstPlanGenerationProvider.notifier).consume();
    if (mounted) context.go(AppRoutes.dashboard);
  }

  Future<void> _logout() async {
    await ref.read(authViewModelProvider.notifier).logout();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(firstPlanGenerationProvider);
    final operation = state.operation;
    if (operation?.status == GenerationStatus.completed && operation?.planId != null && plan == null && planError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlan(operation!.planId!));
    }
    final view = _view(state);
    return PopScope(
      canPop: false,
      child: KoraPage(
        maxWidth: 560,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: KoraMascot(mood: view.mood, size: 168)),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                liveRegion: true,
                child: Text(view.title, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Kora.forest, letterSpacing: -.6)),
              ),
              const SizedBox(height: 10),
              Text(view.message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.5, color: Kora.muted)),
              if (view.waiting) ...[
                const SizedBox(height: 24),
                // Indeterminate on purpose: the backend gives no progress, so none is invented.
                const Center(child: SizedBox(width: 160, child: LinearProgressIndicator(color: Kora.forest, backgroundColor: Colors.white))),
              ],
              const SizedBox(height: 28),
              ...view.actions,
            ]),
          ),
        ),
      ),
    );
  }

  _ResultView _view(FirstPlanGenerationState state) {
    final operation = state.operation;
    if (state.error != null) {
      return _ResultView(
        mood: MascotMood.error,
        title: 'No pudimos pedir tu rutina',
        message: state.error!,
        actions: [
          KoraButton(label: 'Intentar de nuevo', onPressed: () => ref.read(firstPlanGenerationProvider.notifier).retry()),
          TextButton(onPressed: _logout, child: const Text('Cerrar sesión')),
        ],
      );
    }
    switch (operation?.status) {
      case GenerationStatus.completed:
        final summary = plan == null ? null : _summary(plan!);
        return _ResultView(
          mood: MascotMood.success,
          title: '¡Tu primera rutina está lista!',
          message: planError ?? summary ?? 'Estamos abriendo tu plan…',
          waiting: plan == null && planError == null,
          actions: [
            if (plan != null) KoraButton(label: 'Ver mi plan', onPressed: _openPlan),
            if (planError != null) KoraButton(label: 'Reintentar', onPressed: () => _loadPlan(operation!.planId!)),
          ],
        );
      case GenerationStatus.noFactible:
        return _ResultView(
          mood: MascotMood.error,
          title: 'No encontramos una rutina compatible',
          message: '${operation!.message ?? 'Con tus condiciones actuales no fue posible preparar una semana válida.'}\n\n'
              'Kora no relaja tus restricciones para conseguir una rutina. Si crees que tu perfil necesita cambios, contacta al equipo del estudio.',
          actions: [
            KoraButton(label: 'Contactar al equipo', onPressed: _contact),
            TextButton(onPressed: _logout, child: const Text('Cerrar sesión')),
          ],
        );
      case GenerationStatus.failed:
        return _ResultView(
          mood: MascotMood.error,
          title: 'Algo salió mal',
          message: operation!.message ?? 'No pudimos preparar tu rutina.',
          actions: [
            if (operation.retryable)
              KoraButton(label: 'Intentar de nuevo', onPressed: () => ref.read(firstPlanGenerationProvider.notifier).retry())
            else
              KoraButton(label: 'Contactar al equipo', onPressed: _contact),
            TextButton(onPressed: _logout, child: const Text('Cerrar sesión')),
          ],
        );
      default:
        final problem = switch (state.problem) {
          CheckProblem.connection => 'No hay conexión para consultar el estado. Tu rutina se sigue preparando en el servidor; lo intentaremos de nuevo.',
          CheckProblem.server => 'El servidor no responde por ahora. Tu rutina no se pierde; lo intentaremos de nuevo.',
          CheckProblem.none => null,
        };
        return _ResultView(
          mood: problem == null ? MascotMood.waiting : MascotMood.error,
          title: problem == null ? '¡Ya conoces Kora!' : 'Seguimos intentando',
          message: problem ??
              'Estamos terminando de preparar tu primera rutina. Puede tardar unos minutos; si cierras la app, la seguiremos preparando.',
          waiting: true,
          actions: [
            if (problem != null)
              OutlinedButton(onPressed: () => ref.read(firstPlanGenerationProvider.notifier).refresh(), child: const Text('Consultar ahora')),
          ],
        );
    }
  }

  String _summary(Json plan) {
    final workouts = jsonRows(plan['workouts']).length;
    return 'Semana del ${displayDate(plan['weekStartDate'])} · $workouts ${workouts == 1 ? 'entrenamiento' : 'entrenamientos'}.';
  }

  void _contact() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Equipo del estudio'),
      content: const Text('Escríbele al equipo del estudio FitSense indicando tu correo. Revisarán tu perfil contigo.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
    ),
  );
}

class _ResultView {
  const _ResultView({required this.mood, required this.title, required this.message, this.actions = const [], this.waiting = false});
  final MascotMood mood;
  final String title;
  final String message;
  final List<Widget> actions;
  final bool waiting;
}
