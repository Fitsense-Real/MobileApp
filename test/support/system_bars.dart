import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android 15+ draws apps edge to edge, and Android 16 (targetSdk 36) removes
/// the opt-out: the status bar and the gesture/navigation bar are drawn over
/// the app. Flutter reports them as MediaQuery padding.
const androidBars = EdgeInsets.only(top: 32, bottom: 48);

MediaQueryData edgeToEdge(Size size, {double textScale = 1, EdgeInsets bars = androidBars, double keyboard = 0}) =>
    MediaQueryData(
      size: size,
      padding: keyboard > 0 ? bars.copyWith(bottom: 0) : bars,
      viewPadding: bars,
      viewInsets: EdgeInsets.only(bottom: keyboard),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: true,
    );

/// Fails if a control that is not inside a scroll view lies under the system
/// bars (or the keyboard): there the user could not see or tap it.
void expectNothingUnderSystemBars(WidgetTester tester, {EdgeInsets bars = androidBars, double keyboard = 0, String where = ''}) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final top = bars.top;
  final bottom = size.height - (keyboard > 0 ? keyboard : bars.bottom);
  final controls = find.byWidgetPredicate((w) =>
      w is ButtonStyleButton || w is IconButton || w is TextField || w is Checkbox || w is Switch ||
      w is NavigationDestination || w is FloatingActionButton);
  final problems = <String>[];
  for (final element in controls.evaluate()) {
    if (element.findAncestorWidgetOfExactType<Scrollable>() != null) continue; // can be scrolled into view
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.isEmpty || rect.bottom <= 0 || rect.top >= size.height) continue;
    if (rect.top < top - 0.5 || rect.bottom > bottom + 0.5) {
      problems.add('${element.widget.runtimeType} $rect (visible area ${top.toStringAsFixed(0)}–${bottom.toStringAsFixed(0)})');
    }
  }
  expect(problems, isEmpty, reason: 'controls under the system bars $where');
}
