// Validates the Progreso tab against the data produced by
// docs/sql/seed_adherencia_demo.sql. The fixture is that seed exported in the
// exact shape of WeeklyMetricsResource and InterventionResource, so this test
// shows what a real user with 7 closed weeks sees, week by week.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

final fixture = jsonDecode(File('test/fixtures/adherencia_demo.json').readAsStringSync()) as Map<String, dynamic>;
final metrics = jsonRows(fixture['metrics']);          // newest week first, as the repository sorts
final interventions = jsonRows(fixture['interventions']);

String pct(num value) => metricValue(value, suffix: '%');
String pp(num value) => '${value >= 0 ? '+' : ''}${metricValue(value)} pp';

Future<void> openProgress(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 2200); tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(overrides: [
    currentPlanProvider.overrideWith((ref) async => null),
    weeklyMetricsProvider.overrideWith((ref) async => metrics),
    interventionsProvider.overrideWith((ref) async => interventions),
    dashboardProfileProvider.overrideWith((ref) async => null),
  ], child: MaterialApp(theme: AppTheme.light, home: const DashboardPage(initialTab: 2))));
  await tester.pumpAndSettle();
}

Future<void> selectWeek(WidgetTester tester, Map<String, dynamic> week) async {
  await tester.tap(find.byType(DropdownButton<String>)); await tester.pumpAndSettle();
  await tester.tap(find.text('Semana del ${displayDate(week['weekStartDate'])}').last); await tester.pumpAndSettle();
}

void main() {
  test('fixture matches the seed story (8 weeks, 7 measured)', () {
    expect(metrics.map((m) => m['weekNumber']), [7, 6, 5, 4, 3, 2, 1]);
    expect(metrics.map((m) => m['weightedAdherencePct']), [100.0, 94.63, 76.48, 16.67, 48.89, 82.22, 95.31]);
    expect(metrics.map((m) => m['riskLevel']), ['LOW', 'LOW', 'LOW', 'CRITICAL', 'MODERATE', 'LOW', 'LOW']);
    expect(interventions, hasLength(7));
    expect(interventions.where((i) => !(i['adjustmentTypes'] as List).contains('NONE')).map((i) => i['adjustmentTypes']),
        [['REDUCE_VOLUME'], ['REDUCE_DURATION']]);
  });

  testWidgets('the chart has one bar per week with its adherence', (tester) async {
    final semantics = tester.ensureSemantics();
    await openProgress(tester);
    expect(find.text('POR SEMANA · ÚLTIMOS 7 REGISTROS'), findsOneWidget);
    for (final week in metrics) {
      expect(find.bySemanticsLabel(RegExp(RegExp.escape('Semana del ${displayDate(week['weekStartDate'])}: ${pct(week['weightedAdherencePct'])}'))), findsOneWidget,
          reason: 'bar of week ${week['weekNumber']}');
    }
    // Default selection is the latest closed week.
    expect(find.text('100%'), findsOneWidget);
    expect(find.text(pp(100.0 - 94.63)), findsOneWidget);
    expect(find.textContaining('Riesgo de abandono: Bajo'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('every week shows its adherence, change, sessions, minutes and risk', (tester) async {
    await openProgress(tester);
    const risk = {'LOW': 'Bajo', 'MODERATE': 'Moderado', 'HIGH': 'Alto', 'CRITICAL': 'Crítico'};
    for (final (index, week) in metrics.indexed) {
      await selectWeek(tester, week);
      final value = week['weightedAdherencePct'] as num;
      final previous = index + 1 < metrics.length ? metrics[index + 1]['weightedAdherencePct'] as num : null;
      final label = 'week ${week['weekNumber']}';
      expect(find.text(pct(value)), findsOneWidget, reason: label);
      if (previous == null) {
        expect(find.textContaining(' pp'), findsNothing, reason: 'first week has no previous one');
      } else {
        expect(find.text(pp(value - previous)), findsOneWidget, reason: label);
      }
      expect(find.text('${metricValue(week['completedWorkouts'])} / ${metricValue(week['scheduledWorkouts'])}', findRichText: true), findsOneWidget, reason: label);
      expect(find.text('${week['totalTrainingMinutes']} min entrenados'), findsOneWidget, reason: label);
      expect(find.textContaining('Riesgo de abandono: ${risk[week['riskLevel']]}'), findsOneWidget, reason: label);
      expect(find.textContaining('Calculado: ${displayDate(week['calculatedAt'])}'), findsOneWidget, reason: label);
    }
  });

  testWidgets('the drop to 16.7 % and the recovery are visible', (tester) async {
    await openProgress(tester);
    final week4 = metrics.firstWhere((m) => m['weekNumber'] == 4);
    await selectWeek(tester, week4);
    expect(find.text('16.7%'), findsOneWidget);
    expect(find.text('-32.2 pp'), findsOneWidget);
    expect(find.textContaining('Riesgo de abandono: Crítico'), findsOneWidget);
    final week5 = metrics.firstWhere((m) => m['weekNumber'] == 5);
    await selectWeek(tester, week5);
    expect(find.text('76.5%'), findsOneWidget);
    expect(find.text('+59.8 pp'), findsOneWidget);
  });

  testWidgets('"Plan adaptado a ti" only for weeks whose plan came from a real adjustment', (tester) async {
    await openProgress(tester);
    final adaptedPlans = interventions
        .where((i) => (i['adjustmentTypes'] as List).any((t) => t != 'NONE'))
        .map((i) => i['resultingPlanId'])
        .toSet();
    for (final week in metrics) {
      await selectWeek(tester, week);
      final adapted = adaptedPlans.contains(week['planId']);
      expect(find.text(adapted ? 'Plan adaptado a ti' : 'Sin ajustes registrados'), findsOneWidget,
          reason: 'week ${week['weekNumber']}');
    }
    // Weeks 4 (shorter sessions) and 5 (fewer sets) were adapted.
    expect(metrics.where((m) => adaptedPlans.contains(m['planId'])).map((m) => m['weekNumber']), [5, 4]);
  });

  testWidgets('the adjustment summary lists every backend message, newest first', (tester) async {
    await openProgress(tester);
    for (final intervention in interventions) {
      final message = find.text('${intervention['messageShown']}');
      await tester.scrollUntilVisible(message, 200, scrollable: find.byType(Scrollable).first);
      expect(message, findsOneWidget);
      expect(find.text('Ajuste del ${displayDate(intervention['appliedAt'])}'), findsOneWidget);
    }
    expect(find.textContaining('llegabas cansado'), findsOneWidget);
    expect(find.textContaining('te falto tiempo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
