import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'dart:convert';
// Mobile-C3 · incidence I-01: after «Cerrar sesión» no per-account request is
// sent (they could only answer 401: the token is already gone), nothing of the
// previous account stays in memory, and the next account loads its own data.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/authentication/domain/entities/user.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/pain/data/pain_exclusion_repository.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'support/fake_backend.dart';

/// An account that can sign out and another one can sign in, as the real
/// view model does (`state = const AuthState()` after removing the token).
class Session extends AuthViewModel {
  @override
  AuthState build() {
    super.build();
    return _of(7);
  }

  static AuthState _of(int id) => AuthState(isAuthenticated: true, user: User(id: id, firstName: 'Cuenta$id', lastName: 'Prueba',
      email: 'cuenta$id@audit.local', timezone: 'America/Lima', studyParticipant: true));

  void signOut() => state = const AuthState();
  void signIn(int id) => state = _of(id);
}

/// The per-account data of Inicio, Rutinas, Progreso and pain (O20).
final perAccount = <ProviderListenable<AsyncValue<Object?>>>[
  weeklyMetricsProvider, interventionsProvider, dashboardProfileProvider, planHistoryProvider, planLimitationsProvider,
  planAdaptationsProvider, painExclusionsProvider, effectivePainExclusionsProvider, painConfirmationRequestsProvider,
];

/// Waits until every per-account provider has its value.
Future<void> settle(ProviderContainer container) async {
  for (var i = 0; i < 200 && perAccount.any((p) => container.read(p).isLoading); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({'access_token': 'jwt-7'}));

  test('signed in: each per-account request once; signed out: none, and nothing of that account is kept', () async {
    final backend = ScriptedBackend((o) => (status: 200, body: switch (o.path) {
          '/users/me/profile' => {'goalText': 'Datos de la cuenta 7'},
          '/users/me/plan/limitations' => {'limitations': [{'code': 'X', 'message': 'de la cuenta 7'}]},
          '/users/me/pain-exclusions/effective' || '/users/me/pain-exclusions/confirmation-requests' => <Object>[],
          _ => [{'cuenta': 7}],
        }));
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(scriptedDio(backend)),
      authViewModelProvider.overrideWith(Session.new),
    ]);
    addTearDown(container.dispose);
    final subscriptions = [for (final p in perAccount) container.listen(p, (_, _) {})];
    addTearDown(() { for (final s in subscriptions) { s.close(); } });
    await settle(container);
    expect(backend.requests, hasLength(perAccount.length), reason: 'one request each while signed in');

    // «Cerrar sesión»: the token is removed, then the state becomes signed out.
    await const FlutterSecureStorage().deleteAll();
    (container.read(authViewModelProvider.notifier) as Session).signOut();
    await settle(container);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(backend.requests, hasLength(perAccount.length), reason: 'no late request without token (I-01)');
    expect(container.read(dashboardProfileProvider).value, isNull);
    expect(container.read(weeklyMetricsProvider).value, isEmpty);
    expect(container.read(planLimitationsProvider).value, isEmpty, reason: 'nothing of the previous account stays');

    // Another account signs in: its own data is requested again.
    FlutterSecureStorage.setMockInitialValues({'access_token': 'jwt-8'});
    (container.read(authViewModelProvider.notifier) as Session).signIn(8);
    await settle(container);
    expect(backend.requests, hasLength(perAccount.length * 2), reason: 'the next account loads its own data');
    expect(backend.requests.skip(perAccount.length).every((r) => r.headers['Authorization'] == 'Bearer jwt-8'), isTrue,
        reason: 'with the new account token, never the old one');
  });

  test('quick account switch while requests are in flight: only the new account\'s data stays', () async {
    // Slow backend: every answer says which account (token) asked for it.
    final backend = SlowBackend();
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(scriptedDio(ScriptedBackend((o) => (status: 200, body: null)))..httpClientAdapter = backend),
      authViewModelProvider.overrideWith(Session.new),
    ]);
    addTearDown(container.dispose);
    final subscriptions = [for (final p in [weeklyMetricsProvider, interventionsProvider]) container.listen(p, (_, _) {})];
    addTearDown(() { for (final s in subscriptions) { s.close(); } });
    await Future<void>.delayed(const Duration(milliseconds: 5)); // account 7 requests are in flight
    await const FlutterSecureStorage().deleteAll();
    (container.read(authViewModelProvider.notifier) as Session).signOut();
    FlutterSecureStorage.setMockInitialValues({'access_token': 'jwt-8'});
    (container.read(authViewModelProvider.notifier) as Session).signIn(8);
    await settle(container);
    await Future<void>.delayed(const Duration(milliseconds: 150)); // late answers for account 7 arrive
    expect(container.read(weeklyMetricsProvider).value, [{'token': 'Bearer jwt-8'}]);
    expect(container.read(interventionsProvider).value, [{'token': 'Bearer jwt-8'}]);
  });
}

/// Answers after 60 ms with the token that asked, to catch late results of a previous account.
class SlowBackend implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return ResponseBody.fromString(jsonEncode([{'token': options.headers['Authorization']}]), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
