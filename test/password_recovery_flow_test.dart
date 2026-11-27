// Mobile-M2 (M-04): recovery flow over the existing screens, against the
// PasswordResetController contract of Backend `generation` 77b9df3, verified
// in recuperacion-backend-local.txt (202 always, 204 on success, 400 for an
// invalid/used/expired code, 429 per IP).
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/core/api/api_constants.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/forgot_password_page.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/login_page.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/reset_password_page.dart';
import 'package:fitsense_mobile/features/authentication/presentation/widgets/reset_password_form.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/fake_backend.dart';

const code43 = 'fSmUjdqpXmpCuPQgzbKlAbCdEfGhIjKlMnOpQrStUvW';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ScriptedBackend> open(WidgetTester tester, {FakeAnswer Function(RequestOptions)? confirm, FakeAnswer Function(RequestOptions)? request, String start = AppRoutes.forgotPassword}) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final backend = ScriptedBackend((o) => switch (o.path) {
      ApiConstants.forgotPassword => request?.call(o) ?? (status: 202, body: {'message': 'Si el correo corresponde a una cuenta, recibiras un codigo para restablecer tu contrasena.'}),
      ApiConstants.resetPassword => confirm?.call(o) ?? (status: 204, body: null),
      _ => (status: 404, body: apiErrorBody(404, 'No encontrado')),
    });
    final router = GoRouter(initialLocation: start, routes: [
      GoRoute(path: AppRoutes.forgotPassword, builder: (_, __) => const ForgotPasswordPage()),
      GoRoute(path: AppRoutes.resetPassword, builder: (_, __) => const ResetPasswordPage()),
      GoRoute(path: AppRoutes.login, builder: (_, state) => LoginPage(initialEmail: state.uri.queryParameters['correo'])),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [dioProvider.overrideWithValue(scriptedDio(backend))],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)));
    await tester.pumpAndSettle();
    return backend;
  }

  Future<void> requestCode(WidgetTester tester, [String email = 'ana@audit.local']) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), email);
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
  }

  Future<void> fillReset(WidgetTester tester, String code) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Código de recuperación'), code);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nueva contraseña'), 'NuevaClave-2026');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar contraseña'), 'NuevaClave-2026');
    await tester.tap(find.text('Actualizar contraseña'));
    await tester.pumpAndSettle();
  }

  testWidgets('valid request: explains expiry, goes to the code screen and remembers the address', (tester) async {
    final backend = await open(tester);
    expect(find.textContaining('Caduca a los 30 minutos y sirve una sola vez'), findsOneWidget);
    await requestCode(tester);
    expect(backend.bodyOf('POST', ApiConstants.forgotPassword), {'email': 'ana@audit.local'});
    expect(find.text('Código de recuperación'), findsOneWidget);
    expect(find.text('Lo pediste para ana@audit.local.'), findsOneWidget);
  });

  testWidgets('an address without account gets exactly the same answer (nothing revealed)', (tester) async {
    await open(tester);
    await requestCode(tester, 'no-existe@audit.local');
    expect(find.text('Código de recuperación'), findsOneWidget);
  });

  testWidgets('«Ya tengo un código» opens the code screen without asking for another one (app closed meanwhile)', (tester) async {
    final backend = await open(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'ana@audit.local');
    await tester.tap(find.byKey(const Key('have-code')));
    await tester.pumpAndSettle();
    expect(find.text('Código de recuperación'), findsOneWidget);
    expect(backend.requests, isEmpty);
  });

  testWidgets('«Pegar código» pastes the copied code without spaces or line breaks', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async =>
        call.method == 'Clipboard.getData' ? {'text': ' ${code43.substring(0, 20)}\n${code43.substring(20)} '} : null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester, start: AppRoutes.resetPassword);
    await tester.tap(find.byKey(const Key('paste-code')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, code43), findsOneWidget);
  });

  testWidgets('correct code: one confirmation with the exact contract, then login with the address prefilled', (tester) async {
    final backend = await open(tester);
    await requestCode(tester);
    await fillReset(tester, '$code43 \n');
    expect(backend.bodyOf('POST', ApiConstants.resetPassword), {'token': code43, 'newPassword': 'NuevaClave-2026'});
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'ana@audit.local'), findsOneWidget);
  });

  for (final reason in ['incorrecto', 'caducado', 'ya utilizado']) {
    testWidgets('code $reason (400): one clear message, fields kept, a new code can be asked', (tester) async {
      await open(tester, confirm: (_) => (status: 400, body: apiErrorBody(400, 'El codigo de recuperacion no es valido o ha caducado.')));
      await requestCode(tester);
      await fillReset(tester, code43);
      expect(find.text('El código no es válido, ya se usó o caducó. Solicita uno nuevo.'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, code43), findsOneWidget);
      await tester.tap(find.byKey(const Key('new-code')));
      await tester.pumpAndSettle();
      expect(find.text('Enviar código'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'ana@audit.local'), findsOneWidget, reason: 'the address is not typed again');
    });
  }

  testWidgets('repeated requests: each one is sent and answered the same way', (tester) async {
    final backend = await open(tester);
    await requestCode(tester);
    await tester.tap(find.byKey(const Key('new-code')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    expect(backend.routes.where((r) => r == 'POST ${ApiConstants.forgotPassword}'), hasLength(2));
  });

  testWidgets('429: says to wait, nothing else happens', (tester) async {
    await open(tester, request: (_) => (status: 429, body: apiErrorBody(429, 'Demasiadas solicitudes')));
    await requestCode(tester);
    expect(find.text('Demasiadas solicitudes de recuperación. Espera un rato antes de volver a intentarlo.'), findsOneWidget);
    expect(find.text('Código de recuperación'), findsNothing);
  });

  testWidgets('lost connection while confirming: connection message, the code stays on screen', (tester) async {
    await open(tester, confirm: (o) => throw connectionLost(o.path));
    await requestCode(tester);
    await fillReset(tester, code43);
    expect(find.textContaining('conectar'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, code43), findsOneWidget);
  });

  test('codes copied with spaces or line breaks are normalised', () {
    expect(normalizeRecoveryCode(' ab\ncd\t e '), 'abcde');
  });
}
