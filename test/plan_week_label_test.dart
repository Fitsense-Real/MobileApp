import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/dashboard/domain/plan_week_label.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

String iso(DateTime d) => d.toIso8601String().substring(0, 10);

void main() {
  // Week of the first plan seen in the E2E: Monday 16/11/2026 to Sunday 22/11/2026.
  String? label(DateTime now, {Object? start = '2026-11-16', Object? end = '2026-11-22'}) =>
      planWeekLabel(weekStartDate: start, weekEndDate: end, now: now);

  group('planWeekLabel', () {
    test('regression «8 DÍAS»: a plan that starts tomorrow says so', () {
      expect(label(DateTime(2026, 11, 15, 22, 35)), 'EMPIEZA MAÑANA');
    });
    test('a plan that starts in several days counts the days to its start', () {
      expect(label(DateTime(2026, 11, 10, 9)), 'EMPIEZA EN 6 DÍAS');
    });
    test('the plan starts today: its seven days are left', () {
      expect(label(DateTime(2026, 11, 16, 0, 0)), '7 DÍAS');
    });
    test('mid-week counts today', () {
      expect(label(DateTime(2026, 11, 18, 12)), '5 DÍAS');
    });
    test('day change: 23:59 and 00:00 belong to different days, the time does not matter', () {
      expect(label(DateTime(2026, 11, 20, 23, 59)), '3 DÍAS');
      expect(label(DateTime(2026, 11, 21, 0, 0)), '2 DÍAS');
    });
    test('last day of the week', () {
      expect(label(DateTime(2026, 11, 22, 20)), 'ÚLTIMO DÍA');
    });
    test('after the week nothing is shown', () {
      expect(label(DateTime(2026, 11, 23, 8)), isNull);
    });
    test('a week across the end of October (daylight-saving change in other zones) keeps 7 days', () {
      expect(label(DateTime(2026, 10, 26, 7), start: '2026-10-26', end: '2026-11-01'), '7 DÍAS');
      expect(label(DateTime(2026, 3, 30, 7), start: '2026-03-30', end: '2026-04-05'), '7 DÍAS');
    });
    test('missing, invalid or inverted dates show nothing', () {
      final now = DateTime(2026, 11, 18);
      expect(label(now, start: null), isNull);
      expect(label(now, end: null), isNull);
      expect(label(now, start: 'Sin fecha'), isNull);
      expect(label(now, start: '2026-11-22', end: '2026-11-16'), isNull);
    });
  });

  testWidgets('the real plan card never says «8 DÍAS» the day before the plan', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day + 1);
    final end = DateTime(start.year, start.month, start.day + 6);
    await tester.pumpWidget(ProviderScope(overrides: [
      currentPlanProvider.overrideWith((ref) async => {'planId': 1, 'weekStartDate': iso(start), 'weekEndDate': iso(end), 'workouts': []}),
      weeklyMetricsProvider.overrideWith((ref) async => []),
      interventionsProvider.overrideWith((ref) async => []),
      dashboardProfileProvider.overrideWith((ref) async => null),
    ], child: MaterialApp(theme: AppTheme.light, home: const DashboardPage())));
    await tester.pumpAndSettle();
    expect(find.text('EMPIEZA MAÑANA'), findsOneWidget);
    expect(find.textContaining('8 DÍAS'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
