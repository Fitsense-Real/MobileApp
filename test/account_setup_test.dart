import 'dart:async';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/plans/presentation/account_setup_page.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/presentation/welcome_routes.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:fitsense_mobile/features/consents/data/consents_repository.dart';
import 'support/consents_fakes.dart';
import 'support/welcome_fakes.dart';

class ProfileStub extends ProfileRepository {
  ProfileStub(this.profile) : super(Dio());
  final Map<String, dynamic>? profile;
  @override
  Future<Map<String, dynamic>?> fetch() async => profile;
}

class PlanStub extends PlanRepository {
  PlanStub(this.plan) : super(Dio());
  Map<String, dynamic>? plan;
  int reads = 0;
  final attempts = <Completer<Map<String, dynamic>>>[];
  @override
  Future<Map<String, dynamic>?> current() async { reads++; return plan; }
  @override
  Future<Map<String, dynamic>> generate() {
    final result = Completer<Map<String, dynamic>>();
    attempts.add(result);
    return result.future;
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> open(WidgetTester tester, Map<String, dynamic>? profile, PlanStub plans, {FakeGeneration? generation, ConsentsStub? consents, SignedIn Function()? user}) async {
    tester.view.physicalSize = const Size(1080, 4800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/account-setup', routes: [
      GoRoute(path: '/account-setup', builder: (_, __) => const AccountSetupPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const Scaffold(body: Text('Crear perfil'))),
      GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('Inicio'))),
      GoRoute(path: welcomeTourRoute, builder: (_, __) => const Scaffold(body: Text('Recorrido'))),
      GoRoute(path: welcomeResultRoute, builder: (_, __) => const Scaffold(body: Text('Resultado'))),
      GoRoute(path: '/consentimientos', builder: (_, __) => const Scaffold(body: Text('Consentimientos'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      authViewModelProvider.overrideWith(user ?? SignedIn.new),
      profileRepositoryProvider.overrideWithValue(ProfileStub(profile)),
      planRepositoryProvider.overrideWithValue(plans),
      planGenerationRepositoryProvider.overrideWithValue(generation ?? FakeGeneration()),
      consentsRepositoryProvider.overrideWithValue(consents ?? ConsentsStub(consentsJson())),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Without profile opens onboarding without querying or generating a plan', (tester) async {
    final plans = PlanStub(null);
    await open(tester, null, plans);
    await tester.pumpAndSettle();
    expect(find.text('Crear perfil'), findsOneWidget);
    expect(plans.reads, 0);
    expect(plans.attempts, isEmpty);
  });

  testWidgets('Existing profile and plan enter home without generation', (tester) async {
    final plans = PlanStub({'planId': 7});
    await open(tester, {'birthDate': '1995-05-20'}, plans);
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(plans.attempts, isEmpty);
  });

  testWidgets('Missing plan starts the background generation and opens the tour at once', (tester) async {
    final plans = PlanStub(null);
    final generation = FakeGeneration();
    await open(tester, {'birthDate': '1995-05-20'}, plans, generation: generation);
    await tester.pumpAndSettle();
    expect(find.text('Recorrido'), findsOneWidget);
    expect(generation.startCalls, 1, reason: 'requested before the tour, not after it');
    expect(plans.attempts, isEmpty, reason: 'the synchronous endpoint is no longer used');
  });

  testWidgets('Tour already completed and plan still missing: result screen', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'kora_welcome_7': jsonEncode({'tourStatus': 'completed', 'tourStep': 9, 'operationId': operationId})});
    final generation = FakeGeneration(finds: [operation('PROCESSING')]);
    await open(tester, {'birthDate': '1995-05-20'}, PlanStub(null), generation: generation);
    await tester.pumpAndSettle();
    expect(find.text('Resultado'), findsOneWidget);
    expect(generation.foundIds, [operationId], reason: 'resumes the stored operation');
    expect(generation.startCalls, 0, reason: 'no second generation');
  });

  testWidgets('Plan ready but the tour was left half way: the tour is finished first', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'kora_welcome_7': jsonEncode({'tourStatus': 'inProgress', 'tourStep': 4})});
    await open(tester, {'birthDate': '1995-05-20'}, PlanStub({'planId': 9}), generation: FakeGeneration());
    await tester.pumpAndSettle();
    expect(find.text('Recorrido'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
  });

  // Consents (backend V63): only a published version not accepted yet stops the account.
  testWidgets('a newly published terms/privacy version is accepted before entering', (tester) async {
    await open(tester, {'userId': 7}, PlanStub({'planId': 1}), consents: ConsentsStub(consentsJson(terms: 'prueba-terminos-1')));
    expect(find.text('Consentimientos'), findsOneWidget);
  });

  testWidgets('without approved documents (current study state) nothing is asked', (tester) async {
    await open(tester, {'userId': 7}, PlanStub({'planId': 1}), consents: ConsentsStub(consentsJson()));
    expect(find.text('Inicio'), findsOneWidget);
  });

  testWidgets('a failed consents check (older backend, no network) never blocks the account', (tester) async {
    await open(tester, {'userId': 7}, PlanStub({'planId': 1}), consents: ConsentsStub(consentsJson(), fails: true));
    expect(find.text('Inicio'), findsOneWidget);
  });

  // M-01: the backend prepares plans only for active participants.
  group('account the backend will not prepare a plan for', () {
    testWidgets('not a participant, no profile: no onboarding and no generation; explanation, contact and sign out', (tester) async {
      final generation = FakeGeneration();
      final plans = PlanStub(null);
      await open(tester, null, plans, generation: generation, user: () => SignedIn(7, false));
      await tester.pumpAndSettle();
      expect(find.text('Crear perfil'), findsNothing);
      expect(find.textContaining('prepara rutinas solo para las personas que participan'), findsOneWidget);
      expect(find.textContaining('ana7@example.com'), findsOneWidget, reason: 'the account the team must look for');
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Reintentar generación'), findsNothing, reason: 'never a retry that can only fail');
      expect(generation.startCalls, 0);
      expect(plans.attempts, isEmpty);
    });

    testWidgets('not a participant with a saved profile and no plan: no generation is requested', (tester) async {
      final generation = FakeGeneration();
      await open(tester, {'birthDate': '1995-05-20'}, PlanStub(null), generation: generation, user: () => SignedIn(7, false));
      await tester.pumpAndSettle();
      expect(find.text('Recorrido'), findsNothing);
      expect(generation.startCalls, 0);
    });

    testWidgets('withdrawn and no plan this week: says since when and that the data are kept', (tester) async {
      await open(tester, {'birthDate': '1995-05-20'}, PlanStub(null), user: () => SignedIn(7, true, DateTime.utc(2026, 11, 25, 15)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Te retiraste del estudio el 25/11/2026'), findsOneWidget);
      expect(find.textContaining('se conservan'), findsOneWidget);
    });

    testWidgets('withdrawn but the plan of this week exists: still enters to see it', (tester) async {
      await open(tester, {'birthDate': '1995-05-20'}, PlanStub({'planId': 9}), user: () => SignedIn(7, true, DateTime.utc(2026, 11, 25)));
      await tester.pumpAndSettle();
      expect(find.text('Inicio'), findsOneWidget);
    });
  });
}
