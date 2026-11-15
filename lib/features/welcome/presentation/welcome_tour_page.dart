import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../../shared/widgets/mascot/kora_mascot.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../dashboard/presentation/dashboard_tour_targets.dart';
import '../../dashboard/presentation/pages/dashboard_page.dart';
import '../data/welcome_store.dart';
import 'first_plan_generation_controller.dart';
import 'welcome_routes.dart';
import 'tour/tour_spotlight.dart';
import 'tour/tour_steps.dart';


/// Welcome tour over the real dashboard, while the first plan is generated.
///
/// First time ([replay] false): mandatory (no skip), progress saved per user
/// at every step and marked completed only on the last one; the generation
/// is started (or resumed) on entry and checked again when the tour ends.
/// Replay: same steps from Perfil, nothing is saved or generated.
class WelcomeTourPage extends ConsumerStatefulWidget {
  const WelcomeTourPage({super.key, this.replay = false, this.steps = welcomeTourSteps});
  final bool replay;
  final List<TourStep> steps;

  @override
  ConsumerState<WelcomeTourPage> createState() => _WelcomeTourPageState();
}

class _WelcomeTourPageState extends ConsumerState<WelcomeTourPage> {
  final targets = DashboardTourTargets();
  final tab = ValueNotifier<int>(0);
  final _stackKey = GlobalKey();
  int step = 0;
  bool loaded = false;
  Rect? hole;

  TourStep get current => widget.steps[step];
  int? get _userId => ref.read(authViewModelProvider).user?.id;

  @override
  void initState() {
    super.initState();
    tab.addListener(_onTabChanged);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    tab.removeListener(_onTabChanged);
    tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var start = 0;
    final userId = _userId;
    if (!widget.replay && userId != null) {
      // The plan is requested at the same time the tour starts, never after.
      ref.read(firstPlanGenerationProvider.notifier).start();
      final saved = await ref.read(welcomeStoreProvider).load(userId);
      if (saved.tourStatus == TourStatus.inProgress) start = saved.tourStep.clamp(0, widget.steps.length - 1);
      await ref.read(welcomeStoreProvider).update(userId, (p) => p.copyWith(tourStatus: TourStatus.inProgress, tourStep: start));
    }
    if (!mounted) return;
    setState(() {
      loaded = true;
      step = start;
    });
    tab.value = current.tab;
    _measureAfterFrame();
  }

  void _onTabChanged() {
    if (!loaded) return;
    final goes = current.goesToTab;
    if (goes != null && tab.value == goes) {
      _go(step + 1);
    } else if (tab.value != current.tab) {
      // Only the highlighted tab may be opened during the tour.
      tab.value = current.tab;
    }
  }

  Future<void> _go(int next) async {
    if (next < 0) return;
    if (next >= widget.steps.length) return _finish();
    setState(() {
      step = next;
      hole = null;
    });
    if (tab.value != current.tab) tab.value = current.tab;
    final userId = _userId;
    if (!widget.replay && userId != null) {
      await ref.read(welcomeStoreProvider).update(userId, (p) => p.copyWith(tourStatus: TourStatus.inProgress, tourStep: next));
    }
    _measureAfterFrame();
  }

  void _next() {
    final goes = current.goesToTab;
    if (goes != null) {
      tab.value = goes; // same as tapping the highlighted tab
    } else {
      _go(step + 1);
    }
  }

  Future<void> _finish() async {
    if (widget.replay) {
      context.canPop() ? context.pop() : context.go('/dashboard');
      return;
    }
    final userId = _userId;
    if (userId != null) {
      await ref.read(welcomeStoreProvider).update(userId, (p) => p.copyWith(tourStatus: TourStatus.completed, tourStep: widget.steps.length - 1));
    }
    if (mounted) context.go(welcomeResultRoute);
  }

  void _measureAfterFrame() => WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

  Future<void> _measure() async {
    if (!mounted) return;
    final key = current.target?.call(targets);
    final targetContext = key?.currentContext;
    if (targetContext == null) {
      if (hole != null) setState(() => hole = null);
      return;
    }
    final reduce = MediaQuery.disableAnimationsOf(context);
    await Scrollable.ensureVisible(targetContext, alignment: .35, duration: reduce ? Duration.zero : const Duration(milliseconds: 250));
    // The new scroll offset is laid out in the next frame: measure after it,
    // or the ring lands on whatever was there before scrolling.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || key!.currentContext == null) return;
    final box = key.currentContext!.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
    if (rect != hole) setState(() => hole = rect);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && step > 0) _go(step - 1);
      },
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _measureAfterFrame();
          return false;
        },
        child: SizeChangedLayoutNotifier(
          child: Stack(key: _stackKey, children: [
            DashboardPage(tourTargets: targets, tabController: tab),
            if (loaded)
              TourSpotlight(
                hole: hole,
                passThrough: current.interactive,
                card: TourCard(
                  step: step,
                  total: widget.steps.length,
                  data: current,
                  onBack: step > 0 ? () => _go(step - 1) : null,
                  onNext: _next,
                ),
              )
            else
              const Positioned.fill(child: ColoredBox(color: Color(0xB80F2E25))),
          ]),
        ),
      ),
    );
  }
}

/// Kapi's message for a step, with progress and navigation.
class TourCard extends StatelessWidget {
  const TourCard({super.key, required this.step, required this.total, required this.data, required this.onNext, this.onBack});
  final int step, total;
  final TourStep data;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Kora.ivory,
      borderRadius: BorderRadius.circular(26),
      elevation: 6,
      shadowColor: const Color(0x330F2E25),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Semantics(
                label: 'Paso ${step + 1} de $total',
                child: ExcludeSemantics(
                  child: Text('PASO ${step + 1} DE $total',
                      style: const TextStyle(color: Kora.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (step + 1) / total, minHeight: 5, color: Kora.forest, backgroundColor: Colors.white),
          ),
          const SizedBox(height: 10),
          MascotMessage(mood: data.mood, title: data.title, message: data.message, mascotSize: 76),
          if (data.showsResultChoices) ...[
            const SizedBox(height: 10),
            const ResultChoicesDemo(),
          ],
          const SizedBox(height: 10),
          // Side by side when they fit; stacked on narrow screens or large text.
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: 4,
            children: [
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Atrás'),
              style: TextButton.styleFrom(foregroundColor: Kora.forest, minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            FilledButton(
              onPressed: onNext,
              // The app theme makes buttons full width; inside this row they size to their label.
              style: FilledButton.styleFrom(backgroundColor: Kora.forest, foregroundColor: Kora.lime, shape: const StadiumBorder(),
                  minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20),
                  textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 14)),
              child: Text(data.nextLabel ?? 'Siguiente'),
            ),
            ],
          ),
        ]),
      ),
    );
  }
}

/// The three result options of the real exercise dialog, as an illustration.
/// Not interactive and not tied to any workout.
class ResultChoicesDemo extends StatelessWidget {
  const ResultChoicesDemo({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Opciones al registrar un ejercicio: Lo completé, Lo hice parcialmente, No lo hice',
    child: IgnorePointer(
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (label, selected) in const [('Lo completé', true), ('Lo hice parcialmente', false), ('No lo hice', false)])
          Chip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            backgroundColor: selected ? Kora.lime : Colors.white,
            side: const BorderSide(color: Color(0x1F0F2E25)),
            visualDensity: VisualDensity.compact,
          ),
      ]),
    ),
  );
}
