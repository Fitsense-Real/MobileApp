// P2 · the adaptation history in plain words. Exact codes of the backend (generation 98276a9:
// AdaptationOutcome.resultado, AdaptationDecision, plan.adjustmentApplied); real answers from the
// Demo Kora fixture where possible.
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/widgets/plan_history_sheet.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/plans/domain/adaptation_text.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'support/welcome_fakes.dart' show SignedIn;

Json fixture(String path) => (jsonDecode(File('test/fixtures/o20_demo_kora/$path.json').readAsStringSync()) as Map<String, dynamic>)['data'] as Json;
List<Json> fixtureRows(String path) => jsonRows((jsonDecode(File('test/fixtures/o20_demo_kora/$path.json').readAsStringSync()) as Map)['data']);

/// Every `resultado` the backend can send (AdaptationOutcome.de, AdaptationOutcomeQueryService) and RECHAZADA,
/// the only V32 status without its own result.
const backendOutcomes = [
  'ADAPTACION_APLICADA', 'REGENERACION_SEGURA_SUSTITUCION', 'REGENERACION_SEGURA_REGLAS', 'PROGRESION_DEL_BACKEND',
  'SIN_ADAPTACION', 'CONSERVACION_DELIBERADA', 'SIN_CAMBIOS_VALIDOS', 'RESPALDO_PROPUESTA_IA_INVALIDA', 'RESPALDO_SIN_IA',
  'ACORTAMIENTO_IMPOSIBLE', 'REPROGRAMACION_IMPOSIBLE', 'ADAPTACION_IMPOSIBLE', 'RECHAZADA', 'NO_FACTIBLE_POR_SEGURIDAD', 'NO_FACTIBLE',
];
final codePattern = RegExp(r'\b[A-Z]{2,}_[A-Z_]+\b');

class FakePlans extends PlanRepository {
  FakePlans(this.plans, this.rows) : super(Dio());
  List<Json> plans, rows;
  int adaptationReads = 0;
  @override
  Future<List<Json>> history() async => plans;
  @override
  Future<List<Json>> adaptations() async { adaptationReads++; return rows; }
  @override
  Future<Json> byId(Object id) async => fixture('_users_me_plan_$id');
}

void main() {
  final reported = <String>[];
  setUp(() {
    reported.clear();
    reportUnknownCode = reported.add;
  });

  group('the week outcome in plain words', () {
    test('1 · localized adaptation that changed a session', () {
      final text = describeAdaptation({'weekStartDate': '2026-11-16', 'resultado': 'ADAPTACION_APLICADA', 'decision': 'ADAPT_LOCALIZED',
        'sesiones': [{'origenPlannedWorkoutId': 7, 'intervencion': 'ACORTAR_O_REORGANIZAR', 'resultado': 'APLICADA'}]});
      expect(text.title, 'Se ajustó parte de tu rutina');
      expect(text.kind, AdaptationKind.changed);
      expect(text.details, ['1 sesión con cambios.', 'Algunas sesiones tuvieron menos cumplimiento: Kora revisó esas sesiones.']);
    });

    test('2 · expanded adaptation (several sessions)', () {
      final text = describeAdaptation({'resultado': 'ADAPTACION_APLICADA', 'decision': 'ADAPT_EXPANDED',
        'sesiones': [for (final id in [1, 2, 3]) {'origenPlannedWorkoutId': id, 'resultado': 'APLICADA'}]});
      expect(text.details, ['3 sesiones con cambios.', 'Varias sesiones tuvieron menos cumplimiento: Kora revisó varias sesiones.']);
    });

    test('3 · no change (real answer of the demo week 16/11)', () {
      final text = describeAdaptation(fixtureRows('_users_me_plan_adaptations')[1]);
      expect(text.title, 'Tu rutina se mantiene igual');
      expect(text.kind, AdaptationKind.kept);
      expect(text.details, ['Tus registros no mostraban baja adherencia, así que no hacía falta un ajuste.']);
    });

    test('progression (real answer of the demo week 23/11): it says why, without contradicting itself', () {
      final text = describeAdaptation(fixtureRows('_users_me_plan_adaptations')[2]);
      expect(text.title, 'Tu rutina avanzó un paso');
      expect(text.kind, AdaptationKind.changed);
      expect(text.details, ['Con tu buen cumplimiento, Kora subió un poco la exigencia de tu rutina.']);
    });

    test('4 · insufficient data: not a «no change», it is that it cannot be known', () {
      final text = describeAdaptation({'resultado': 'SIN_ADAPTACION', 'decision': 'INSUFFICIENT_DATA'});
      expect(text.title, 'Tu rutina se mantiene igual');
      expect(text.details, ['Aún faltaban entrenamientos registrados para evaluar cambios.']);
    });

    test('5 · not feasible: explained without presenting a routine that does not exist', () {
      final text = describeAdaptation({'weekStartDate': '2026-12-07', 'resultado': 'NO_FACTIBLE_POR_SEGURIDAD', 'estadoPublicacion': 'NO_PUBLICADO',
        'decision': 'ADAPT_EXPANDED', 'motivoTexto': 'No pudimos preparar una alternativa segura para la sesión en la que registraste molestias.',
        'motivos': ['Sin respuesta de la IA no se puede resolver el dolor de las sesiones [37, 38]'], 'resultingPlanId': null});
      expect(text.kind, AdaptationKind.notFeasible);
      expect(text.title, 'Kora no pudo adaptar esa semana sin volver a proponer lo que te dolió');
      expect(text.reason, 'No pudimos preparar una alternativa segura para la sesión en la que registraste molestias.');
      expect(text.details.first, 'No se publicó una rutina nueva para esa semana.');
      expect([text.title, text.reason, ...text.details].join(' '), isNot(contains('[37, 38]')), reason: 'internal motivos are not shown');
    });

    test('6 · unknown result: a general text, the code reported for diagnosis and never shown', () {
      final text = describeAdaptation({'weekStartDate': '2027-01-04', 'resultado': 'NUEVO_RESULTADO_X', 'decision': 'DECISION_NUEVA'});
      expect(text.title, 'Kora revisó tu plan de esa semana');
      expect(text.kind, AdaptationKind.unknown);
      expect([text.title, ...text.details].any((t) => t.contains('NUEVO_RESULTADO_X') || t.contains('DECISION_NUEVA')), isFalse);
      expect(reported, hasLength(2));
      expect(reported.first, contains('NUEVO_RESULTADO_X'));
    });

    test('every result the backend can send has its own text, without codes; applied and rejected are told apart', () {
      for (final code in backendOutcomes) {
        final text = describeAdaptation({'resultado': code});
        expect(text.kind, isNot(AdaptationKind.unknown), reason: code);
        expect(codePattern.hasMatch(text.title), isFalse, reason: '$code → ${text.title}');
      }
      expect(reported, isEmpty);
      expect(describeAdaptation({'resultado': 'ADAPTACION_APLICADA'}).kind, AdaptationKind.changed);
      for (final rejected in ['RESPALDO_PROPUESTA_IA_INVALIDA', 'SIN_CAMBIOS_VALIDOS', 'RECHAZADA']) {
        expect(describeAdaptation({'resultado': rejected}).kind, AdaptationKind.kept, reason: '$rejected is not an adaptation carried out');
        expect(describeAdaptation({'resultado': rejected}).title, contains('se mantiene igual'));
      }
    });

    test('the data is not altered', () {
      final row = fixtureRows('_users_me_plan_adaptations').first;
      final before = jsonEncode(row);
      describeAdaptation(row);
      planHistoryLabel(fixture('_users_me_plan_910000001'), [row]);
      expect(jsonEncode(row), before);
    });
  });

  group('plan history', () {
    test('the substitution for pain of the demo (adjustmentApplied ADAPT_LOCALIZED) no longer shows the code', () {
      final plans = fixtureRows('_users_me_plans');
      final adaptations = fixtureRows('_users_me_plan_adaptations');
      final labels = {for (final p in plans) p['planId']: planHistoryLabel(p, adaptations)};
      expect(labels, {910000003: 'Progresión', 910000002: 'Sin cambios', 910000001: 'Sustitución por seguridad', 910000000: null});
      expect(planHistoryLabel(plans.firstWhere((p) => p['planId'] == 910000001), const []), 'Revisión de parte de tu rutina',
          reason: 'without the adaptation record, the decision does not claim a change');
      expect(planHistoryLabel({'adjustmentApplied': 'SAFETY_REPAIR'}, const []), 'Ajustada por seguridad');
      expect(planHistoryLabel({'adjustmentApplied': 'REDUCE_VOLUME'}, const []), 'Menos volumen');
      expect(planHistoryLabel({'planId': 9, 'adjustmentApplied': 'OTRO_AJUSTE'}, const []), 'Plan ajustado');
      expect(reported.single, contains('OTRO_AJUSTE'));
    });

    testWidgets('7 · history of several weeks: titles in plain words, no codes on screen', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final plans = FakePlans(fixtureRows('_users_me_plans'), fixtureRows('_users_me_plan_adaptations'));
      await tester.pumpWidget(ProviderScope(overrides: [
        authViewModelProvider.overrideWith(() => SignedIn()),
        planRepositoryProvider.overrideWithValue(plans),
        planHistoryProvider.overrideWith((ref) => plans.history()),
      ], child: const MaterialApp(home: Scaffold(body: PlanHistorySheet()))));
      await tester.pumpAndSettle();
      expect(find.text('Completado · 5 días · Sustitución por seguridad'), findsOneWidget);
      expect(find.text('Vigente · 5 días · Progresión'), findsOneWidget);
      expect(find.text('Completado · 5 días · Sin cambios'), findsOneWidget);
      expect(find.textContaining('ADAPT_'), findsNothing);
      // The week itself explains what happened, with the session the backend names.
      await tester.tap(find.textContaining('Semana del 09/11/2026'));
      await tester.pumpAndSettle();
      expect(find.text('Se sustituyó un ejercicio por seguridad'), findsOneWidget);
      expect(find.text('Sesión revisada: jueves 05/11 (Tren superior).'), findsOneWidget);
      expect(find.text('Algunas sesiones tuvieron menos cumplimiento: Kora revisó esas sesiones.'), findsOneWidget);
    });

    testWidgets('8 · updated after asking the backend again', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final rows = fixtureRows('_users_me_plan_adaptations');
      final plans = FakePlans(fixtureRows('_users_me_plans'), rows.take(2).toList());
      final container = ProviderContainer(overrides: [
        authViewModelProvider.overrideWith(() => SignedIn()),
        planRepositoryProvider.overrideWithValue(plans),
        planHistoryProvider.overrideWith((ref) => plans.history()),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(container: container,
          child: const MaterialApp(home: Scaffold(body: PlanHistorySheet()))));
      await tester.pumpAndSettle();
      expect(find.text('Vigente · 5 días · Progresión'), findsNothing, reason: 'the backend has not reported that week yet');
      final reads = plans.adaptationReads;
      plans.rows = rows; // the backend now reports the progression of 23/11
      container.invalidate(planAdaptationsProvider);
      await tester.pumpAndSettle();
      expect(plans.adaptationReads, greaterThan(reads));
      expect(find.text('Vigente · 5 días · Progresión'), findsOneWidget);
    });
  });
}
