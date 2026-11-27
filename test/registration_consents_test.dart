// Mobile-M1: sign-up, study participation (M-01), documents (M-02/M-03/M-27),
// time zone (M-18) and signing in after creating the account (M-34).
// The fake backend answers exactly like Backend `generation` 77b9df3
// (contratos-backend-local.txt of the pre-production audit).
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/register_page.dart';
import 'package:fitsense_mobile/features/authentication/presentation/widgets/kora_auth_form.dart';
import 'package:fitsense_mobile/features/consents/data/consents_repository.dart';
import 'package:fitsense_mobile/features/consents/data/document_text_repository.dart';
import 'package:fitsense_mobile/features/consents/domain/legal_documents.dart';
import 'package:fitsense_mobile/features/plans/domain/plan_eligibility.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/fake_backend.dart';

/// Synthetic documents for the tests only: never shown to participants.
const syntheticTerms = 'Condiciones sintéticas de prueba. No es un documento aprobado.';
const syntheticPrivacy = 'Política sintética de prueba. No es un documento aprobado.';
const syntheticConsent = 'Consentimiento sintético de prueba. No es un documento aprobado.';

class FakeDocuments extends DocumentTextRepository {
  FakeDocuments() : super(Dio());
  final fetched = <String>[];
  @override
  Future<String> fetch(String url) async {
    fetched.add(url);
    return switch (url) {
      'https://docs.test/terminos' => syntheticTerms,
      'https://docs.test/privacidad' => syntheticPrivacy,
      _ => syntheticConsent,
    };
  }
}

const withDocuments = SignUpDocuments(
  terms: LegalDocument(type: ConsentType.termsOfService, title: 'Condiciones de uso', url: 'https://docs.test/terminos', version: 'T-PRUEBA-1'),
  privacy: LegalDocument(type: ConsentType.privacyPolicy, title: 'Política de privacidad', url: 'https://docs.test/privacidad', version: 'P-PRUEBA-1'),
);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ScriptedBackend> open(WidgetTester tester, {
    FakeAnswer Function(RequestOptions)? register,
    SignUpDocuments documents = const SignUpDocuments(),
    bool plansForNonParticipants = false,
    FakeDocuments? texts,
  }) async {
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final backend = ScriptedBackend((o) => switch ('${o.method} ${o.path}') {
      'POST /auth/register' => register?.call(o) ?? (status: 201, body: userResource(participant: (o.data as Map)['acceptsStudyParticipation'] == true)),
      'POST /auth/login' => (status: 200, body: {'userId': 41, 'email': 'ana@audit.local', 'fullName': 'Ana Prueba', 'token': 'jwt-nuevo'}),
      'GET /users/me' => (status: 200, body: userResource()),
      _ => (status: 404, body: apiErrorBody(404, 'No encontrado')),
    });
    final router = GoRouter(initialLocation: AppRoutes.register, routes: [
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterPage()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const Scaffold(body: Text('Pantalla de login'))),
      GoRoute(path: AppRoutes.accountSetup, builder: (_, __) => const Scaffold(body: Text('Preparando cuenta'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      dioProvider.overrideWithValue(scriptedDio(backend)),
      signUpDocumentsProvider.overrideWithValue(documents),
      plansForNonParticipantsProvider.overrideWithValue(plansForNonParticipants),
      documentTextRepositoryProvider.overrideWithValue(texts ?? FakeDocuments()),
    ], child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)));
    await tester.pumpAndSettle();
    return backend;
  }

  Future<void> fillAccount(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Nombres'), 'Ana');
    await tester.enterText(find.widgetWithText(TextFormField, 'Apellidos'), 'Prueba');
    await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'ana@audit.local');
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'clave-segura-1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar contraseña'), 'clave-segura-1');
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('CREAR CUENTA'));
      await tester.pumpAndSettle();
    await tester.tap(find.text('CREAR CUENTA'));
    await tester.pumpAndSettle();
  }

  Future<void> readDocument(WidgetTester tester, String buttonText) async {
    await tester.ensureVisible(find.text(buttonText).first);
      await tester.pumpAndSettle();
    await tester.tap(find.text(buttonText).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('He leído el documento'));
    await tester.pumpAndSettle();
  }

  group('M-01 participation (current backend: plans only for participants)', () {
    testWidgets('the box is not presented as optional and says what happens without it', (tester) async {
      await open(tester);
      expect(find.textContaining('Opcional'), findsNothing);
      expect(find.text('Sin participar podrás crear la cuenta, pero no recibirás una rutina.'), findsOneWidget);
      expect(find.textContaining('prepara rutinas solo para quienes participan'), findsOneWidget);
    });

    testWidgets('unticked: asks before creating the account; «Revisar participación» sends nothing', (tester) async {
      final backend = await open(tester);
      await fillAccount(tester);
      await submit(tester);
      expect(find.text('¿Crear la cuenta sin participar?'), findsOneWidget);
      await tester.tap(find.text('Revisar participación'));
      await tester.pumpAndSettle();
      expect(backend.routes, isNot(contains('POST /auth/register')));
    });

    testWidgets('a person who declines can still create the account knowingly (no participation sent)', (tester) async {
      final backend = await open(tester);
      await fillAccount(tester);
      await submit(tester);
      await tester.tap(find.text('Crear sin participar'));
      await tester.pumpAndSettle();
      expect(backend.bodyOf('POST', '/auth/register')['acceptsStudyParticipation'], isFalse);
    });

    testWidgets('ticked: account created as participant, then signed in automatically (M-34)', (tester) async {
      final backend = await open(tester);
      await fillAccount(tester);
      await tester.ensureVisible(find.byKey(const Key('accept-study')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accept-study')));
      await submit(tester);
      final body = backend.bodyOf('POST', '/auth/register');
      expect(body['acceptsStudyParticipation'], isTrue);
      expect(body['timezone'], 'America/Lima');
      expect(body.containsKey('acceptedTermsVersion'), isFalse, reason: 'no approved document in this build: nothing is sent');
      expect(body.containsKey('acceptedPrivacyVersion'), isFalse);
      expect(backend.routes, containsAllInOrder(['POST /auth/register', 'POST /auth/login', 'GET /users/me']));
      expect(find.text('Preparando cuenta'), findsOneWidget);
    });

    testWidgets('with plans for non-participants (option B) participation is optional and nothing is asked', (tester) async {
      final backend = await open(tester, plansForNonParticipants: true);
      expect(find.text('Opcional. Déjalo desmarcado si no deseas participar.'), findsOneWidget);
      await fillAccount(tester);
      await submit(tester);
      expect(find.text('¿Crear la cuenta sin participar?'), findsNothing);
      expect(backend.bodyOf('POST', '/auth/register')['acceptsStudyParticipation'], isFalse);
    });
  });

  group('M-18 time zone', () {
    testWidgets('a closed list of IANA zones; the choice is what is sent', (tester) async {
      final backend = await open(tester);
      await fillAccount(tester);
      await tester.ensureVisible(find.byKey(const Key('timezone')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timezone')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Colombia (Bogotá)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accept-study')));
      await submit(tester);
      expect(backend.bodyOf('POST', '/auth/register')['timezone'], 'America/Bogota');
      expect(find.byType(TextFormField).evaluate().where((e) => (e.widget as TextFormField).controller?.text == 'America/Lima'), isEmpty,
          reason: 'there is no free text field for the zone any more');
    });
  });

  group('M-02/M-03 documents (synthetic, tests only)', () {
    testWidgets('no approved documents: the documents block does not exist', (tester) async {
      await open(tester);
      expect(find.text('Documentos'), findsNothing);
      expect(find.byKey(const Key('accept-TERMS_OF_SERVICE')), findsNothing);
    });

    testWidgets('each document must be read completely before it can be accepted; versions are sent', (tester) async {
      final texts = FakeDocuments();
      final backend = await open(tester, documents: withDocuments, texts: texts);
      await fillAccount(tester);
      final terms = find.byKey(const Key('accept-TERMS_OF_SERVICE'));
      expect(tester.widget<CheckboxListTile>(terms).onChanged, isNull, reason: 'not read yet');
      await tester.ensureVisible(find.byKey(const Key('accept-study')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accept-study')));
      await submit(tester);
      expect(find.text('Lee y acepta cada documento para crear la cuenta.', skipOffstage: false), findsOneWidget);
      expect(backend.routes, isNot(contains('POST /auth/register')));

      await readDocument(tester, 'Leer');
      expect(texts.fetched.single, 'https://docs.test/terminos');
      await tester.tap(terms);
      await tester.pump();
      await readDocument(tester, 'Leer');
      await tester.tap(find.byKey(const Key('accept-PRIVACY_POLICY')));
      await tester.pump();
      await submit(tester);
      final body = backend.bodyOf('POST', '/auth/register');
      expect(body['acceptedTermsVersion'], 'T-PRUEBA-1');
      expect(body['acceptedPrivacyVersion'], 'P-PRUEBA-1');
      expect(body['acceptsStudyParticipation'], isTrue, reason: 'research consent is a separate decision');
    });

    testWidgets('the reader shows the whole text and its version; accepting needs reaching the end', (tester) async {
      await open(tester, documents: withDocuments);
      await tester.ensureVisible(find.text('Leer').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leer').first);
      await tester.pumpAndSettle();
      expect(find.text(syntheticTerms), findsOneWidget);
      expect(find.text('Versión T-PRUEBA-1'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('accept-TERMS_OF_SERVICE'))).onChanged, isNull,
          reason: 'leaving without finishing does not count as read');
    });

    Future<void> acceptAll(WidgetTester tester) async {
      await fillAccount(tester);
      await readDocument(tester, 'Leer');
      await tester.tap(find.byKey(const Key('accept-TERMS_OF_SERVICE')));
      await readDocument(tester, 'Leer');
      await tester.tap(find.byKey(const Key('accept-PRIVACY_POLICY')));
      await tester.ensureVisible(find.byKey(const Key('accept-study')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accept-study')));
      await submit(tester);
    }

    testWidgets('outdated version (422): clear message, account not created, documents must be read again', (tester) async {
      await open(tester, documents: withDocuments,
          register: (_) => (status: 422, body: apiErrorBody(422, 'La version aceptada de TERMS_OF_SERVICE no es la vigente (T-2).')));
      await acceptAll(tester);
      expect(find.text('Los documentos cambiaron'), findsOneWidget);
      expect(find.textContaining('Tu cuenta no se creó'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Preparando cuenta'), findsNothing);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('accept-TERMS_OF_SERVICE'))).value, isFalse);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('accept-TERMS_OF_SERVICE'))).onChanged, isNull);
    });

    testWidgets('document not published (422): explained, nothing created', (tester) async {
      await open(tester, documents: withDocuments,
          register: (_) => (status: 422, body: apiErrorBody(422, 'Todavia no hay una version aprobada de TERMS_OF_SERVICE: no se puede aceptar.')));
      await acceptAll(tester);
      expect(find.textContaining('todavía no está publicado'), findsOneWidget);
    });

    testWidgets('lost connection while creating: message, fields kept, no navigation', (tester) async {
      await open(tester, register: (o) => throw connectionLost(o.path));
      await fillAccount(tester);
      await tester.tap(find.byKey(const Key('accept-study')));
      await submit(tester);
      expect(find.text('Preparando cuenta'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'ana@audit.local'), findsOneWidget);
    });

    testWidgets('study consent document: participation can be accepted only after reading it', (tester) async {
      await open(tester, documents: const SignUpDocuments(studyConsent: LegalDocument(type: ConsentType.studyParticipation,
          title: 'Consentimiento informado del estudio', url: 'https://docs.test/consentimiento', version: 'C-PRUEBA-1')));
      final box = find.byKey(const Key('accept-study'));
      await tester.ensureVisible(box);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(box).onChanged, isNull);
      expect(find.text('Primero lee el consentimiento informado.'), findsOneWidget);
      await readDocument(tester, 'Leer el consentimiento informado (versión C-PRUEBA-1)');
      expect(tester.widget<CheckboxListTile>(box).onChanged, isNotNull);
    });
  });

  group('SignUpDocuments from the build configuration', () {
    test('a document appears only with both its address and its approved version', () {
      expect(SignUpDocuments.fromConfig(termsUrl: 'https://x/t', termsVersion: '', privacyUrl: '', privacyVersion: '', studyConsentUrl: '').required, isEmpty);
      final docs = SignUpDocuments.fromConfig(termsUrl: 'https://x/t', termsVersion: 'T1', privacyUrl: 'https://x/p', privacyVersion: 'P1', studyConsentUrl: '');
      expect(docs.required.map((d) => d.version), ['T1', 'P1']);
      expect(docs.urlFor(ConsentType.termsOfService, 'T1'), 'https://x/t');
      expect(docs.urlFor(ConsentType.termsOfService, 'T0'), isNull, reason: 'another version is not this text');
    });

    test('HTML documents are shown as plain text', () {
      expect(DocumentTextRepository.plainText('<h1>Título</h1><p>Uno &amp; dos</p><ul><li>a</li></ul>'), 'Título\nUno & dos\n• a');
    });
  });
}
