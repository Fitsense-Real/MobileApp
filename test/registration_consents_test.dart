// Mobile-C1: sign-up with option A (Kora is only for participants of the
// study) and the documents the backend publishes (`GET /api/v1/legal-documents`,
// `acceptedStudyConsentVersion`). The fake backend answers exactly like Backend
// `generation` 41c498a (LegalDocumentsController, ConsentimientoService,
// GlobalExceptionHandler). Documents are synthetic, for tests only.
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/core/api/api_error.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/register_page.dart';
import 'package:fitsense_mobile/features/consents/data/consents_repository.dart';
import 'package:fitsense_mobile/features/consents/data/document_text_repository.dart';
import 'package:fitsense_mobile/features/consents/domain/legal_documents.dart';
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

/// The privacy policy address answers 404: its text can never be shown.
class BrokenDocuments extends FakeDocuments {
  @override
  Future<String> fetch(String url) async {
    if (url.contains('privacidad')) {
      throw DioException(requestOptions: RequestOptions(path: url), type: DioExceptionType.badResponse,
          response: Response(requestOptions: RequestOptions(path: url), statusCode: 404, data: 'Not Found'));
    }
    return super.fetch(url);
  }
}

/// `DocumentoResource` exactly as the backend sends it.
Map<String, dynamic> doc(String type, String version, String url, {String status = 'PUBLISHED', String? title}) =>
    {'type': type, 'version': version, 'title': title ?? 'Documento sintético', 'url': url, 'status': status, 'effectiveFrom': '2026-11-01'};

/// `DocumentosResource`: what `GET /legal-documents` answers.
Map<String, dynamic> published({bool enforced = false, String privacyRecord = 'ACEPTACION', List<Map<String, dynamic>>? documents}) => {
      'enforcedOnSignup': enforced,
      'privacyRecord': privacyRecord,
      'documents': documents ?? [
        doc('TERMS_OF_SERVICE', 'T-PRUEBA-1', 'https://docs.test/terminos', title: 'Condiciones de uso'),
        doc('PRIVACY_POLICY', 'P-PRUEBA-1', 'https://docs.test/privacidad', title: 'Política de privacidad'),
        doc('STUDY_PARTICIPATION', 'C-PRUEBA-1', 'https://docs.test/consentimiento', title: 'Consentimiento informado'),
      ],
    };

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ScriptedBackend> open(WidgetTester tester, {
    FakeAnswer Function(RequestOptions)? register,
    List<FakeAnswer Function(RequestOptions)>? documents,
    FakeDocuments? texts,
    Map<String, List<String>> Function(RequestOptions)? headers,
  }) async {
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Each GET /legal-documents takes the next answer; the last one repeats.
    final answers = documents ?? [(_) => (status: 200, body: published())];
    var calls = 0;
    final backend = ScriptedBackend((o) => switch ('${o.method} ${o.path}') {
      'GET /legal-documents' => answers[(calls++).clamp(0, answers.length - 1)](o),
      'POST /auth/register' => register?.call(o) ?? (status: 201, body: userResource(participant: (o.data as Map)['acceptsStudyParticipation'] == true)),
      'POST /auth/login' => (status: 200, body: {'userId': 41, 'email': 'ana@audit.local', 'fullName': 'Ana Prueba', 'token': 'jwt-nuevo'}),
      'GET /users/me' => (status: 200, body: userResource()),
      _ => (status: 404, body: apiErrorBody(404, 'No encontrado')),
    }, headers: headers);
    final router = GoRouter(initialLocation: AppRoutes.register, routes: [
      GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterPage()),
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const Scaffold(body: Text('Bienvenida'))),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const Scaffold(body: Text('Pantalla de login'))),
      GoRoute(path: AppRoutes.accountSetup, builder: (_, __) => const Scaffold(body: Text('Preparando cuenta'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      dioProvider.overrideWithValue(scriptedDio(backend)),
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

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('CREAR CUENTA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREAR CUENTA'));
    await tester.pumpAndSettle();
  }

  /// Opens the document of [type] and reads it to the end.
  Future<void> read(WidgetTester tester, String type) async {
    await tapKey(tester, 'read-$type');
    await tester.tap(find.text('He leído el documento'));
    await tester.pumpAndSettle();
  }

  /// Reads the three published documents and accepts them.
  Future<void> acceptAll(WidgetTester tester, {bool participate = true}) async {
    await fillAccount(tester);
    await read(tester, 'TERMS_OF_SERVICE');
    await tapKey(tester, 'accept-TERMS_OF_SERVICE');
    await read(tester, 'PRIVACY_POLICY');
    await tapKey(tester, 'accept-PRIVACY_POLICY');
    await read(tester, 'STUDY_PARTICIPATION');
    if (participate) await tapKey(tester, 'accept-study');
  }

  CheckboxListTile box(WidgetTester tester, String key) => tester.widget<CheckboxListTile>(find.byKey(Key(key)));

  group('option A: Kora is only for participants', () {
    testWidgets('the study is explained before anything is typed; nothing is pre-checked or acceptable unread', (tester) async {
      await open(tester);
      expect(find.text('Kora es parte de un estudio'), findsOneWidget);
      expect(find.textContaining('es exclusiva para las personas que aceptan participar'), findsOneWidget);
      expect(find.textContaining('Opcional'), findsNothing);
      for (final key in ['accept-TERMS_OF_SERVICE', 'accept-PRIVACY_POLICY', 'accept-study']) {
        expect(box(tester, key).value, isFalse, reason: '$key never pre-checked');
        expect(box(tester, key).onChanged, isNull, reason: '$key cannot be accepted unread');
      }
      expect(find.text('Consentimiento informado · versión C-PRUEBA-1'), findsOneWidget);
    });

    testWidgets('without accepting to take part no account is created', (tester) async {
      final backend = await open(tester);
      await acceptAll(tester, participate: false);
      await submit(tester);
      expect(find.textContaining('Kora es solo para participantes'), findsOneWidget);
      expect(backend.routes, isNot(contains('POST /auth/register')));
    });

    testWidgets('«No deseo participar»: respectful message, leaves sign-up, nothing created or kept', (tester) async {
      final backend = await open(tester);
      await fillAccount(tester);
      await tapKey(tester, 'decline-study');
      expect(find.text('No participar en el estudio'), findsOneWidget);
      expect(find.textContaining('no se creará ninguna cuenta'), findsOneWidget);
      for (final wrong in ['Error inesperado', 'Reintentar generación', 'ya aceptaste']) {
        expect(find.textContaining(wrong), findsNothing, reason: wrong);
      }
      await tester.tap(find.byKey(const Key('leave-sign-up')));
      await tester.pumpAndSettle();
      expect(find.text('Bienvenida'), findsOneWidget);
      expect(backend.routes.where((r) => r.startsWith('POST')), isEmpty, reason: 'no request creates anything');
    });

    testWidgets('«Volver al registro» keeps what was typed', (tester) async {
      await open(tester);
      await fillAccount(tester);
      await tapKey(tester, 'decline-study');
      await tester.tap(find.text('Volver al registro'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'ana@audit.local'), findsOneWidget);
    });

    testWidgets('accepted: the four fields carry exactly the versions read, re-checked first; then signed in', (tester) async {
      final texts = FakeDocuments();
      final backend = await open(tester, texts: texts);
      await acceptAll(tester);
      await submit(tester);
      expect(texts.fetched, ['https://docs.test/terminos', 'https://docs.test/privacidad', 'https://docs.test/consentimiento']);
      final body = backend.bodyOf('POST', '/auth/register');
      expect(body['acceptsStudyParticipation'], isTrue);
      expect(body['acceptedTermsVersion'], 'T-PRUEBA-1');
      expect(body['acceptedPrivacyVersion'], 'P-PRUEBA-1');
      expect(body['acceptedStudyConsentVersion'], 'C-PRUEBA-1');
      expect(body['timezone'], 'America/Lima');
      expect(backend.routes, containsAllInOrder(['GET /legal-documents', 'GET /legal-documents', 'POST /auth/register', 'POST /auth/login', 'GET /users/me']),
          reason: 'the published versions are checked again right before sending');
      expect(find.text('Preparando cuenta'), findsOneWidget);
    });

    testWidgets('only the informed consent published: still closed, and it says what is missing', (tester) async {
      final backend = await open(tester, documents: [(_) => (status: 200, body: published(documents: [
            doc('STUDY_PARTICIPATION', 'C-PRUEBA-1', 'https://docs.test/consentimiento'),
          ]))]);
      expect(find.text('El registro todavía no está abierto'), findsOneWidget);
      expect(find.textContaining('todavía faltan: las condiciones de uso, la política de privacidad.'), findsOneWidget);
      expect(find.text('CREAR CUENTA'), findsNothing);
      expect(backend.routes, ['GET /legal-documents']);
    });

    testWidgets('privacy recorded as CONSTANCIA: «He leído», not «Acepto»', (tester) async {
      await open(tester, documents: [(_) => (status: 200, body: published(privacyRecord: 'CONSTANCIA'))]);
      expect(find.text('He leído la política de privacidad'), findsOneWidget);
      expect(find.text('Acepto la política de privacidad'), findsNothing);
    });
  });

  group('no valid acceptance possible: sign-up stays closed', () {
    testWidgets('no informed consent published (today): no form, an explanation, nothing can be sent', (tester) async {
      final backend = await open(tester, documents: [(_) => (status: 200, body: published(documents: []))]);
      expect(find.text('El registro todavía no está abierto'), findsOneWidget);
      expect(find.textContaining('todavía faltan: las condiciones de uso, la política de privacidad, el consentimiento informado.'), findsOneWidget);
      expect(find.text('CREAR CUENTA'), findsNothing);
      expect(find.byKey(const Key('accept-study')), findsNothing, reason: 'no participation without a document to accept');
      expect(backend.routes, ['GET /legal-documents']);
    });

    testWidgets('terms and privacy published but not the consent: still closed', (tester) async {
      await open(tester, documents: [(_) => (status: 200, body: published(documents: [
            doc('TERMS_OF_SERVICE', 'T-PRUEBA-1', 'https://docs.test/terminos'),
            doc('PRIVACY_POLICY', 'P-PRUEBA-1', 'https://docs.test/privacidad'),
          ]))]);
      expect(find.text('El registro todavía no está abierto'), findsOneWidget);
      expect(find.textContaining('falta: el consentimiento informado'), findsOneWidget);
    });

    testWidgets('consent and terms but no privacy policy: still closed', (tester) async {
      await open(tester, documents: [(_) => (status: 200, body: published(documents: [
            doc('TERMS_OF_SERVICE', 'T-PRUEBA-1', 'https://docs.test/terminos'),
            doc('STUDY_PARTICIPATION', 'C-PRUEBA-1', 'https://docs.test/consentimiento'),
          ]))]);
      expect(find.textContaining('falta: la política de privacidad'), findsOneWidget);
      expect(find.text('CREAR CUENTA'), findsNothing);
    });

    testWidgets('documents cannot be checked (no connection): says so, «Reintentar» reads them again', (tester) async {
      final backend = await open(tester, documents: [
        (o) => throw connectionLost(o.path),
        (_) => (status: 200, body: published()),
      ]);
      expect(find.text('No pudimos consultar los documentos'), findsOneWidget);
      expect(find.text('CREAR CUENTA'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('CREAR CUENTA'), findsOneWidget);
      expect(backend.routes.where((r) => r == 'GET /legal-documents'), hasLength(2));
    });
  });

  group('version changes and backend refusals', () {
    testWidgets('a new version published while signing up: not sent, explained, must be read again', (tester) async {
      final backend = await open(tester, documents: [
        (_) => (status: 200, body: published()),
        (_) => (status: 200, body: published(documents: [
              doc('TERMS_OF_SERVICE', 'T-PRUEBA-2', 'https://docs.test/terminos'),
              doc('PRIVACY_POLICY', 'P-PRUEBA-1', 'https://docs.test/privacidad'),
              doc('STUDY_PARTICIPATION', 'C-PRUEBA-1', 'https://docs.test/consentimiento'),
            ])),
      ]);
      await acceptAll(tester);
      await submit(tester);
      expect(find.text('Los documentos cambiaron'), findsOneWidget);
      expect(find.textContaining('Tu cuenta no se creó'), findsOneWidget);
      expect(backend.routes, isNot(contains('POST /auth/register')), reason: 'an outdated version is never sent');
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.textContaining('versión T-PRUEBA-2'), findsOneWidget, reason: 'the current version is shown');
      expect(box(tester, 'accept-TERMS_OF_SERVICE').value, isFalse);
      expect(box(tester, 'accept-TERMS_OF_SERVICE').onChanged, isNull, reason: 'it has to be read again');
      expect(box(tester, 'accept-study').value, isFalse);
    });

    for (final (name, message) in [
      ('outdated terms', 'La version aceptada de TERMS_OF_SERVICE no es la vigente (T-2).'),
      ('outdated privacy', 'La version aceptada de PRIVACY_POLICY no es la vigente (P-2).'),
      ('outdated study consent', 'La version aceptada de STUDY_PARTICIPATION no es la vigente (C-2).'),
      ('consent required', 'Para participar en el estudio tienes que aceptar la version vigente del consentimiento informado.'),
    ]) {
      testWidgets('422 $name: account not created, documents read again', (tester) async {
        await open(tester, register: (_) => (status: 422, body: apiErrorBody(422, message)));
        await acceptAll(tester);
        await submit(tester);
        expect(find.text('Los documentos cambiaron'), findsOneWidget);
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
        expect(find.text('Preparando cuenta'), findsNothing);
        expect(box(tester, 'accept-study').value, isFalse);
      });
    }

    testWidgets('422 document no longer published: explained, nothing created', (tester) async {
      await open(tester, register: (_) => (status: 422, body: apiErrorBody(422, 'Todavia no hay una version aprobada de STUDY_PARTICIPATION: no se puede aceptar.')));
      await acceptAll(tester);
      await submit(tester);
      expect(find.textContaining('ya no está publicado'), findsOneWidget);
    });

    testWidgets('429: the backend message and how long to wait, no internal code, nothing else happens', (tester) async {
      await open(tester,
          register: (_) => (status: 429, body: {...apiErrorBody(429, 'Demasiadas solicitudes desde esta conexion. Espera antes de volver a intentarlo.'), 'details': ['DEMASIADAS_SOLICITUDES']}),
          headers: (o) => o.path == '/auth/register' ? {'retry-after': ['540']} : const {});
      await acceptAll(tester);
      await submit(tester);
      final snack = tester.widget<Text>(find.descendant(of: find.byType(SnackBar), matching: find.byType(Text))).data!;
      expect(snack, contains('Demasiadas solicitudes'));
      expect(snack, contains('9 minutos'));
      expect(snack, isNot(contains('DEMASIADAS_SOLICITUDES')));
      expect(find.text('Preparando cuenta'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'ana@audit.local'), findsOneWidget, reason: 'nothing typed is lost');
    });

    testWidgets('422 with the stable code of Backend #96 (whatever the text): documents read again', (tester) async {
      await open(tester, register: (_) => (status: 422, body: {...apiErrorBody(422, 'Texto cualquiera.'), 'details': ['VERSION_NO_VIGENTE']}));
      await acceptAll(tester);
      await submit(tester);
      expect(find.text('Los documentos cambiaron'), findsOneWidget);
    });

    testWidgets('e-mail already registered: said clearly; form and acceptances kept; not a document problem', (tester) async {
      await open(tester, register: (_) => (status: 422, body: apiErrorBody(422, 'Ya existe una cuenta registrada con el correo ana@audit.local.')));
      await acceptAll(tester);
      await submit(tester);
      expect(find.text('Los documentos cambiaron'), findsNothing);
      expect(find.textContaining('Ya existe una cuenta registrada'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'ana@audit.local'), findsOneWidget);
      expect(box(tester, 'accept-study').value, isTrue, reason: 'only the e-mail has to be corrected');
    });

    testWidgets('unexpected answer (500 with an HTML page): a clear message, nothing lost', (tester) async {
      await open(tester, register: (_) => (status: 500, body: '<html>Error</html>'));
      await acceptAll(tester);
      await submit(tester);
      final snack = tester.widget<Text>(find.descendant(of: find.byType(SnackBar), matching: find.byType(Text))).data!;
      expect(snack, contains('El servidor tuvo un problema (500)'));
      expect(snack, isNot(contains('<html>')));
      expect(find.text('Preparando cuenta'), findsNothing);
      expect(box(tester, 'accept-study').value, isTrue);
    });

    testWidgets('429 without Retry-After (as Flutter web sees it): no waiting time is invented', (tester) async {
      await open(tester, register: (_) => (status: 429, body: {...apiErrorBody(429, 'Demasiadas solicitudes desde esta conexion. Espera antes de volver a intentarlo.'), 'details': ['DEMASIADAS_SOLICITUDES']}));
      await acceptAll(tester);
      await submit(tester);
      final snack = tester.widget<Text>(find.descendant(of: find.byType(SnackBar), matching: find.byType(Text))).data!;
      expect(snack, 'Demasiadas solicitudes desde esta conexion. Espera antes de volver a intentarlo.');
    });

    testWidgets('lost connection while creating: message, fields and acceptances kept, no navigation', (tester) async {
      await open(tester, register: (o) => throw connectionLost(o.path));
      await acceptAll(tester);
      await submit(tester);
      expect(find.text('Preparando cuenta'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'ana@audit.local'), findsOneWidget);
      expect(box(tester, 'accept-study').value, isTrue);
    });

    testWidgets('lost connection on the final check: nothing is sent', (tester) async {
      final backend = await open(tester, documents: [
        (_) => (status: 200, body: published()),
        (o) => throw connectionLost(o.path),
      ]);
      await acceptAll(tester);
      await submit(tester);
      expect(find.textContaining('Tu cuenta no se creó'), findsOneWidget);
      expect(backend.routes, isNot(contains('POST /auth/register')));
    });
  });

  group('reading and time zone', () {
    testWidgets('the reader shows the whole text and its version; leaving unfinished does not count', (tester) async {
      await open(tester);
      await tapKey(tester, 'read-TERMS_OF_SERVICE');
      expect(find.text(syntheticTerms), findsOneWidget);
      expect(find.text('Versión T-PRUEBA-1'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(box(tester, 'accept-TERMS_OF_SERVICE').onChanged, isNull);
    });

    testWidgets('a document that cannot be opened (broken address): error, «Reintentar», and it can never be accepted', (tester) async {
      await open(tester, texts: BrokenDocuments());
      await tapKey(tester, 'read-PRIVACY_POLICY');
      expect(find.textContaining('No se pudo abrir el documento'), findsOneWidget);
      expect(find.text('He leído el documento'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(box(tester, 'accept-PRIVACY_POLICY').onChanged, isNull, reason: 'not shown = not read = not acceptable');
    });

    testWidgets('a closed list of IANA zones; the choice is what is sent', (tester) async {
      final backend = await open(tester);
      await acceptAll(tester);
      await tapKey(tester, 'timezone');
      await tester.tap(find.text('Colombia (Bogotá)').last);
      await tester.pumpAndSettle();
      await submit(tester);
      expect(backend.bodyOf('POST', '/auth/register')['timezone'], 'America/Bogota');
    });
  });

  group('PublishedDocuments (DocumentosResource of backend 41c498a)', () {
    test('the real shape; only PUBLISHED documents with type, version and address count', () {
      final docs = PublishedDocuments.fromJson(published(enforced: true, privacyRecord: 'CONSTANCIA', documents: [
        doc('TERMS_OF_SERVICE', 'T-1', 'https://x/t'),
        doc('PRIVACY_POLICY', 'P-1', 'https://x/p', status: 'DRAFT'),
        doc('OTRO', 'X', 'https://x/o'),
        doc('STUDY_PARTICIPATION', ' C-1 ', 'https://x/c', title: ''),
      ]));
      expect(docs.enforcedOnSignup, isTrue);
      expect(docs.privacyRecord, PrivacyRecord.acknowledgement);
      expect(docs.toRead.map((d) => '${d.type.code}=${d.version}'), ['TERMS_OF_SERVICE=T-1', 'STUDY_PARTICIPATION=C-1']);
      expect(docs.studyConsent!.title, 'Consentimiento informado del estudio');
      expect(docs.signUpOpen, isFalse, reason: 'the privacy policy is a draft: not published');
      expect(docs.missing, [ConsentType.privacyPolicy]);
      expect(PublishedDocuments.fromJson(published()).signUpOpen, isTrue);
      expect(PublishedDocuments.fromJson(published(documents: [])).missing, hasLength(3));
    });

    test('changedSince: a new version, a withdrawn document or a new one all count as a change', () {
      final before = PublishedDocuments.fromJson(published());
      expect(before.changedSince(before.toRead), isFalse);
      final newTerms = PublishedDocuments.fromJson(published(documents: [
        doc('TERMS_OF_SERVICE', 'T-2', 'https://docs.test/terminos'),
        doc('PRIVACY_POLICY', 'P-PRUEBA-1', 'https://docs.test/privacidad'),
        doc('STUDY_PARTICIPATION', 'C-PRUEBA-1', 'https://docs.test/consentimiento'),
      ]));
      expect(newTerms.changedSince(before.toRead), isTrue);
      final fewer = PublishedDocuments.fromJson(published(documents: [doc('STUDY_PARTICIPATION', 'C-PRUEBA-1', 'https://docs.test/consentimiento')]));
      expect(fewer.changedSince(before.toRead), isTrue);
      expect(before.changedSince(fewer.toRead), isTrue);
    });

    test('backend 422 messages about documents are recognised', () {
      expect(isDocumentProblem('La version aceptada de TERMS_OF_SERVICE no es la vigente (T-2).'), isTrue);
      expect(isDocumentProblem('Todavia no hay una version aprobada de PRIVACY_POLICY: no se puede aceptar.'), isTrue);
      expect(isDocumentProblem('Para registrarte tienes que aceptar las condiciones de uso y la politica de privacidad.'), isTrue);
      expect(isDocumentProblem('Ya existe una cuenta registrada con el correo x@audit.local.'), isFalse);
      for (final code in ['CONSENTIMIENTO_REQUERIDO', 'PARTICIPACION_REQUERIDA', 'DOCUMENTO_NO_PUBLICADO', 'VERSION_NO_VIGENTE', 'VERSION_SIN_PARTICIPACION']) {
        expect(isDocumentProblem('texto', code: code), isTrue, reason: code);
      }
      expect(isUnpublishedDocument('texto', code: 'DOCUMENTO_NO_PUBLICADO'), isTrue);
    });

    test('HTML documents are shown as plain text', () {
      expect(DocumentTextRepository.plainText('<h1>Título</h1><p>Uno &amp; dos</p><ul><li>a</li></ul>'), 'Título\nUno & dos\n• a');
    });

    test('apiError: machine codes are not shown; a 429 says how long to wait', () {
      DioException error(int status, Map<String, dynamic> body, {String? retryAfter}) => DioException(
            requestOptions: RequestOptions(path: '/x'),
            response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: body,
                headers: Headers.fromMap({if (retryAfter != null) 'retry-after': [retryAfter]})),
            type: DioExceptionType.badResponse);
      expect(apiError(error(429, {'message': 'Espera.', 'details': ['DEMASIADAS_SOLICITUDES']}, retryAfter: '61')), 'Espera. Podrás intentarlo de nuevo en 2 minutos.');
      expect(apiError(error(409, {'message': 'Tu plan cambio.', 'details': ['PLAN_CAMBIADO_DURANTE_LA_GENERACION']})), 'Tu plan cambio.');
      expect(apiError(error(400, {'message': 'Campos.', 'details': ['heightCm: no debe ser nulo']})), 'Campos.\nheightCm: no debe ser nulo');
      expect(apiError(error(429, {})), startsWith('Demasiadas solicitudes'));
    });
  });

  group('ConsentStatus history (ConsentimientoResource)', () {
    test('date, evidence and kind are kept apart; a participation without approved document is flagged', () {
      final status = ConsentStatus.fromJson({
        'currentVersions': {'STUDY_PARTICIPATION': 'MVP-1.0', 'TERMS_OF_SERVICE': null, 'PRIVACY_POLICY': 'P-1'},
        'approvedDocuments': {'STUDY_PARTICIPATION': false, 'TERMS_OF_SERVICE': false, 'PRIVACY_POLICY': true},
        'enforcedOnSignup': false,
        'history': [
          {'type': 'STUDY_PARTICIPATION', 'documentVersion': 'MVP-1.0', 'grantedAt': '2026-11-27T21:18:19Z', 'affirmativeAction': 'CASILLA_SIN_DOCUMENTO_APROBADO', 'source': 'APP', 'withdrawnAt': null},
          {'type': 'PRIVACY_POLICY', 'documentVersion': 'P-1', 'grantedAt': '2026-11-27T21:18:19Z', 'affirmativeAction': 'CONSTANCIA_DE_LECTURA', 'source': 'APP', 'withdrawnAt': null},
        ],
      });
      expect(status.accepted(ConsentType.studyParticipation)!.withoutApprovedDocument, isTrue);
      expect(status.accepted(ConsentType.privacyPolicy)!.acknowledgement, isTrue);
      expect(status.accepted(ConsentType.privacyPolicy)!.grantedAt, '2026-11-27T21:18:19Z');
      expect(status.accepted(ConsentType.termsOfService), isNull);
    });
  });
}
