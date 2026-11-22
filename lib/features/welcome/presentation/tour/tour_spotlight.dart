import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import '../../../../shared/widgets/kora_ui.dart';

/// Dims the real screen except [hole] and places [card] away from it.
///
/// Every touch outside the hole is absorbed, so nothing in the app can be
/// changed during the tour. Inside the hole touches reach the real widget
/// only when [passThrough] is true (e.g. tapping the "Rutinas" tab).
class TourSpotlight extends StatelessWidget {
  const TourSpotlight({super.key, required this.card, this.hole, this.passThrough = false});
  final Rect? hole;
  final bool passThrough;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = reduce ? Duration.zero : const Duration(milliseconds: 260);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final target = hole;
      // Card opposite to the highlighted element; centred low when there is none.
      final cardOnTop = target != null && target.center.dy > size.height * .55;
      // With large text the card can be taller than the screen: it gets the space
      // away from the highlight (at least half the screen) and its message scrolls,
      // so progress and buttons are always reachable.
      final safe = MediaQuery.paddingOf(context);
      final away = target == null ? size.height : cardOnTop ? target.top - 8 : size.height - target.bottom - 8;
      final maxCard = math.max(math.max(away, size.height * .5) - 24 - (cardOnTop ? safe.top : safe.bottom), 120.0);
      return Stack(children: [
        Positioned.fill(
          child: _HoleBarrier(
            hole: target?.inflate(6),
            passThrough: passThrough,
            child: target == null
                ? const CustomPaint(painter: _ScrimPainter(null))
                : TweenAnimationBuilder<Rect?>(
                    tween: RectTween(end: target.inflate(6)),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    builder: (context, rect, _) => CustomPaint(painter: _ScrimPainter(rect)),
                  ),
          ),
        ),
        if (target != null)
          AnimatedPositioned(
            duration: duration,
            curve: Curves.easeOutCubic,
            left: target.left - 8,
            top: target.top - 8,
            width: target.width + 16,
            height: target.height + 16,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Kora.lime, width: 3),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: cardOnTop ? 0 : null,
          bottom: cardOnTop ? null : 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(constraints: BoxConstraints(maxHeight: maxCard), child: card),
            ),
          ),
        ),
      ]);
    });
  }
}

class _ScrimPainter extends CustomPainter {
  const _ScrimPainter(this.hole);
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()..addRect(Offset.zero & size);
    final rect = hole;
    if (rect != null) {
      scrim
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)))
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(scrim, Paint()..color = Kora.forest.withValues(alpha: .72));
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole;
}

/// Absorbs every touch except, when [passThrough], those inside [hole]: for
/// those it reports "not hit", so the Stack hands them to the real screen.
class _HoleBarrier extends SingleChildRenderObjectWidget {
  const _HoleBarrier({required this.hole, required this.passThrough, super.child});
  final Rect? hole;
  final bool passThrough;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHoleBarrier(hole, passThrough);

  @override
  void updateRenderObject(BuildContext context, _RenderHoleBarrier renderObject) {
    renderObject
      ..hole = hole
      ..passThrough = passThrough;
  }
}

class _RenderHoleBarrier extends RenderProxyBox {
  _RenderHoleBarrier(this.hole, this.passThrough);
  Rect? hole;
  bool passThrough;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final target = hole;
    if (passThrough && target != null && target.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
