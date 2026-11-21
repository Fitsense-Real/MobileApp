import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Flutter 3.50: a ListTile inside a DecoratedBox with a background paints its
// ink on a Material *below* that background, so the press feedback was hidden.
// The Perfil cards now give their rows a transparent Material of their own.
void main() {
  testWidgets('Perfil rows paint their press feedback above the white card and still run their action', (tester) async {
    tester.view.physicalSize = const Size(420, 900); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentPlanProvider.overrideWith((ref) async => {'planId': 3, 'weekStartDate': '2026-10-26', 'weekEndDate': '2026-11-01', 'workouts': []}),
      weeklyMetricsProvider.overrideWith((ref) async => []),
      interventionsProvider.overrideWith((ref) async => []),
      dashboardProfileProvider.overrideWith((ref) async => {'goalText': 'Objetivo'}),
    ], child: MaterialApp(theme: AppTheme.light, home: const DashboardPage())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil')); await tester.pumpAndSettle();
    final row = find.widgetWithText(ListTile, 'Ayuda y soporte');
    await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    // The nearest Material of the row is the card's own transparent one, and
    // it sits inside the white decorated card (not under it).
    final material = find.ancestor(of: row, matching: find.byType(Material)).first;
    final widget = tester.widget<Material>(material);
    expect(widget.type, MaterialType.transparency);
    expect(widget.clipBehavior, Clip.antiAlias, reason: 'ink stays inside the rounded corners');
    final whiteCard = find.ancestor(of: material, matching: find.byWidgetPredicate((w) =>
        w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == Colors.white));
    expect(whiteCard, findsWidgets);

    // Pressing adds the splash and the highlight to that Material (before it
    // only holds the tiles' own InkDecoration backgrounds), the same check the
    // Flutter framework uses in its own tests.
    final ink = Material.of(tester.element(row));
    final before = (((ink as dynamic).debugInkFeatures as List?) ?? const []).length;
    final gesture = await tester.startGesture(tester.getCenter(row));
    await tester.pump(const Duration(milliseconds: 200));
    expect(((ink as dynamic).debugInkFeatures as List).length, greaterThan(before), reason: 'the press adds a splash and a highlight');
    await gesture.up(); await tester.pumpAndSettle();

    // And the tap still runs the row's action.
    expect(find.text('Tu entrenamiento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
