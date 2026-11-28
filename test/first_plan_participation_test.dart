// Option A in the first-plan generation (Backend PR #96): an account that is no
// longer an active participant (e.g. withdrew while the plan was prepared) sees
// its real state, never «Intentar de nuevo» towards a refusal; a 409 (the plan
// changed / a generation is running) is explained and leads to the current plan,
// without automatic retries. The 409 here comes from a SIMULATED backend.
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/features/authentication/domain/entities/user.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/presentation/first_plan_result_page.dart';
import 'package:fitsense_mobile/features/welcome/presentation/welcome_routes.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/welcome_fakes.dart';

/// A participant that, when the account is read again, has withdrawn.
class WithdrawsOnReload extends SignedIn {
  int reloads = 0;
  @override
  Future<void> loadCurrentUser() async {
    reloads++;
    state = AuthState(isAuthenticated: true, user: User(id: 7, firstName: 'Ana', lastName: 'Demo', email: 'ana7@example.com',
        timezone: 'America/Lima', studyParticipant: true, participantCode: 'P-007', withdrawnAt: DateTime.utc(2026, 11, 28)));
  }
}

/// A participant that stays one when read again.
class StaysParticipant extends SignedIn {
  int reloads = 0;
  @override
  Future<void> loadCurrentUser() async => reloads++;
}

/// `ApiErrorResource` with the stable code of Backend PR #96 in `details[0]`.
DioException coded(int status, String message, String code) {
  final options = RequestOptions(path: PlanGenerationRepository.path);
  return DioException(requestOptions: options, type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: status, data: {'status': status, 'message': message, 'details': [code]}));
}

class NoPlans extends PlanRepository {
  NoPlans() : super(Dio());
  @override
  Future<List<Map<String, dynamic>>> history() async => const [];
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({'access_token': 'jwt'}));

  Future<void> pumpResult(WidgetTester tester, FakeGeneration generation, SignedIn Function() auth) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: welcomeResultRoute, routes: [
      GoRoute(path: welcomeResultRoute, builder: (_, __) => const FirstPlanResultPage()),
      GoRoute(path: AppRoutes.accountSetup, builder: (_, __) => const Scaffold(body: Text('Preparando cuenta'))),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const Scaffold(body: Text('Login'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      authViewModelProvider.overrideWith(auth),
      planGenerationRepositoryProvider.overrideWithValue(generation),
      planRepositoryProvider.overrideWithValue(NoPlans()),
    ], child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)));
    await settle(tester);
  }

  testWidgets('422 PARTICIPACION_NO_VIGENTE: reads the account again and shows its real state; never asks again', (tester) async {
    late WithdrawsOnReload auth;
    final generation = FakeGeneration(starts: [coded(422, 'Tu cuenta no tiene una participacion activa en el estudio: Kora no puede preparar rutinas nuevas.', 'PARTICIPACION_NO_VIGENTE')]);
    await pumpResult(tester, generation, () => auth = WithdrawsOnReload());
    expect(auth.reloads, 1);
    expect(find.text('Preparando cuenta'), findsOneWidget, reason: 'the account setup shows «Te retiraste del estudio…»');
    await settle(tester, 40);
    expect(generation.startCalls, 1, reason: 'no new generation request');
  });

  testWidgets('withdrew while the plan was prepared (operation FAILED, not retryable): withdrawn state, no retry button', (tester) async {
    late WithdrawsOnReload auth;
    final generation = FakeGeneration(starts: [operation('PROCESSING')],
        finds: [operation('FAILED', reason: 'NO_GENERABLE', message: 'En este momento no es posible preparar tu rutina. Si persiste, contacta al equipo del estudio.')]);
    await pumpResult(tester, generation, () => auth = WithdrawsOnReload());
    await settle(tester, 50);
    expect(auth.reloads, 1);
    expect(find.text('Preparando cuenta'), findsOneWidget);
    expect(generation.startCalls, 1);
  });

  testWidgets('FAILED not retryable but still a participant: explained, contact offered, no navigation and no retry', (tester) async {
    late StaysParticipant auth;
    final generation = FakeGeneration(starts: [operation('FAILED', reason: 'NO_GENERABLE', message: 'En este momento no es posible preparar tu rutina.')]);
    await pumpResult(tester, generation, () => auth = StaysParticipant());
    await settle(tester, 30);
    expect(auth.reloads, 1, reason: 'the account is checked once');
    expect(find.text('Algo salió mal'), findsOneWidget);
    expect(find.text('Contactar al equipo'), findsOneWidget);
    expect(find.text('Intentar de nuevo'), findsNothing);
    expect(generation.startCalls, 1);
  });

  testWidgets('409 (simulated backend): explained, nothing obsolete shown, no automatic retry; leads to the current plan', (tester) async {
    final generation = FakeGeneration(starts: [coded(409, 'Tu plan cambio mientras se preparaba uno nuevo. Consulta el plan actual.', 'PLAN_CAMBIADO_DURANTE_LA_GENERACION')]);
    await pumpResult(tester, generation, StaysParticipant.new);
    expect(find.text('Tu plan cambió'), findsOneWidget);
    expect(find.textContaining('Tu plan cambio mientras se preparaba uno nuevo'), findsOneWidget);
    expect(find.textContaining('PLAN_CAMBIADO'), findsNothing, reason: 'no internal code on screen');
    expect(find.textContaining('lista'), findsNothing, reason: 'no plan presented as valid');
    await settle(tester, 40);
    expect(generation.startCalls, 1, reason: 'never retried on its own');
    await tester.tap(find.text('Consultar mi plan actual'));
    await settle(tester);
    expect(find.text('Preparando cuenta'), findsOneWidget, reason: 'the account setup reads the current plan');
  });
}

/// Polling and the mascot keep timers alive, so pumpAndSettle would not end.
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
