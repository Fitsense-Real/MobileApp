import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/login_page.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/register_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'package:fitsense_mobile/features/consents/data/consents_repository.dart';
import 'package:fitsense_mobile/features/consents/domain/legal_documents.dart';

/// Google Play: no disabled buttons for features that do not exist.
/// Social sign-in is not implemented, so it must not appear at all.
Future<void> pumpAuth(WidgetTester tester, String location, {Size size = const Size(390, 844), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: location, routes: [
    GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
    GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterPage()),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [publishedDocumentsProvider.overrideWith((ref) async => _published)],
    child: MediaQuery(
      data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Synthetic published documents (sign-up open), for layout tests only.
const _published = PublishedDocuments(documents: [
  LegalDocument(type: ConsentType.studyParticipation, title: 'Consentimiento informado', url: 'https://docs.test/consentimiento', version: 'C-PRUEBA-1'),
  LegalDocument(type: ConsentType.termsOfService, title: 'Condiciones de uso', url: 'https://docs.test/terminos', version: 'T-PRUEBA-1'),
  LegalDocument(type: ConsentType.privacyPolicy, title: 'Política de privacidad', url: 'https://docs.test/privacidad', version: 'P-PRUEBA-1'),
]);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final (name, location) in [('login', AppRoutes.login), ('registro', AppRoutes.register)]) {
    testWidgets('$name: no social sign-in, email and password sign-in intact', (tester) async {
      await pumpAuth(tester, location);
      for (final gone in ['GOOGLE', 'APPLE', 'O CONTINÚA CON', 'próximamente']) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      expect(find.byWidgetPredicate((w) => w is OutlinedButton && w.onPressed == null), findsNothing,
          reason: 'no disabled buttons for missing features');
      expect(find.text(location == AppRoutes.login ? 'INICIAR SESIÓN' : 'CREAR CUENTA'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name: fits 320 px with large text', (tester) async {
      await pumpAuth(tester, location, size: const Size(320, 640), textScale: 1.5);
      expect(tester.takeException(), isNull);
    });
  }
}
