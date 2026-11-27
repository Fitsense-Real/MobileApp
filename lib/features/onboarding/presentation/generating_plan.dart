import 'dart:async';
import 'dart:math';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../../shared/widgets/mascot/kora_mascot.dart';
import 'kapi_fun_messages.dart';

/// How long the generation screen stays up after «Generar mi plan», whatever
/// the backend does meanwhile: an early answer is kept and shown at the end,
/// a late one leads to the pending state. Never shortened or extended.
const generationScreenDuration = Duration(seconds: 30);

/// How often Kapi changes the subject (tapping Kapi changes it at once).
const kapiMessageInterval = Duration(seconds: 5);

/// The generation screen. While [pending] is false it shows «Generando» with
/// a bar driven only by [progress] (the 30 s clock, not the backend) and Kapi
/// entertaining. With [pending] the 30 s are over and the result has not
/// arrived: nothing is invented, the screen says so and lets the user go on.
class GeneratingPlan extends StatefulWidget {
  const GeneratingPlan({super.key, required this.progress, this.pending = false, this.problem, this.onContinue, this.random});

  /// 0 → 1 over [generationScreenDuration].
  final Animation<double> progress;
  final bool pending;

  /// Why the last status check failed (no connection, server down), if it did.
  final String? problem;

  /// Pending state only: continue to Kora. Null while the request itself has
  /// not been accepted yet.
  final VoidCallback? onContinue;

  /// Order of Kapi's messages; fixed in tests.
  final Random? random;

  @override
  State<GeneratingPlan> createState() => _GeneratingPlanState();
}

class _GeneratingPlanState extends State<GeneratingPlan> with TickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> scale = Tween(begin: .94, end: 1.04).animate(
    CurvedAnimation(parent: pulse, curve: Curves.easeInOutSine),
  );
  /// Little hop when Kapi is tapped.
  late final AnimationController hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final KapiMessageDeck deck = KapiMessageDeck(widget.random);
  late (MascotMood, String) message = deck.next();
  Timer? rotation;

  @override
  void initState() {
    super.initState();
    if (!widget.pending) _startRotation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant GeneratingPlan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pending != oldWidget.pending) {
      widget.pending ? rotation?.cancel() : _startRotation();
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.pending || MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = .5;
    } else if (!pulse.isAnimating) {
      pulse.repeat(reverse: true);
    }
  }

  /// Kapi's rotation runs on its own timer: it never touches [GeneratingPlan.progress].
  void _startRotation() {
    rotation?.cancel();
    rotation = Timer.periodic(kapiMessageInterval, (_) {
      if (mounted) setState(() => message = deck.next());
    });
  }

  void _tapKapi() {
    if (widget.pending) return;
    setState(() => message = deck.next());
    _startRotation();
    if (!MediaQuery.disableAnimationsOf(context)) hop.forward(from: 0);
  }

  @override
  void dispose() {
    rotation?.cancel();
    pulse.dispose();
    hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final pending = widget.pending;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Kora.forest,
        body: CustomPaint(
          painter: const _GenerationBackground(),
          child: SizedBox.expand(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Pill(pending ? 'RESULTADO PENDIENTE' : 'GENERANDO TU PLAN'),
                        const SizedBox(height: 20),
                        _kapi(pending),
                        const SizedBox(height: 16),
                        if (!pending) ...[
                          _bubble(reduce),
                          const SizedBox(height: 6),
                          const Text('Toca a Kapi para otra curiosidad', textAlign: TextAlign.center, style: TextStyle(color: Kora.sage, fontSize: 12)),
                          const SizedBox(height: 22),
                          Semantics(
                            label: 'Generando plan',
                            liveRegion: true,
                            child: const ExcludeSemantics(
                              child: Text('Generando...', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -1.2)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedBuilder(
                            animation: widget.progress,
                            builder: (context, _) => ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                key: const ValueKey('generation-progress'),
                                value: widget.progress.value,
                                minHeight: 8,
                                color: Kora.lime,
                                backgroundColor: const Color(0xFF2B473A),
                                semanticsLabel: 'Progreso',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Combinando tu perfil con modelos de optimización biomecánica.', textAlign: TextAlign.center, style: TextStyle(color: Kora.sage, height: 1.6, fontSize: 13)),
                        ] else ...[
                          Semantics(
                            header: true,
                            liveRegion: true,
                            child: const Text('Tu plan sigue en camino', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.problem ??
                                'Todavía no tenemos el resultado. No te mostraremos nada hasta que esté listo de verdad: '
                                    'puedes continuar y conocer Kora mientras tanto.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Kora.sage, height: 1.6, fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          // Indeterminate on purpose: the 30 s are over and the backend gives no progress.
                          const SizedBox(width: 160, child: LinearProgressIndicator(color: Kora.lime, backgroundColor: Color(0xFF2B473A))),
                          const SizedBox(height: 24),
                          if (widget.onContinue != null)
                            KoraButton(label: 'Continuar', onPressed: widget.onContinue, lime: true),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kapi(bool pending) {
    final mood = pending ? MascotMood.waiting : message.$1;
    return SizedBox(
      width: 220,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: scale,
            child: Container(
              width: 176,
              height: 176,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF233F30),
                border: Border.all(color: const Color(0xFF2D4936)),
              ),
            ),
          ),
          Semantics(
            button: !pending,
            onTapHint: pending ? null : 'otra curiosidad',
            child: GestureDetector(
              onTap: pending ? null : _tapKapi,
              child: AnimatedBuilder(
                animation: hop,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -sin(hop.value * pi) * 14),
                  child: child,
                ),
                child: KoraMascot(mood: mood, size: 150),
              ),
            ),
          ),
          Positioned(top: 4, right: 10, child: Transform.rotate(angle: .22, child: Container(
            width: 37, height: 37,
            decoration: BoxDecoration(color: Kora.lime, borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x38D9FF59), blurRadius: 20)]),
            child: const Icon(Icons.fitness_center, color: Kora.forest, size: 18),
          ))),
          Positioned(bottom: 8, left: 10, child: Transform.rotate(angle: -.24, child: Container(
            width: 35, height: 35,
            decoration: BoxDecoration(color: const Color(0xFF294634), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF3B5337))),
            child: const Icon(Icons.bolt_outlined, color: Color(0xFF8DA849), size: 21),
          ))),
        ],
      ),
    );
  }

  /// Kapi's speech bubble. Not a live region: screen readers are not
  /// interrupted every few seconds; the message is read when focused.
  Widget _bubble(bool reduce) => AnimatedSwitcher(
    duration: reduce ? Duration.zero : const Duration(milliseconds: 320),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(position: Tween(begin: const Offset(0, .08), end: Offset.zero).animate(animation), child: child),
    ),
    child: Container(
      key: ValueKey(message.$2),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Kora.ivory,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Text(message.$2, key: const ValueKey('kapi-message'), textAlign: TextAlign.center, style: const TextStyle(color: Kora.forest, fontSize: 15, height: 1.45, fontWeight: FontWeight.w600)),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1C392F),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: const Color(0xFF2B473A)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Kora.lime, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x80D9FF59), blurRadius: 8)])),
        const SizedBox(width: 10),
        Flexible(child: Text(label, style: const TextStyle(color: Kora.lime, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.6))),
      ],
    ),
  );
}

class _GenerationBackground extends CustomPainter {
  const _GenerationBackground();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF29482D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawPath(Path()
      ..moveTo(0, -40)
      ..cubicTo(size.width * .13, size.height * .39, size.width * .29, size.height * .39, size.width * .52, -40), paint);
    canvas.drawPath(Path()
      ..moveTo(-35, size.height * 1.12)
      ..cubicTo(size.width * .25, size.height * .52, size.width * .20, size.height * .64, size.width * .51, size.height * 1.12), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
