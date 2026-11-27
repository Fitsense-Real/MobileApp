// Mobile-M5: profile review before the first plan (M-38) and leaving the
// setup from its first step (M-35).
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/onboarding/presentation/onboarding_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/welcome_fakes.dart';

class _Profiles extends ProfileRepository {
  _Profiles() : super(Dio());
  @override
  Future<Map<String, dynamic>?> fetch() async => null;
  @override
  Future<List<Equipment>> equipment() async => [const Equipment('body weight', 'Peso corporal', false), const Equipment('band', 'Banda elástica', false)];
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 7200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/onboarding', routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Pantalla de login'))),
      GoRoute(path: '/dashboard', builder: (_, __) => const Scaffold(body: Text('Inicio vacío'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [authViewModelProvider.overrideWith(SignedIn.new), profileRepositoryProvider.overrideWithValue(_Profiles())],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
  }

  testWidgets('M-38: the last step shows every value that will be used, each with «Editar»', (tester) async {
    await open(tester);
    tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text = 'Sentirme con más energía';
    await next(tester);
    tester.widget<TextFormField>(find.descendant(of: find.byKey(const ValueKey('Estatura (cm)')), matching: find.byType(TextFormField))).controller!.text = '164';
    tester.widget<TextFormField>(find.descendant(of: find.byKey(const ValueKey('Peso actual (kg)')), matching: find.byType(TextFormField))).controller!.text = '63';
    tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('birthday')), matching: find.byType(EditableText))).controller.text = '1990-05-10';
    await next(tester);
    await next(tester);
    await next(tester);
    await tester.tap(find.text('Saltos y alto impacto'));
    await tester.pumpAndSettle();
    final review = find.byKey(const Key('profile-review'));
    expect(review, findsOneWidget);
    expect(find.descendant(of: review, matching: find.textContaining('Mejorar condición · Sentirme con más energía')), findsOneWidget);
    expect(find.descendant(of: review, matching: find.textContaining('164 cm · 63 kg')), findsOneWidget);
    expect(find.descendant(of: review, matching: find.textContaining('Lun, Mié, Vie · 45 min por sesión')), findsOneWidget);
    expect(find.descendant(of: review, matching: find.textContaining('Casa · Peso corporal')), findsOneWidget);
    expect(find.descendant(of: review, matching: find.textContaining('saltos y alto impacto')), findsOneWidget);
    expect(find.descendant(of: review, matching: find.text('Editar')), findsNWidgets(5));
    await tester.tap(find.descendant(of: review, matching: find.text('Editar')).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Paso 3 de 5'), findsOneWidget, reason: 'jumps to the step to correct it');
  });

  testWidgets('M-35: «Volver» on the first step offers to sign out instead of an empty Inicio', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir de la configuración?'), findsOneWidget);
    await tester.tap(find.text('Seguir configurando'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 5'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('Pantalla de login'), findsOneWidget);
    expect(find.text('Inicio vacío'), findsNothing);
  });
}
