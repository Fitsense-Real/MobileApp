import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/kora_ui.dart';

typedef Clock = DateTime Function();

/// Active time of a live session, measured from the backend's `startedAt`.
/// Pauses exist only on this device: the backend has no pause, so they are
/// reflected through the `activeMinutes` suggested when finishing.
class SessionClock {
  SessionClock(this.startedAt);
  final DateTime startedAt;
  Duration _paused = Duration.zero;
  DateTime? _pausedAt;

  bool get isPaused => _pausedAt != null;

  Duration active(DateTime now) {
    final elapsed = (_pausedAt ?? now).difference(startedAt) - _paused;
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  void pause(DateTime now) => _pausedAt ??= now;

  void resume(DateTime now) {
    final since = _pausedAt;
    if (since == null) return;
    _paused += now.difference(since);
    _pausedAt = null;
  }

  /// Minutes for `FinishSessionResource.activeMinutes` (a Short, >= 0).
  int suggestedActiveMinutes(DateTime now) =>
      math.max(1, (active(now).inSeconds / 60).round()).clamp(1, 600);
}

/// Clocks by session id, so leaving the routine and coming back keeps the
/// pauses while the app is alive.
class SessionClocks {
  SessionClocks._();
  static final _clocks = <Object, SessionClock>{};
  static SessionClock of(Object sessionId, DateTime startedAt) =>
      _clocks.putIfAbsent(sessionId, () => SessionClock(startedAt));
  static void clear(Object? sessionId) => _clocks.remove(sessionId);
}

String formatClock(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// "Tiempo activo 12:34" with pause/resume, shown during a live session.
class SessionTimerBar extends StatefulWidget {
  const SessionTimerBar({super.key, required this.clock, this.now = DateTime.now});
  final SessionClock clock;
  final Clock now;
  @override
  State<SessionTimerBar> createState() => _SessionTimerBarState();
}

class _SessionTimerBarState extends State<SessionTimerBar> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clock = widget.clock;
    return KoraCard(child: Row(children: [
      Icon(clock.isPaused ? Icons.pause_circle_outline : Icons.timer_outlined, color: Kora.forest),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(clock.isPaused ? 'En pausa' : 'Tiempo activo', style: const TextStyle(color: Kora.muted, fontSize: 12)),
        Semantics(
          liveRegion: false,
          label: 'Tiempo activo ${formatClock(clock.active(widget.now()))}',
          child: Text(formatClock(clock.active(widget.now())),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
        ),
      ])),
      TextButton.icon(
        onPressed: () => setState(() => clock.isPaused ? clock.resume(widget.now()) : clock.pause(widget.now())),
        icon: Icon(clock.isPaused ? Icons.play_arrow : Icons.pause),
        label: Text(clock.isPaused ? 'Reanudar' : 'Pausar'),
      ),
    ]));
  }
}

/// Opens a countdown (rest between sets, or a timed set).
Future<void> showCountdown(BuildContext context, {required int seconds, required String title, String? subtitle}) =>
    showDialog<void>(context: context, barrierDismissible: false,
        builder: (_) => CountdownDialog(seconds: seconds, title: title, subtitle: subtitle));

class CountdownDialog extends StatefulWidget {
  const CountdownDialog({super.key, required this.seconds, required this.title, this.subtitle});
  final int seconds;
  final String title;
  final String? subtitle;
  @override
  State<CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<CountdownDialog> {
  late int remaining = widget.seconds;
  late int total = widget.seconds;
  Timer? _ticker;

  bool get done => remaining <= 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted || done) return;
    setState(() => remaining--);
    if (done) {
      _ticker?.cancel();
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } else if (remaining <= 3) {
      HapticFeedback.selectionClick();
    }
  }

  // Only offered while the countdown runs, so the ticker is still active.
  void _addTime() => setState(() {
    remaining += 15;
    total += 15;
  });

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      if (widget.subtitle != null) Text(widget.subtitle!, style: const TextStyle(color: Kora.muted)),
      const SizedBox(height: 20),
      SizedBox(width: 150, height: 150, child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(child: CircularProgressIndicator(
          value: total <= 0 ? 0 : remaining / total,
          strokeWidth: 8, color: Kora.lime, backgroundColor: Kora.ivory,
        )),
        Text(done ? '¡Listo!' : formatClock(Duration(seconds: remaining)),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
      ])),
    ]),
    actions: [
      if (!done) TextButton(onPressed: _addTime, child: const Text('+15 s')),
      FilledButton(onPressed: () => Navigator.pop(context), child: Text(done ? 'Continuar' : 'Saltar')),
    ],
  );
}
