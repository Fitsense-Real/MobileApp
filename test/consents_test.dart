import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/features/consents/data/consents_repository.dart';
import 'package:fitsense_mobile/features/consents/presentation/consent_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'package:fitsense_mobile/features/consents/data/document_text_repository.dart';
import 'package:fitsense_mobile/features/consents/domain/legal_documents.dart';
import 'package:dio/dio.dart';
import 'support/consents_fakes.dart';

class _Texts extends DocumentTextRepository {
  _Texts() : super(Dio());
  @override
  Future<String> fetchRaw(String url) async => 'Texto sintético de prueba ($url). No es un documento aprobado.';
}

/// The privacy policy cannot be shown (for example, its address is broken).
class _Broken extends _Texts {
  @override
  Future<String> fetchRaw(String url) async => url.contains('privacidad') ? throw const FormatException('El documento está vacío.') : super.fetchRaw(url);
}

void main() {
  group('ConsentStatus (EstadoResource of backend 5977d28)', () {
    test('real answer today: study participation accepted, no approved terms or privacy', () {
      final status = ConsentStatus.fromJson(consentsJson());
      expect(status.currentVersions[ConsentType.studyParticipation], 'MVP-1.0');
      expect(status.currentVersions[ConsentType.termsOfService], isNull);
      expect(status.currentVersions[ConsentType.privacyPolicy], isNull);
      expect(status.enforcedOnSignup, isFalse);
      expect(status.acceptedVersion(ConsentType.studyParticipation), 'MVP-1.0');
      expect(status.pendingDocuments, isEmpty, reason: 'nothing approved: nothing is asked');
    });
    test('published versions are pending until this exact version is accepted', () {
      expect(ConsentStatus.fromJson(consentsJson(terms: 't-2', privacy: 'p-1')).pendingDocuments, [ConsentType.termsOfService, ConsentType.privacyPolicy]);
      final acceptedOld = ConsentStatus.fromJson(consentsJson(terms: 't-2', extraHistory: [
        {'type': 'TERMS_OF_SERVICE', 'documentVersion': 't-1', 'withdrawnAt': null},
      ]));
      expect(acceptedOld.pendingDocuments, [ConsentType.termsOfService], reason: 'a new version must be accepted again');
      final acceptedCurrent = ConsentStatus.fromJson(consentsJson(terms: 't-2', extraHistory: [
        {'type': 'TERMS_OF_SERVICE', 'documentVersion': 't-2', 'withdrawnAt': null},
      ]));
      expect(acceptedCurrent.pendingDocuments, isEmpty);
    });
    test('study participation is never asked here: it is chosen at sign-up and withdrawn apart', () {
      final status = ConsentStatus.fromJson(consentsJson()..['currentVersions'] = {'STUDY_PARTICIPATION': 'MVP-2.0'});
      expect(status.pendingDocuments, isEmpty);
    });
  });

  const published = PublishedDocuments(documents: [
    LegalDocument(type: ConsentType.termsOfService, title: 'Condiciones de uso', url: 'https://docs.test/terminos', version: 'prueba-terminos-1'),
    LegalDocument(type: ConsentType.privacyPolicy, title: 'Política de privacidad', url: 'https://docs.test/privacidad', version: 'prueba-privacidad-1'),
  ]);

  Future<ConsentsStub> openPage(WidgetTester tester, {PublishedDocuments documents = published, DocumentTextRepository? texts}) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final stub = ConsentsStub(consentsJson(terms: 'prueba-terminos-1', privacy: 'prueba-privacidad-1'));
    final router = GoRouter(initialLocation: AppRoutes.consents, routes: [
      GoRoute(path: AppRoutes.consents, builder: (_, __) => const ConsentPage()),
      GoRoute(path: AppRoutes.accountSetup, builder: (_, __) => const Scaffold(body: Text('Preparando cuenta'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      consentsRepositoryProvider.overrideWithValue(stub),
      publishedDocumentsProvider.overrideWith((ref) async => documents),
      documentTextRepositoryProvider.overrideWithValue(texts ?? _Texts()),
    ], child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)));
    await tester.pumpAndSettle();
    return stub;
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

  Checkbox box(WidgetTester tester, String type) => tester.widget<Checkbox>(find.byKey(Key('accept-$type')));

  testWidgets('separate unchecked boxes; the name opens the document without ticking it; accepts each current version', (tester) async {
    final stub = await openPage(tester);
    expect(find.byType(Checkbox), findsNWidgets(2), reason: 'terms and privacy are two different authorisations');
    for (final type in ['TERMS_OF_SERVICE', 'PRIVACY_POLICY']) {
      expect(box(tester, type).value, isFalse, reason: 'never pre-checked');
    }
    expect(find.textContaining('(versión prueba-privacidad-1)', findRichText: true), findsOneWidget);
    await openDoc(tester, 'TERMS_OF_SERVICE');
    expect(find.descendant(of: find.byType(ListView), matching: find.text('Términos y condiciones')), findsOneWidget, reason: 'title');
    expect(find.text('Versión prueba-terminos-1'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver').last);
    await tester.pumpAndSettle();
    expect(box(tester, 'TERMS_OF_SERVICE').value, isFalse, reason: 'opening is not accepting');
    await tester.tap(find.byKey(const Key('accept-TERMS_OF_SERVICE')));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull, reason: 'both are needed');
    await tester.tap(find.byKey(const Key('accept-PRIVACY_POLICY')));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(stub.accepted, ['TERMS_OF_SERVICE=prueba-terminos-1', 'PRIVACY_POLICY=prueba-privacidad-1']);
    expect(find.text('Preparando cuenta'), findsOneWidget);
  });

  testWidgets('privacy recorded as CONSTANCIA: the box says «He leído», not «Acepto»', (tester) async {
    await openPage(tester, documents: PublishedDocuments(privacyRecord: PrivacyRecord.acknowledgement, documents: published.documents));
    expect(find.textContaining('He leído la Política de privacidad', findRichText: true), findsOneWidget);
    expect(find.textContaining('Acepto la Política de privacidad', findRichText: true), findsNothing);
  });

  testWidgets('a document that cannot be shown cannot be accepted', (tester) async {
    await openPage(tester, texts: _Broken());
    await tester.tap(find.byKey(const Key('accept-PRIVACY_POLICY')));
    await tester.pump();
    await openDoc(tester, 'PRIVACY_POLICY');
    expect(find.textContaining('No se pudo abrir el documento'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver').last);
    await tester.pumpAndSettle();
    expect(box(tester, 'PRIVACY_POLICY').value, isFalse);
    expect(box(tester, 'PRIVACY_POLICY').onChanged, isNull);
    expect(box(tester, 'TERMS_OF_SERVICE').onChanged, isNotNull);
  });

  testWidgets('a version the backend does not publish as a document cannot be accepted: it says so', (tester) async {
    final stub = await openPage(tester, documents: const PublishedDocuments());
    expect(find.textContaining('no está publicado para leerlo en la app'), findsNWidgets(2));
    expect(tester.widgetList<Checkbox>(find.byType(Checkbox)).every((b) => b.onChanged == null), isTrue);
    expect(stub.accepted, isEmpty);
  });
}
