import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

  Future<void> open(WidgetTester tester, Map<String, dynamic>? profile, PlanStub plans, {FakeGeneration? generation}) async {
    final router = GoRouter(initialLocation: '/account-setup', routes: [
      GoRoute(path: '/account-setup', builder: (_, __) => const AccountSetupPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const Scaffold(body: Text('Crear perfil'))),
      GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('Inicio'))),
      GoRoute(path: welcomeTourRoute, builder: (_, __) => const Scaffold(body: Text('Recorrido'))),
      GoRoute(path: welcomeResultRoute, builder: (_, __) => const Scaffold(body: Text('Resultado'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      authViewModelProvider.overrideWith(SignedIn.new),
      profileRepositoryProvider.overrideWithValue(ProfileStub(profile)),
      planRepositoryProvider.overrideWithValue(plans),
      planGenerationRepositoryProvider.overrideWithValue(generation ?? FakeGeneration()),
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
}
