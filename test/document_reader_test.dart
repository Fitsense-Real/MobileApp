// Documents shown entirely in Flutter (Mobile, registration): only text or
// HTML can be shown and therefore read; links keep their destination; the
// reader and the sign-up stay usable on a small screen with large text; and
// accepting is not lost by rotating the phone or scrolling. Synthetic
// documents, tests only.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/register_page.dart';
import 'package:fitsense_mobile/features/consents/data/consents_repository.dart';
import 'package:fitsense_mobile/features/consents/data/document_text_repository.dart';
import 'package:fitsense_mobile/features/consents/domain/legal_documents.dart';
import 'package:fitsense_mobile/features/consents/presentation/document_reader_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/fake_backend.dart';

/// Serves one body with the given Content-Type values, like a document host.
class DocumentHost implements HttpClientAdapter {
  DocumentHost(this.body, this.types);
  final List<int> body;
  final List<String> types;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async =>
      ResponseBody.fromBytes(body, 200, headers: {if (types.isNotEmpty) Headers.contentTypeHeader: types});
  @override
  void close({bool force = false}) {}
}

DocumentTextRepository host(List<int> body, List<String> types) => DocumentTextRepository(Dio()..httpClientAdapter = DocumentHost(body, types));

final pdf = [...utf8.encode('%PDF-1.7\n'), 0, 1, 2, 255, 254, ...utf8.encode('stream')];
final longText = utf8.encode('DOCUMENTO SINTÉTICO DE PRUEBA - NO APROBADO\n\n${List.generate(60, (i) => 'Párrafo $i con un texto largo para comprobar el desplazamiento en una pantalla pequeña.').join('\n\n')}\n\nFin.');

const doc = LegalDocument(type: ConsentType.studyParticipation, title: 'Consentimiento informado del estudio', url: 'https://docs.test/consentimiento', version: 'C-PRUEBA-1');

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('what can be shown (and therefore read)', () {
    test('text and HTML are shown; a repeated Content-Type does not break it', () async {
      expect(await host(utf8.encode('Texto sintético.'), ['text/plain; charset=utf-8']).fetch('https://docs.test/t'), 'Texto sintético.');
      expect(await host(utf8.encode('<p>Hola</p>'), ['text/html', 'text/html; charset=utf-8']).fetch('https://docs.test/h'), 'Hola');
      expect(await host(utf8.encode('Sin cabecera.'), []).fetch('https://docs.test/s'), 'Sin cabecera.');
    });

    test('a PDF, an image or a binary file is reported as not openable (never shown as text)', () async {
      for (final (body, types) in [
        (pdf, ['application/pdf']),
        (pdf, ['application/octet-stream']),
        (pdf, <String>[]),
        ([137, 80, 78, 71, 13, 10, 26, 10, 0, 0], ['image/png']),
      ]) {
        await expectLater(host(body, types).fetch('https://docs.test/x'), throwsA(isA<FormatException>().having((e) => e.message, 'message', DocumentTextRepository.unsupportedFormat)),
            reason: '$types');
      }
    });

    test('links keep their destination (a contact address or page never vanishes)', () {
      expect(DocumentTextRepository.plainText('<p>Escribe a <a href="mailto:equipo@estudio.example">el equipo</a> o visita '
          '<a href="https://estudio.example/retirada">esta página</a>.</p>'), 'Escribe a el equipo (equipo@estudio.example) o visita esta página (https://estudio.example/retirada).');
      expect(DocumentTextRepository.plainText('<a href="https://estudio.example">https://estudio.example</a>'), 'https://estudio.example');
      expect(DocumentTextRepository.plainText('<a href="#seccion-2">Ver la sección 2</a>'), 'Ver la sección 2');
      expect(DocumentTextRepository.plainText('<a href="javascript:void(0)">Nada</a>'), 'Nada');
    });
  });

  Future<void> openReader(WidgetTester tester, DocumentTextRepository repository, {Size size = const Size(320, 568), double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [documentTextRepositoryProvider.overrideWithValue(repository)],
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(theme: AppTheme.light, home: const Scaffold(body: SizedBox())),
      ),
    ));
  }

  testWidgets('a PDF in the reader: explained, «Reintentar», and no «He leído el documento»', (tester) async {
    await openReader(tester, host(pdf, ['application/pdf']));
    final read = DocumentReaderPage.open(tester.element(find.byType(SizedBox).first), doc);
    await tester.pumpAndSettle();
    expect(find.textContaining('no está en un formato que Kora pueda mostrar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('He leído el documento'), findsNothing);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(await read, isFalse, reason: 'not shown = not read');
  });

  testWidgets('320 × 568 with text at 200 %: readable, scrollable to the end, back to the sign-up', (tester) async {
    await openReader(tester, host(longText, ['text/plain; charset=utf-8']), textScale: 2);
    final read = DocumentReaderPage.open(tester.element(find.byType(SizedBox).first), doc);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
    expect(find.text('Desplázate hasta el final para continuar'), findsOneWidget);
    final scrollable = find.descendant(of: find.byType(DocumentReaderPage), matching: find.byType(Scrollable)).first;
    // At 200 % the synthetic document is very long: scroll until its end.
    for (var i = 0; i < 100 && find.text('He leído el documento').evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -3000));
      await tester.pumpAndSettle();
    }
    expect(find.text('He leído el documento'), findsOneWidget);
    await tester.tap(find.text('He leído el documento'));
    await tester.pumpAndSettle();
    expect(await read, isTrue);
    expect(tester.takeException(), isNull);
  });

  group('sign-up', () {
    Map<String, dynamic> published() => {
          'enforcedOnSignup': true, 'privacyRecord': 'ACEPTACION',
          'documents': [
            for (final (t, v) in [('TERMS_OF_SERVICE', 'T-PRUEBA-1'), ('PRIVACY_POLICY', 'P-PRUEBA-1'), ('STUDY_PARTICIPATION', 'C-PRUEBA-1')])
              {'type': t, 'version': v, 'title': 'Documento sintético $t', 'url': 'https://docs.test/$t', 'status': 'PUBLISHED', 'effectiveFrom': '2026-11-01', 'requiredForSignup': true},
          ],
        };

    Future<void> openSignUp(WidgetTester tester, Size size, {double textScale = 1}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = ScriptedBackend((o) => o.path == '/legal-documents' ? (status: 200, body: published()) : (status: 404, body: apiErrorBody(404, 'No')));
      final router = GoRouter(initialLocation: AppRoutes.register, routes: [GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterPage())]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [dioProvider.overrideWithValue(scriptedDio(backend)), documentTextRepositoryProvider.overrideWithValue(host(utf8.encode('Texto sintético corto.'), ['text/plain']))],
        child: MediaQuery(data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)), child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    Future<void> read(WidgetTester tester, String type) async {
      await tapKey(tester, 'read-$type');
      await tester.tap(find.text('He leído el documento'));
      await tester.pumpAndSettle();
    }

    CheckboxListTile box(WidgetTester tester, String key) => tester.widget<CheckboxListTile>(find.byKey(Key(key)));

    testWidgets('320 px with text at 200 %: every document and box can be reached, nothing overflows', (tester) async {
      await openSignUp(tester, const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull);
      for (final key in ['read-TERMS_OF_SERVICE', 'read-PRIVACY_POLICY', 'read-STUDY_PARTICIPATION', 'accept-study', 'decline-study']) {
        // The list builds what is near the screen: scroll down to each one.
        await tester.scrollUntilVisible(find.byKey(Key(key)), 250, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.byKey(Key(key)).hitTestable(), findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('acceptances survive rotating the phone and scrolling away and back', (tester) async {
      await openSignUp(tester, const Size(390, 844));
      await read(tester, 'TERMS_OF_SERVICE');
      await tapKey(tester, 'accept-TERMS_OF_SERVICE');
      await read(tester, 'PRIVACY_POLICY');
      await tapKey(tester, 'accept-PRIVACY_POLICY');
      await read(tester, 'STUDY_PARTICIPATION');
      await tapKey(tester, 'accept-study');
      // Landscape and back.
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      // Far up (the boxes leave the screen) and down again.
      await tester.drag(find.byType(ListView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('accept-study')), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      for (final key in ['accept-TERMS_OF_SERVICE', 'accept-PRIVACY_POLICY', 'accept-study']) {
        expect(box(tester, key).value, isTrue, reason: key);
      }
    });
  });
}
