import 'dart:math' as math;
import 'package:flutter/material.dart';

abstract final class Kora {
  static const lime = Color(0xFFD9FF59);
  static const forest = Color(0xFF0F2E25);
  static const ivory = Color(0xFFF7F5ED);
  static const sage = Color(0xFF7A9A7E);
  static const muted = Color(0xFF5E7865);
}

class KoraPattern extends CustomPainter {
  const KoraPattern({this.color = const Color(0x18D9FF59)});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32;
    for (double y = 60; y < size.height; y += 320) {
      final path = Path();
      for (double x = -40; x < size.width + 40; x += 2) {
        final dy = y + math.sin(x / 45) * 20;
        if (x == -40) {
          path.moveTo(x, dy);
        } else {
          path.lineTo(x, dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(KoraPattern oldDelegate) => color != oldDelegate.color;
}

class KoraPage extends StatelessWidget {
  const KoraPage({
    super.key,
    required this.child,
    this.bottomNavigationBar,
    this.maxWidth = 760,
    this.patternColor = const Color(0x18D9FF59),
  });
  final Widget child;
  final Widget? bottomNavigationBar;
  final double maxWidth;
  final Color patternColor;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Kora.ivory,
    bottomNavigationBar: bottomNavigationBar,
    body: CustomPaint(
      painter: KoraPattern(color: patternColor),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    ),
  );
}

class KoraLogo extends StatelessWidget {
  const KoraLogo({super.key, this.width = 104});
  final double width;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/kora/logo.png',
    width: width,
    semanticLabel: 'Kora',
  );
}

class KoraButton extends StatelessWidget {
  const KoraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.lime = false,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool lime;
  final bool busy;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: lime ? Kora.lime : Kora.forest,
      foregroundColor: lime ? Kora.forest : Colors.white,
      minimumSize: const Size(double.infinity, 58),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
  );
}

class KoraHeading extends StatelessWidget {
  const KoraHeading(this.title, {super.key, this.accent, this.subtitle});
  final String title;
  final String? accent;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          text: title,
          children: [
            if (accent != null)
              TextSpan(
                text: '\n$accent',
                style: const TextStyle(color: Kora.sage),
              ),
          ],
        ),
        style: const TextStyle(
          color: Kora.forest,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.12,
          letterSpacing: -1.2,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 16),
        Text(subtitle!, style: const TextStyle(color: Kora.muted, height: 1.6)),
      ],
    ],
  );
}

class KoraCard extends StatelessWidget {
  const KoraCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Kora.forest.withValues(alpha: .04)),
      boxShadow: [
        BoxShadow(
          color: Kora.forest.withValues(alpha: .04),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class KoraLabel extends StatelessWidget {
  const KoraLabel(this.text, {super.key, this.color = Kora.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: color,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
}
