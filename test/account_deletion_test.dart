import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/core/api/api_constants.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/account/data/local_account_data.dart';
import 'package:fitsense_mobile/features/account/presentation/account_deletion_controller.dart';
import 'package:fitsense_mobile/features/account/presentation/account_deletion_page.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:fitsense_mobile/features/reminders/data/reminder_scheduler.dart';
import 'package:fitsense_mobile/features/reminders/presentation/reminders_controller.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/welcome_fakes.dart';

/// Backend double for the account endpoints. `DELETE /users/me` is still
/// being prepared in Fitsense-Real/Backend: these are simulated contracts.
class AccountBackend implements HttpClientAdapter {
  AccountBackend({this.loginStatus = 200, this.loginUserId = 7, this.deleteStatus = 204, this.offline = false});
  int loginStatus, loginUserId, deleteStatus;
  bool offline;
  final calls = <String>[];
  final authHeaders = <String?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? stream, Future<void>? cancel) async {
    calls.add('${o.method} ${o.path}');
    authHeaders.add(o.headers['Authorization'] as String?);
    if (offline && o.method == 'DELETE') {
      throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    }
    final (int status, Object? body) = switch ('${o.method} ${o.path}') {
      'POST /auth/login' => (loginStatus, loginStatus == 200 ? {'userId': loginUserId, 'email': 'ana7@example.com', 'token': 'jwt-fresco'} : {'status': loginStatus, 'message': 'Credenciales inválidas'}),
      'DELETE /users/me' => (deleteStatus, deleteStatus >= 400 ? {'status': deleteStatus, 'message': 'Error $deleteStatus'} : null),
      'POST /users/me/withdraw' => (200, {'userId': 7, 'email': 'ana7@example.com', 'firstName': 'Ana', 'studyParticipant': true, 'withdrawnAt': '2026-11-19T10:00:00Z'}),
      _ => (404, {'message': 'no existe'}),
    };
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class FakeScheduler implements ReminderScheduler {
  int cancels = 0;
  @override
  Future<void> cancelAll() async => cancels++;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class SignedOut extends AuthViewModel {
  @override
  AuthState build() {
    super.build();
    return const AuthState();
  }
}

Future<({AccountBackend backend, FakeScheduler scheduler, ProviderContainer container})> pumpDeletion(
  WidgetTester tester, {
  AccountBackend? backend,
  bool signedIn = true,
}) async {
  tester.view.physicalSize = const Size(390, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = backend ?? AccountBackend();
  final scheduler = FakeScheduler();
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'))..httpClientAdapter = api;
  final router = GoRouter(initialLocation: AppRoutes.deleteAccount, routes: [
    GoRoute(path: AppRoutes.deleteAccount, builder: (_, __) => const AccountDeletionPage()),
    GoRoute(path: AppRoutes.login, builder: (_, __) => const Scaffold(body: Text('Pantalla de login'))),
    GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const Scaffold(body: Text('Inicio'))),
  ]);
  addTearDown(router.dispose);
  final container = ProviderContainer(overrides: [
    dioProvider.overrideWithValue(dio),
    authViewModelProvider.overrideWith(signedIn ? SignedIn.new : SignedOut.new),
    reminderSchedulerProvider.overrideWithValue(scheduler),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)));
  await tester.pumpAndSettle();
  return (backend: api, scheduler: scheduler, container: container);
}

Future<void> fillAndConfirm(WidgetTester tester, {bool confirm = true, String password = 'Kora12345'}) async {
  await tester.enterText(find.byType(TextField), password);
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Eliminar mi cuenta'));
  await tester.pumpAndSettle();
  expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
  await tester.tap(find.text(confirm ? 'Eliminar' : 'Cancelar'));
  await tester.pumpAndSettle();
}

const userKeys = {'kora_welcome_7': '{}', 'kora_reminders_7': '{}', 'kora_favorites_7': '[]', 'access_token': 'jwt-viejo', 'kora_welcome_8': '{"tourStep":3}'};

Future<Map<String, String>> stored() => const FlutterSecureStorage().readAll();

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues(Map.of(userKeys)));

  testWidgets('authenticated: explains it, links the study terms, and needs password and acknowledgement', (tester) async {
    await pumpDeletion(tester);
    expect(find.text('Eliminar mi cuenta'), findsWidgets);
    expect(find.textContaining('Retirarte del estudio es distinto'), findsOneWidget);
    expect(find.textContaining('consentimiento informado'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Eliminar mi cuenta'));
    expect(button.onPressed, isNull, reason: 'disabled until password and acknowledgement');
    await tester.enterText(find.byType(TextField), 'Kora12345');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Eliminar mi cuenta')).onPressed, isNull);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Eliminar mi cuenta')).onPressed, isNotNull);
  });

  testWidgets('signed out: asks to sign in and sends nothing', (tester) async {
    final r = await pumpDeletion(tester, signedIn: false);
    expect(find.textContaining('Inicia sesión para eliminar tu cuenta'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(r.backend.calls, isEmpty);
  });

  testWidgets('cancelled confirmation: no request, nothing cleared', (tester) async {
    final r = await pumpDeletion(tester);
    await fillAndConfirm(tester, confirm: false);
    expect(r.backend.calls, isEmpty);
    expect(await stored(), userKeys);
  });

  testWidgets('204: re-authenticates, deletes with the fresh token, signs out and clears only this account', (tester) async {
    final r = await pumpDeletion(tester);
    await fillAndConfirm(tester);
    expect(r.backend.calls, ['POST ${ApiConstants.login}', 'DELETE ${ApiConstants.deleteAccount}']);
    expect(find.text('Tu cuenta fue eliminada'), findsOneWidget);
    expect(r.container.read(authViewModelProvider).user, isNull, reason: 'signed out');
    expect(r.scheduler.cancels, greaterThan(0), reason: 'no reminders after deleting the account');
    final left = await stored();
    for (final key in [...LocalAccountData.keysOf(7), 'access_token']) {
      expect(left.containsKey(key), isFalse, reason: key);
    }
    expect(left['kora_welcome_8'], '{"tourStep":3}', reason: 'another account on the same phone is kept');
    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla de login'), findsOneWidget);
  });

  testWidgets('202: says the request was received and pending, never that the account was deleted', (tester) async {
    final r = await pumpDeletion(tester, backend: AccountBackend(deleteStatus: 202));
    await fillAndConfirm(tester);
    expect(find.text('Solicitud recibida'), findsOneWidget);
    expect(find.textContaining('Todavía no está completada'), findsOneWidget);
    expect(find.text('Tu cuenta fue eliminada'), findsNothing);
    expect(r.container.read(authViewModelProvider).user, isNull);
    expect((await stored()).containsKey('access_token'), isFalse);
  });

  for (final (name, backend, message) in [
    ('500', AccountBackend(deleteStatus: 500), 'El servidor no pudo procesar la solicitud'),
    ('405 (the current backend: no DELETE /users/me yet)', AccountBackend(deleteStatus: 405), 'todavía no está disponible'),
    ('404', AccountBackend(deleteStatus: 404), 'todavía no está disponible'),
    ('without connection', AccountBackend(offline: true), 'No hay conexión'),
    ('wrong password', AccountBackend(loginStatus: 401), 'contraseña no es correcta'),
    ('password of another account', AccountBackend(loginUserId: 99), 'otra cuenta'),
  ]) {
    testWidgets('$name: nothing is deleted, the session and local data stay', (tester) async {
      final r = await pumpDeletion(tester, backend: backend);
      await fillAndConfirm(tester);
      expect(find.textContaining(message), findsOneWidget);
      expect(find.textContaining('No se eliminó nada'), backend.loginUserId == 99 ? findsNothing : findsOneWidget);
      expect(find.text('Tu cuenta fue eliminada'), findsNothing);
      expect(find.text('Solicitud recibida'), findsNothing);
      expect(r.container.read(authViewModelProvider).user, isNotNull, reason: 'still signed in');
      expect(r.scheduler.cancels, 0);
      final left = await stored();
      for (final key in LocalAccountData.keysOf(7)) {
        expect(left.containsKey(key), isTrue, reason: key);
      }
      if (backend.loginStatus == 401 || backend.loginUserId != 7) {
        expect(r.backend.calls.where((c) => c.startsWith('DELETE')), isEmpty, reason: 'no DELETE without re-authentication');
      }
    });
  }

  testWidgets('repeated requests (double tap) send a single deletion', (tester) async {
    final r = await pumpDeletion(tester);
    final notifier = r.container.read(accountDeletionProvider.notifier);
    await tester.runAsync(() => Future.wait([for (var i = 0; i < 3; i++) notifier.delete(password: 'Kora12345')]));
    expect(r.backend.calls.where((c) => c == 'DELETE ${ApiConstants.deleteAccount}').length, 1);
    expect(r.backend.calls.where((c) => c == 'POST ${ApiConstants.login}').length, 1);
  });

  test('withdrawing from the study is a different request that deletes nothing', () async {
    FlutterSecureStorage.setMockInitialValues(Map.of(userKeys));
    final api = AccountBackend();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'))..httpClientAdapter = api;
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      authViewModelProvider.overrideWith(SignedIn.new),
      reminderSchedulerProvider.overrideWithValue(FakeScheduler()),
    ]);
    addTearDown(container.dispose);
    await container.read(authViewModelProvider.notifier).withdrawFromStudy();
    expect(api.calls, ['POST ${ApiConstants.withdraw}']);
    expect(container.read(authViewModelProvider).user, isNotNull, reason: 'the account is kept');
    expect(await stored(), userKeys, reason: 'nothing is removed from the phone');
  });
}
