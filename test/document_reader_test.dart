// Documents shown entirely in Flutter (Mobile, registration): only text or
// HTML can be shown and therefore read; links keep their destination; the
// reader and the sign-up stay usable on a small screen with large text; and
// accepting is not lost by rotating the phone or scrolling. Synthetic
// documents, tests only.
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

/// Short text for every document except the privacy policy, which is a PDF.
class PdfForPrivacy extends DocumentTextRepository {
  PdfForPrivacy() : super(Dio());
  @override
  Future<String> fetchRaw(String url) =>
      (url.contains('PRIVACY') ? host(pdf, ['application/pdf']) : host(utf8.encode('Texto sintético corto.'), ['text/plain'])).fetchRaw(url);
}

DocumentTextRepository host(List<int> body, List<String> types) => DocumentTextRepository(Dio()..httpClientAdapter = DocumentHost(body, types));

final pdf = [...utf8.encode('%PDF-1.7\n'), 0, 1, 2, 255, 254, ...utf8.encode('stream')];
final longText = utf8.encode('DOCUMENTO SINTÉTICO DE PRUEBA - NO APROBADO\n\n${List.generate(60, (i) => 'Párrafo $i con un texto largo para comprobar el desplazamiento en una pantalla pequeña.').join('\n\n')}\n\nFin.');

const doc = LegalDocument(type: ConsentType.studyParticipation, title: 'Consentimiento informado del estudio', url: 'https://docs.test/consentimiento', version: 'C-PRUEBA-1');

/// The app's real fonts: word widths (a split title) are only meaningful with them.
Future<void> loadFonts() async {
  final font = FontLoader('Poppins');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
    font.addFont(rootBundle.load('assets/fonts/Poppins-$w.ttf'));
  }
  await font.load();
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}

void main() {
  setUpAll(loadFonts);
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

    test('a PDF announced as HTML or text is still blocked', () async {
      for (final types in [['text/html'], ['text/plain; charset=utf-8']]) {
        await expectLater(host(pdf, types).fetch('https://docs.test/x'), throwsA(isA<FormatException>()), reason: '$types');
      }
    });

    test('nothing active is run or shown: scripts, styles, iframes, event attributes, javascript: links', () {
      final text = DocumentTextRepository.plainText('<style>p{color:red}</style><p>Hola</p><script>alert(1)</script>'
          '<SCRIPT type="x">robar()</SCRIPT><img src=x onerror="alert(2)"><iframe src="https://malo.example"></iframe>'
          '<a href="javascript:alert(3)">pulsa</a>');
      expect(text, 'Hola\npulsa');
      for (final active in ['alert', 'robar', 'color', 'onerror', 'malo.example', 'javascript']) {
        expect(text, isNot(contains(active)), reason: active);
      }
    });

    test('the reader gets subtitles and paragraphs in order; the text is not changed', () {
      expect(DocumentTextRepository.blocks('<h1>Título</h1><p>Uno &amp; dos.</p><h2>1. <b>Datos</b></h2><p>Tres.</p><ul><li>a</li><li>b</li></ul>')
          .map((b) => '${b.heading ? '#' : ''}${b.text}'), ['#Título', 'Uno & dos.', '#1. Datos', 'Tres.', '• a', '• b']);
      expect(DocumentTextRepository.blocks('Primero.\n\n1. Uno\n2. Dos\n\nFin.').map((b) => b.text), ['Primero.', '1. Uno\n2. Dos', 'Fin.'],
          reason: 'plain text keeps its line breaks (lists stay lists)');
    });

    test('HTML entities are decoded once (accents, ¿¡, «», numeric), unknown ones kept', () {
      expect(DocumentTextRepository.plainText('<p>Informaci&#243;n &Aacute;rea &iquest;Dudas? &iexcl;S&iacute;! &uuml; &laquo;x&raquo; &#x00E9; &mdash; &amp;lt; &desconocida;</p>'),
          'Información Área ¿Dudas? ¡Sí! ü «x» é — &lt; &desconocida;');
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

  testWidgets('a PDF in the reader: explained, «Reintentar», nothing to accept, and it comes back as not shown', (tester) async {
    await openReader(tester, host(pdf, ['application/pdf']));
    final shown = DocumentReaderPage.open(tester.element(find.byType(SizedBox).first), doc);
    await tester.pumpAndSettle();
    expect(find.textContaining('no está en un formato que Kora pueda mostrar'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(await shown, isFalse, reason: 'not shown = cannot be accepted');
  });

  testWidgets('the reader is only a document: white page, dark text, title, subtitles and paragraphs in order, no buttons to accept', (tester) async {
    await openReader(tester, host(utf8.encode('<h1>Términos sintéticos</h1><p>Primer párrafo.</p><h2>1. Uso de la app</h2><p>Segundo párrafo.</p>'), ['text/html']),
        size: const Size(390, 844));
    final shown = DocumentReaderPage.open(tester.element(find.byType(SizedBox).first), doc);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.descendant(of: find.byType(AppBar), matching: find.byType(AnimatedOpacity))).opacity, 0,
        reason: 'the title is not repeated while the title of the text is visible');
    final scaffold = tester.widget<Scaffold>(find.descendant(of: find.byType(DocumentReaderPage), matching: find.byType(Scaffold)));
    expect(scaffold.backgroundColor, Colors.white);
    final texts = tester.widgetList<Text>(find.descendant(of: find.byType(ListView), matching: find.byType(Text))).map((t) => t.data).toList();
    expect(texts, ['Consentimiento informado', 'Versión C-PRUEBA-1', 'Términos sintéticos', 'Primer párrafo.', '1. Uso de la app', 'Segundo párrafo.']);
    final subtitle = tester.widget<Text>(find.text('1. Uso de la app'));
    final paragraph = tester.widget<Text>(find.text('Primer párrafo.'));
    expect(subtitle.style!.fontWeight, FontWeight.w700);
    expect(paragraph.style!.fontWeight, isNot(FontWeight.w700));
    expect(paragraph.style!.color!.computeLuminance(), lessThan(0.05), reason: 'dark text on white');
    for (final none in [FilledButton, ElevatedButton, OutlinedButton, Checkbox, Card]) {
      expect(find.descendant(of: find.byType(DocumentReaderPage), matching: find.byType(none)), findsNothing, reason: '$none');
    }
    expect(find.byTooltip('Volver'), findsOneWidget, reason: 'back arrow');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(await shown, isTrue, reason: 'shown: it can be accepted in the form, without reading to the end');
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('reader at $size, text ${(scale * 100).round()} %: no overflow, whole title and version, scrolls, back', (tester) async {
        await openReader(tester, host(longText, ['text/plain; charset=utf-8']), size: size, textScale: scale);
        final shown = DocumentReaderPage.open(tester.element(find.byType(SizedBox).first), doc);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'nothing overflows');
        expect(find.text('Versión C-PRUEBA-1'), findsOneWidget);
        // The full title at the start of the text (the bar may shorten it): no word is split.
        final title = tester.renderObject<RenderParagraph>(find.descendant(of: find.descendant(of: find.byType(ListView), matching: find.text('Consentimiento informado')), matching: find.byType(RichText)));
        expect(title.getMinIntrinsicWidth(double.infinity), lessThanOrEqualTo(title.size.width + 0.5), reason: 'a word of the title would be split');
        expect(find.byTooltip('Volver').hitTestable(), findsOneWidget, reason: 'back is always reachable');
        final scrollable = find.descendant(of: find.byType(DocumentReaderPage), matching: find.byType(Scrollable)).first;
        for (var i = 0; i < 100 && find.text('Fin.').evaluate().isEmpty; i++) {
          await tester.drag(scrollable, const Offset(0, -3000));
          await tester.pumpAndSettle();
        }
        expect(find.text('Fin.'), findsOneWidget, reason: 'the whole document can be read');
        expect(tester.widget<AnimatedOpacity>(find.descendant(of: find.byType(AppBar), matching: find.byType(AnimatedOpacity))).opacity, 1,
            reason: 'once the title of the text has scrolled away, the bar shows it');
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
        expect(await shown, isTrue);
      });
    }
  }

  group('sign-up', () {
    Map<String, dynamic> published() => {
          'enforcedOnSignup': true, 'privacyRecord': 'ACEPTACION',
          'documents': [
            for (final (t, v) in [('TERMS_OF_SERVICE', 'T-PRUEBA-1'), ('PRIVACY_POLICY', 'P-PRUEBA-1'), ('STUDY_PARTICIPATION', 'C-PRUEBA-1')])
              {'type': t, 'version': v, 'title': 'Documento sintético $t', 'url': 'https://docs.test/$t', 'status': 'PUBLISHED', 'effectiveFrom': '2026-11-01', 'requiredForSignup': true},
          ],
        };

    Future<void> openSignUp(WidgetTester tester, Size size, {double textScale = 1, DocumentTextRepository? texts}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final backend = ScriptedBackend((o) => o.path == '/legal-documents' ? (status: 200, body: published()) : (status: 404, body: apiErrorBody(404, 'No')));
      final router = GoRouter(initialLocation: AppRoutes.register, routes: [GoRoute(path: AppRoutes.register, builder: (_, __) => const RegisterPage())]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [dioProvider.overrideWithValue(scriptedDio(backend)), documentTextRepositoryProvider.overrideWithValue(texts ?? host(utf8.encode('Texto sintético corto.'), ['text/plain']))],
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

    /// Taps the name of the document inside «Acepto los …» (the link).
    Future<void> openDoc(WidgetTester tester, String type) async {
      final sentence = find.byKey(Key('read-$type'));
      await tester.ensureVisible(sentence);
      await tester.pumpAndSettle();
      final title = switch (type) { 'TERMS_OF_SERVICE' => 'Términos y condiciones', 'PRIVACY_POLICY' => 'Política de privacidad', _ => 'Consentimiento informado' };
      await tester.tapOnText(find.textRange.ofSubstring(title, descendentOf: sentence));
      await tester.pumpAndSettle();
    }

    Future<void> read(WidgetTester tester, String type) async {
      await openDoc(tester, type);
      await tester.tap(find.byTooltip('Volver').last);
      await tester.pumpAndSettle();
    }

    Checkbox box(WidgetTester tester, String key) => tester.widget<Checkbox>(find.byKey(Key(key)));

    testWidgets('320 px with text at 200 %: every document and box can be reached, nothing overflows', (tester) async {
      await openSignUp(tester, const Size(320, 640), textScale: 2);
      expect(tester.takeException(), isNull);
      for (final key in ['read-TERMS_OF_SERVICE', 'accept-TERMS_OF_SERVICE', 'read-PRIVACY_POLICY', 'accept-PRIVACY_POLICY', 'read-STUDY_PARTICIPATION', 'accept-study', 'decline-study']) {
        // The list builds what is near the screen: scroll down to each one.
        await tester.scrollUntilVisible(find.byKey(Key(key)), 250, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(find.byKey(Key(key)).hitTestable(), findsOneWidget, reason: key);
      }
      expect(tester.takeException(), isNull);
    });

    for (final (size, scale) in [(const Size(320, 640), 1.0), (const Size(320, 640), 1.3), (const Size(320, 640), 2.0), (const Size(568, 320), 2.0)]) {
      testWidgets('$size, text ${(scale * 100).round()} %: «Acepto los Términos y condiciones» and the others read well, no word split', (tester) async {
        await openSignUp(tester, size, textScale: scale);
        for (final type in ['TERMS_OF_SERVICE', 'PRIVACY_POLICY', 'STUDY_PARTICIPATION']) {
          final link = find.byKey(Key('read-$type'));
          await tester.scrollUntilVisible(link, 200, scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          final sentence = tester.renderObject<RenderParagraph>(find.descendant(of: link, matching: find.byType(RichText)));
          expect(sentence.getMinIntrinsicWidth(double.infinity), lessThanOrEqualTo(sentence.size.width + 0.5), reason: '$type: a word would be split');
          expect(find.byKey(Key(type == 'STUDY_PARTICIPATION' ? 'accept-study' : 'accept-$type')).hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a PDF document: explained in the reader; back in the form nothing typed or accepted is lost', (tester) async {
      await openSignUp(tester, const Size(390, 844), texts: PdfForPrivacy());
      await tester.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'ana@audit.local');
      await read(tester, 'TERMS_OF_SERVICE');
      await tapKey(tester, 'accept-TERMS_OF_SERVICE');
      await openDoc(tester, 'PRIVACY_POLICY');
      expect(find.textContaining('no está en un formato que Kora pueda mostrar'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'ana@audit.local'), findsOneWidget);
      expect(box(tester, 'accept-TERMS_OF_SERVICE').value, isTrue, reason: 'the other acceptance is kept');
      expect(box(tester, 'accept-PRIVACY_POLICY').onChanged, isNull, reason: 'a document that failed cannot be accepted');
    });

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('landscape 568 × 320, text ${(scale * 100).round()} %: documents and boxes reachable, nothing overflows', (tester) async {
        await openSignUp(tester, const Size(568, 320), textScale: scale);
        expect(tester.takeException(), isNull);
        for (final key in ['read-TERMS_OF_SERVICE', 'accept-TERMS_OF_SERVICE', 'read-PRIVACY_POLICY', 'accept-PRIVACY_POLICY', 'read-STUDY_PARTICIPATION', 'accept-study', 'decline-study']) {
          await tester.scrollUntilVisible(find.byKey(Key(key)), 200, scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          expect(find.byKey(Key(key)).hitTestable(), findsOneWidget, reason: key);
        }
        expect(tester.takeException(), isNull);
      });
    }

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
