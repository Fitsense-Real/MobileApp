import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/data/welcome_store.dart';
import 'package:fitsense_mobile/features/welcome/presentation/first_plan_result_page.dart';
import 'package:fitsense_mobile/features/welcome/presentation/tour/tour_steps.dart';
import 'package:fitsense_mobile/features/welcome/presentation/welcome_routes.dart';
import 'package:fitsense_mobile/features/welcome/presentation/welcome_tour_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/welcome_fakes.dart';

class PlansById extends PlanRepository {
  PlansById() : super(Dio());
  final requested = <Object>[];
  @override
  Future<Json> byId(Object id) async {
    requested.add(id);
    return {'planId': id, 'weekStartDate': '2026-11-16', 'workouts': [{}, {}, {}]};
  }
}

int realDataReads = 0;

Future<GoRouter> pumpWelcome(WidgetTester tester, FakeGeneration generation, {String location = welcomeTourRoute, PlansById? plans, Size size = const Size(420, 900), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  realDataReads = 0;
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(path: welcomeTourRoute, builder: (_, state) => WelcomeTourPage(replay: state.uri.queryParameters['repaso'] == '1')),
    GoRoute(path: welcomeResultRoute, builder: (_, __) => const FirstPlanResultPage()),
    GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('Mi plan'))),
    GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith(SignedIn.new),
      planGenerationRepositoryProvider.overrideWithValue(generation),
      planRepositoryProvider.overrideWithValue(plans ?? PlansById()),
      // The tour must not read the user's real data: any read is counted.
      currentPlanProvider.overrideWith((ref) async { realDataReads++; return null; }),
      weeklyMetricsProvider.overrideWith((ref) async { realDataReads++; return []; }),
      interventionsProvider.overrideWith((ref) async { realDataReads++; return []; }),
    ],
    child: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale), disableAnimations: true),
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    ),
  ));
  await settle(tester);
  return router;
}

/// Polling and the mascot keep timers alive, so pumpAndSettle would not end.
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.byType(FilledButton).last);
  await settle(tester);
}

Future<WelcomeProgress> stored() => WelcomeStore().load(7);

Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('1 · the tour starts at once and the generation is requested at the same time', (tester) async {
    final generation = FakeGeneration();
    await pumpWelcome(tester, generation);
    expect(find.text('PASO 1 DE ${welcomeTourSteps.length}'), findsOneWidget);
    expect(find.text('¡Hola! Soy Kapi'), findsOneWidget);
    expect(generation.startCalls, 1);
    expect(find.textContaining('Saltar'), findsNothing, reason: 'mandatory the first time');
    expect(find.textContaining('Omitir'), findsNothing);
    expect((await stored()).tourStatus, TourStatus.inProgress);
    await disposeTree(tester);
  });

  testWidgets('forward, back and progress saved at every step', (tester) async {
    await pumpWelcome(tester, FakeGeneration());
    await tapNext(tester);
    expect(find.text('Tu plan de la semana'), findsWidgets);
    expect(find.text('PASO 2 DE ${welcomeTourSteps.length}'), findsOneWidget);
    expect((await stored()).tourStep, 1);
    await tester.tap(find.text('Atrás')); await settle(tester);
    expect(find.text('PASO 1 DE ${welcomeTourSteps.length}'), findsOneWidget);
    expect((await stored()).tourStep, 0);
    await disposeTree(tester);
  });

  testWidgets('interactive step: only the highlighted real tab can be tapped', (tester) async {
    await pumpWelcome(tester, FakeGeneration());
    await tapNext(tester); // plan card
    await tapNext(tester); // "Toca Rutinas"
    expect(find.text('Toca «Rutinas» para ver dónde estarán tus entrenamientos.'), findsOneWidget);
    // A different tab is outside the hole: the touch is absorbed.
    await tester.tap(find.text('Progreso'), warnIfMissed: false); await settle(tester);
    expect(find.text('PASO 3 DE ${welcomeTourSteps.length}'), findsOneWidget);
    // The highlighted real tab opens Rutinas and advances.
    await tester.tap(find.text('Rutinas'), warnIfMissed: false); await settle(tester);
    expect(find.text('PASO 4 DE ${welcomeTourSteps.length}'), findsOneWidget);
    expect(find.textContaining('Tu primera rutina se está preparando'), findsOneWidget, reason: 'honest empty state, no fake workouts');
    await disposeTree(tester);
  });

  testWidgets('4, 5, 6 · closing the app mid-tour resumes at the same step, never marked completed', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'kora_welcome_7': jsonEncode({'tourStatus': 'inProgress', 'tourStep': 5, 'operationId': operationId})});
    final generation = FakeGeneration(finds: [operation('PROCESSING')]);
    await pumpWelcome(tester, generation);
    expect(find.text('PASO 6 DE ${welcomeTourSteps.length}'), findsOneWidget);
    expect(generation.foundIds.first, operationId, reason: 'the generation is resumed too');
    expect(generation.startCalls, 0);
    await disposeTree(tester); // "closing the app"
    expect((await stored()).tourStatus, TourStatus.inProgress);
  });

  testWidgets('17 · the whole tour reads no user data and ends in the result screen', (tester) async {
    final generation = FakeGeneration(finds: [operation('PROCESSING')]);
    await pumpWelcome(tester, generation);
    for (var i = 0; i < welcomeTourSteps.length; i++) {
      expect(find.text('PASO ${i + 1} DE ${welcomeTourSteps.length}'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapNext(tester);
    }
    expect(find.text('¡Ya conoces Kora!'), findsOneWidget, reason: 'case B: still generating');
    expect((await stored()).tourStatus, TourStatus.completed);
    expect(realDataReads, 0, reason: 'the first plan is presented only after the tour');
    expect(generation.startCalls, 1);
    await disposeTree(tester);
  });

  testWidgets('16 · every step fits a 320 px screen with 1.3 text scale', (tester) async {
    await pumpWelcome(tester, FakeGeneration(), size: const Size(320, 640), textScale: 1.3);
    for (var i = 0; i < welcomeTourSteps.length - 1; i++) {
      expect(tester.takeException(), isNull, reason: 'step ${i + 1}');
      await tapNext(tester);
    }
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('15 · replay from Perfil: no generation and progress untouched', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'kora_welcome_7': jsonEncode({'tourStatus': 'completed', 'tourStep': 9})});
    final generation = FakeGeneration();
    await pumpWelcome(tester, generation, location: welcomeReplayRoute);
    expect(find.text('PASO 1 DE ${welcomeTourSteps.length}'), findsOneWidget);
    await tapNext(tester);
    expect(generation.startCalls, 0);
    expect((await stored()).tourStatus, TourStatus.completed);
    expect((await stored()).tourStep, 9);
    await disposeTree(tester);
  });

  group('result screen', () {
    testWidgets('A · generation finished before the tour: the plan is presented after it', (tester) async {
      final plans = PlansById();
      final generation = FakeGeneration(starts: [operation('COMPLETED', planId: 42)], finds: [operation('COMPLETED', planId: 42)]);
      await pumpWelcome(tester, generation, location: welcomeResultRoute, plans: plans);
      expect(find.text('¡Tu primera rutina está lista!'), findsOneWidget);
      expect(find.textContaining('3 entrenamientos'), findsOneWidget);
      expect(plans.requested, [42]);
      await tester.tap(find.text('Ver mi plan')); await settle(tester);
      expect(find.text('Mi plan'), findsOneWidget);
      expect((await stored()).operationId, isNull);
    });

    testWidgets('B · still generating: waiting message without percentages, then the plan', (tester) async {
      final generation = FakeGeneration(starts: [operation('PROCESSING')], finds: [operation('PROCESSING'), operation('COMPLETED', planId: 8)]);
      await pumpWelcome(tester, generation, location: welcomeResultRoute);
      expect(find.text('¡Ya conoces Kora!'), findsOneWidget);
      expect(find.textContaining('Estamos terminando de preparar tu primera rutina'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      await settle(tester, 40); // two polls of 3 s
      await settle(tester, 40);
      expect(find.text('¡Tu primera rutina está lista!'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('C · NO_FACTIBLE explains it, offers contact and never retries on its own', (tester) async {
      final generation = FakeGeneration(starts: [operation('NO_FACTIBLE', reason: 'SIN_SEMANA_GENERABLE', message: 'Con tus restricciones actuales no fue posible generar una semana válida.')]);
      await pumpWelcome(tester, generation, location: welcomeResultRoute);
      expect(find.text('No encontramos una rutina compatible'), findsOneWidget);
      expect(find.textContaining('Con tus restricciones actuales'), findsOneWidget);
      expect(find.textContaining('no relaja tus restricciones'), findsOneWidget);
      expect(find.text('Intentar de nuevo'), findsNothing);
      expect(find.text('Contactar al equipo'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget, reason: 'never trapped');
      expect(generation.startCalls, 1);
      await disposeTree(tester);
    });

    testWidgets('C · a retryable technical failure offers a safe retry', (tester) async {
      final generation = FakeGeneration(
        starts: [operation('FAILED', reason: 'ERROR_TECNICO', message: 'No pudimos preparar tu rutina por un problema técnico.', retryable: true), operation('PENDING', id: 'op-2')],
        finds: [operation('PROCESSING', id: 'op-2')],
      );
      await pumpWelcome(tester, generation, location: welcomeResultRoute);
      expect(find.text('Algo salió mal'), findsOneWidget);
      await tester.tap(find.text('Intentar de nuevo')); await settle(tester);
      expect(generation.startCalls, 2);
      expect(find.text('¡Ya conoces Kora!'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('13 · without connection it says so and can check again', (tester) async {
      final generation = FakeGeneration(starts: [operation('PROCESSING')], finds: [offline()]);
      await pumpWelcome(tester, generation, location: welcomeResultRoute);
      await settle(tester, 40);
      expect(find.text('Seguimos intentando'), findsOneWidget);
      expect(find.textContaining('No hay conexión'), findsOneWidget);
      expect(find.text('Consultar ahora'), findsOneWidget);
      await disposeTree(tester);
    });

    testWidgets('a 5xx is presented as a server problem, not as missing connection', (tester) async {
      final generation = FakeGeneration(starts: [operation('PROCESSING')], finds: [httpError(503)]);
      await pumpWelcome(tester, generation, location: welcomeResultRoute);
      await settle(tester, 40);
      expect(find.textContaining('El servidor no responde'), findsOneWidget);
      expect(find.textContaining('No hay conexión'), findsNothing);
      await disposeTree(tester);
    });
  });
}
