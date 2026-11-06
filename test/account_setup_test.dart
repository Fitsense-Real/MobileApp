import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/plans/presentation/account_setup_page.dart';

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
  Future<void> open(WidgetTester tester, Map<String, dynamic>? profile, PlanStub plans) async {
    final router = GoRouter(initialLocation: '/account-setup', routes: [
      GoRoute(path: '/account-setup', builder: (_, __) => const AccountSetupPage()),
      GoRoute(path: '/onboarding', builder: (_, __) => const Scaffold(body: Text('Crear perfil'))),
      GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('Inicio'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      profileRepositoryProvider.overrideWithValue(ProfileStub(profile)),
      planRepositoryProvider.overrideWithValue(plans),
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

  testWidgets('Missing plan waits for generation, handles errors and reconciles retry', (tester) async {
    final plans = PlanStub(null);
    await open(tester, {'birthDate': '1995-05-20'}, plans);
    expect(find.text('Sincronizando...'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
    plans.attempts.single.completeError(Exception('Connection lost'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
    plans.plan = {'planId': 9};
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
    expect(plans.attempts.length, 1);
  });

  testWidgets('Generation success opens home only after response', (tester) async {
    final plans = PlanStub(null);
    await open(tester, {}, plans);
    expect(find.text('Inicio'), findsNothing);
    plans.attempts.single.complete({'planId': 10});
    await tester.pumpAndSettle();
    expect(find.text('Inicio'), findsOneWidget);
  });
}
