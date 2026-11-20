import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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

/// Double of `DELETE /api/v1/users/me` with the contract of Fitsense-Real/Backend
/// `generation` 5977d28 (checked over HTTP against the real backend): body
/// `{password, confirm: true}`; 200 DELETED, 202 PENDING, 400, 403, 429 +
/// Retry-After, 401, 404, 503.
class AccountBackend implements HttpClientAdapter {
  AccountBackend({this.deleteStatus = 200, this.offline = false, this.alreadyRequested = false, this.retryAfterVisible = true, this.timeouts = 0});
  int deleteStatus;
  /// The first N DELETEs get no answer (receive timeout) although they left the phone.
  int timeouts;
  bool offline, alreadyRequested;
  /// false: like a browser, where the backend does not expose Retry-After (CORS).
  bool retryAfterVisible;
  final calls = <String>[];
  final bodies = <Object?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? stream, Future<void>? cancel) async {
    calls.add('${o.method} ${o.path}');
    bodies.add(o.data);
    if (offline && o.method == 'DELETE') {
      throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    }
    if (timeouts > 0 && o.method == 'DELETE') {
      timeouts--;
      throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout);
    }
    var headers = <String, List<String>>{Headers.contentTypeHeader: [Headers.jsonContentType]};
    final (int status, Object? body) = switch ('${o.method} ${o.path}') {
      'DELETE /users/me' => _delete(o.data, (h) => headers = {...headers, ...h}),
      'POST /users/me/withdraw' => (200, {'userId': 7, 'email': 'ana7@example.com', 'firstName': 'Ana', 'studyParticipant': true, 'withdrawnAt': '2026-11-19T10:00:00Z'}),
      _ => (404, {'message': 'no existe'}),
    };
    return ResponseBody.fromString(body == null ? '' : jsonEncode(body), status, headers: headers);
  }

  (int, Object?) _delete(Object? data, void Function(Map<String, List<String>>) addHeaders) {
    final body = data is Map ? data : const {};
    if (body['confirm'] != true) return (400, {'status': 400, 'message': 'Falta la confirmacion: envia confirm=true para eliminar la cuenta de forma irreversible.', 'details': ['CONFIRMACION_REQUERIDA']});
    if (body['password'] != 'Kora12345') return (403, {'status': 403, 'message': 'La contrasena no es correcta. La cuenta no se ha eliminado.', 'details': ['REAUTENTICACION_FALLIDA']});
    switch (deleteStatus) {
      case 200:
        return (200, {'status': 'DELETED', 'deletionId': 'b29c96e1-1449-44a0-8806-f1451b2b79a1', 'requestedAt': '2026-11-20T03:19:02Z', 'completedAt': '2026-11-20T03:19:02Z'});
      case 202:
        return (202, {'status': 'PENDING', 'deletionId': 'b29c96e1-1449-44a0-8806-f1451b2b79a1', 'requestedAt': '2026-11-20T03:19:02Z', if (alreadyRequested) 'alreadyRequested': true});
      case 429:
        if (retryAfterVisible) addHeaders({'retry-after': ['899']});
        return (429, {'status': 429, 'message': 'Demasiados intentos con una contrasena incorrecta. Espera antes de volver a intentarlo.', 'details': ['DEMASIADOS_INTENTOS']});
      default:
        return (deleteStatus, {'status': deleteStatus, 'message': 'Error $deleteStatus'});
    }
  }

  @override
  void close({bool force = false}) {}
}

class BrokenLocalData extends LocalAccountData {
  const BrokenLocalData();
  @override
  Future<void> clear(int userId) async => throw Exception('almacenamiento no disponible');
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
  List<Override> overrides = const [],
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
    ...overrides,
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

  testWidgets('200 DELETED: one DELETE with {password, confirm: true}, signs out and clears only this account', (tester) async {
    final r = await pumpDeletion(tester);
    await fillAndConfirm(tester);
    expect(r.backend.calls, ['DELETE ${ApiConstants.deleteAccount}'], reason: 'the password goes once, only in the DELETE: no separate login');
    expect(r.backend.bodies.single, {'password': 'Kora12345', 'confirm': true});
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

  testWidgets('202 PENDING: "Solicitud recibida", account deactivated, never "deleted"; signs out and clears', (tester) async {
    final r = await pumpDeletion(tester, backend: AccountBackend(deleteStatus: 202));
    await fillAndConfirm(tester);
    expect(find.text('Solicitud recibida'), findsOneWidget);
    expect(find.textContaining('quedó desactivada'), findsOneWidget);
    expect(find.textContaining('todavía no está terminada'), findsOneWidget);
    expect(find.text('Tu cuenta fue eliminada'), findsNothing);
    expect(r.container.read(authViewModelProvider).user, isNull, reason: 'the backend revoked every token');
    expect((await stored()).containsKey('access_token'), isFalse);
  });

  testWidgets('202 with alreadyRequested: says it was requested before', (tester) async {
    await pumpDeletion(tester, backend: AccountBackend(deleteStatus: 202, alreadyRequested: true));
    await fillAndConfirm(tester);
    expect(find.textContaining('Ya habías solicitado'), findsOneWidget);
  });

  testWidgets('404 (account no longer exists): signs out and clears, without claiming the app deleted it', (tester) async {
    final r = await pumpDeletion(tester, backend: AccountBackend(deleteStatus: 404));
    await fillAndConfirm(tester);
    expect(find.text('Tu cuenta ya no existe'), findsOneWidget);
    expect(r.container.read(authViewModelProvider).user, isNull);
  });

  testWidgets('403 wrong password: understandable message, nothing cleared, the password can be corrected', (tester) async {
    final r = await pumpDeletion(tester);
    await fillAndConfirm(tester, password: 'Equivocada1');
    expect(find.textContaining('La contraseña no es correcta'), findsOneWidget);
    expect(r.container.read(authViewModelProvider).user, isNotNull);
    expect(await stored(), userKeys);
    await tester.enterText(find.byType(TextField), 'Kora12345');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar mi cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('Tu cuenta fue eliminada'), findsOneWidget, reason: 'corrected password works');
    expect(r.backend.calls.length, 2);
  });

  testWidgets('429: explains the temporary block with the Retry-After time and does not send again', (tester) async {
    final r = await pumpDeletion(tester, backend: AccountBackend(deleteStatus: 429));
    await fillAndConfirm(tester);
    expect(find.textContaining('Demasiados intentos'), findsOneWidget);
    expect(find.textContaining('15 minutos'), findsOneWidget, reason: 'Retry-After: 899 s');
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Eliminar mi cuenta')).onPressed, isNull,
        reason: 'button disabled during the block');
    await tester.runAsync(() => r.container.read(accountDeletionProvider.notifier).delete(password: 'Kora12345'));
    expect(r.backend.calls.where((c) => c.startsWith('DELETE')).length, 1, reason: 'no automatic or repeated request');
    expect(r.container.read(authViewModelProvider).user, isNotNull);
  });

  // Found in the web E2E against backend 5977d28: without Access-Control-Expose-Headers
  // the browser hides Retry-After, and the button allowed another attempt right away.
  testWidgets('429 without a readable Retry-After still pauses the button', (tester) async {
    final r = await pumpDeletion(tester, backend: AccountBackend(deleteStatus: 429, retryAfterVisible: false));
    await fillAndConfirm(tester);
    expect(find.textContaining('espera unos minutos'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Eliminar mi cuenta')).onPressed, isNull);
    await tester.runAsync(() => r.container.read(accountDeletionProvider.notifier).delete(password: 'Kora12345'));
    expect(r.backend.calls.where((c) => c.startsWith('DELETE')).length, 1);
  });

  // Found in the independent review: a request that got no answer may have been
  // processed (the backend deactivates the account at once).
  testWidgets('no answer after sending: never "nothing was deleted"; a later 401 clears this account', (tester) async {
    final r = await pumpDeletion(tester, backend: AccountBackend(timeouts: 1, deleteStatus: 401));
    await fillAndConfirm(tester);
    expect(find.textContaining('no sabemos si la eliminación se registró'), findsOneWidget);
    expect(find.textContaining('No se eliminó nada'), findsNothing);
    expect(r.container.read(authViewModelProvider).user, isNotNull, reason: 'nothing assumed yet');
    expect(await stored(), userKeys);
    await tester.runAsync(() => r.container.read(accountDeletionProvider.notifier).delete(password: 'Kora12345'));
    await tester.pumpAndSettle();
    expect(r.backend.calls.where((c) => c.startsWith('DELETE')).length, 2);
    final state = r.container.read(accountDeletionProvider);
    expect(state.status, DeletionStatus.gone);
    expect(state.inferred, isTrue);
    expect(find.text('Tu cuenta probablemente ya se eliminó'), findsOneWidget);
    final left = await stored();
    for (final key in LocalAccountData.keysOf(7)) {
      expect(left.containsKey(key), isFalse, reason: key);
    }
    expect(left['kora_welcome_8'], '{"tourStep":3}', reason: 'other accounts are kept');
  });

  testWidgets('a plain 401 (no earlier unanswered request) keeps the local data', (tester) async {
    final r = await pumpDeletion(tester, backend: AccountBackend(deleteStatus: 401));
    await fillAndConfirm(tester);
    expect(find.textContaining('Tu sesión ya no es válida'), findsOneWidget);
    expect(r.container.read(accountDeletionProvider).status, DeletionStatus.failed);
    expect((await stored())['kora_favorites_7'], '[]');
  });

  testWidgets('a 403 that is not REAUTENTICACION_FALLIDA is not called a wrong password', (tester) async {
    await pumpDeletion(tester, backend: AccountBackend(deleteStatus: 403));
    await fillAndConfirm(tester);
    expect(find.textContaining('La contraseña no es correcta'), findsNothing);
    expect(find.textContaining('El servidor rechazó la solicitud'), findsOneWidget);
  });

  testWidgets('200 with a local cleanup failure still says the account was deleted', (tester) async {
    final r = await pumpDeletion(tester, overrides: [localAccountDataProvider.overrideWithValue(const BrokenLocalData())]);
    await fillAndConfirm(tester);
    expect(find.text('Tu cuenta fue eliminada'), findsOneWidget);
    expect(find.textContaining('No se eliminó nada'), findsNothing);
    expect(r.container.read(authViewModelProvider).user, isNull, reason: 'signed out anyway');
  });

  for (final (name, backend, message) in [
    ('503 (not registered)', AccountBackend(deleteStatus: 503), 'El servidor no pudo registrar la solicitud'),
    ('500', AccountBackend(deleteStatus: 500), 'El servidor no pudo registrar la solicitud'),
    ('401 (revoked token)', AccountBackend(deleteStatus: 401), 'Tu sesión ya no es válida'),
    ('405 (old backend without the endpoint)', AccountBackend(deleteStatus: 405), 'todavía no está disponible'),
    ('without connection', AccountBackend(offline: true), 'No hay conexión'),
    ('unexpected 200 without DELETED', AccountBackend(deleteStatus: 299), 'No se eliminó nada'),
  ]) {
    testWidgets('$name: nothing is deleted locally, the session stays', (tester) async {
      final r = await pumpDeletion(tester, backend: backend);
      await fillAndConfirm(tester);
      expect(find.textContaining(message), findsOneWidget);
      expect(find.textContaining('No se eliminó nada'), findsOneWidget);
      expect(find.text('Tu cuenta fue eliminada'), findsNothing);
      expect(find.text('Solicitud recibida'), findsNothing);
      expect(r.container.read(authViewModelProvider).user, isNotNull, reason: 'still signed in');
      expect(r.scheduler.cancels, 0);
      final left = await stored();
      for (final key in LocalAccountData.keysOf(7)) {
        expect(left.containsKey(key), isTrue, reason: key);
      }
    });
  }

  testWidgets('repeated and simultaneous requests (double tap) send a single DELETE', (tester) async {
    final r = await pumpDeletion(tester);
    final notifier = r.container.read(accountDeletionProvider.notifier);
    await tester.runAsync(() => Future.wait([for (var i = 0; i < 3; i++) notifier.delete(password: 'Kora12345')]));
    expect(r.backend.calls.where((c) => c == 'DELETE ${ApiConstants.deleteAccount}').length, 1);
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
