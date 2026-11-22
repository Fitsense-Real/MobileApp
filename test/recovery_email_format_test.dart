import 'package:fitsense_mobile/features/authentication/domain/email_format.dart';
import 'package:fitsense_mobile/features/authentication/domain/repositories/auth_repository.dart';
import 'package:fitsense_mobile/features/authentication/domain/usecases/forgot_password_usecase.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/forgot_password_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/widgets/forgot_password_form.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Requests implements ForgotPasswordUseCase {
  final sent = <String>[];
  @override
  AuthRepository get repository => throw UnimplementedError();
  @override
  Future<void> call(String email) async => sent.add(email);
}

void main() {
  // Found in the E2E against backend 5977d28: the recovery screen rejected
  // addresses that sign-up and login accept.
  test('Sign-up, login and recovery accept the same addresses', () {
    for (final ok in ['ana@correo.com', 'maria+d20@e2e.local', 'luis@kora.travel', 'a.b-c@sub.dominio.pe']) {
      expect(looksLikeEmail(ok), isTrue, reason: ok);
    }
    for (final bad in ['', 'ana', 'ana@', 'ana@correo', 'ana correo@x.com', '@correo.com']) {
      expect(looksLikeEmail(bad), isFalse, reason: bad);
    }
  });

  testWidgets('Recovery sends the request for an address with + and a long domain', (tester) async {
    final requests = _Requests();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold(body: SingleChildScrollView(child: ForgotPasswordForm()))),
      GoRoute(path: '/reset-password', builder: (_, __) => const Text('pantalla del código')),
    ]);
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [forgotPasswordUseCaseProvider.overrideWithValue(requests)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'maria+d20@e2e.local');
    await tester.tap(find.text('Enviar código'));
    await tester.pumpAndSettle();
    expect(find.text('Ingrese un correo válido'), findsNothing);
    expect(requests.sent, ['maria+d20@e2e.local']);
  });
}
