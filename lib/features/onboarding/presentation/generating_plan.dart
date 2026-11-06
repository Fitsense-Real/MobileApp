import 'package:flutter/material.dart';
import '../../../shared/widgets/kora_ui.dart';

class GeneratingPlan extends StatefulWidget {
  const GeneratingPlan({super.key, required this.saving});
  final bool saving;
  @override
  State<GeneratingPlan> createState() => _GeneratingPlanState();
}

class _GeneratingPlanState extends State<GeneratingPlan>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Animation<double> scale = Tween(begin: .88, end: 1.08).animate(
    CurvedAnimation(parent: pulse, curve: Curves.easeInOutSine),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      pulse.stop();
      pulse.value = .5;
    } else if (!pulse.isAnimating) {
      pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      backgroundColor: Kora.forest,
      body: CustomPaint(
        painter: const _GenerationBackground(),
        child: SizedBox.expand(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                children: [
                  Container(
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
                        Text(widget.saving ? 'SINCRONIZANDO PERFIL' : 'MOTOR IA ACTIVO', style: const TextStyle(color: Kora.lime, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: 240,
                    height: 230,
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
                            alignment: Alignment.center,
                            child: Container(
                              width: 116,
                              height: 116,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [Color(0xFF3B582B), Color(0xFF29472D), Color(0xFF203C2D)]),
                              ),
                              child: const Icon(Icons.psychology_outlined, size: 48, color: Kora.lime),
                            ),
                          ),
                        ),
                        Positioned(top: 6, right: 17, child: Transform.rotate(angle: .22, child: Container(
                          width: 37, height: 37,
                          decoration: BoxDecoration(color: Kora.lime, borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x38D9FF59), blurRadius: 20)]),
                          child: const Icon(Icons.fitness_center, color: Kora.forest, size: 18),
                        ))),
                        Positioned(bottom: 14, left: 14, child: Transform.rotate(angle: -.24, child: Container(
                          width: 35, height: 35,
                          decoration: BoxDecoration(color: const Color(0xFF294634), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF3B5337))),
                          child: const Icon(Icons.bolt_outlined, color: Color(0xFF8DA849), size: 21),
                        ))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  Semantics(
                    label: widget.saving ? 'Guardando perfil' : 'Generando plan',
                    liveRegion: true,
                    child: const Text('Sincronizando...', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, letterSpacing: -1.2)),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: const Text('Combinando tu perfil con modelos de\noptimización biomecánica.', textAlign: TextAlign.center, style: TextStyle(color: Kora.sage, height: 1.6, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
