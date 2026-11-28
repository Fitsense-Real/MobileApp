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
  Future<String> fetch(String url) async => 'Texto sintético de prueba ($url). No es un documento aprobado.';
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

  Future<ConsentsStub> openPage(WidgetTester tester, {PublishedDocuments documents = published}) async {
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
      documentTextRepositoryProvider.overrideWithValue(_Texts()),
    ], child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)));
    await tester.pumpAndSettle();
    return stub;
  }

  Future<void> read(WidgetTester tester) async {
    await tester.tap(find.text('Leer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('He leído el documento'));
    await tester.pumpAndSettle();
  }

  testWidgets('separate unchecked boxes per document, each enabled only after reading it; accepts each current version', (tester) async {
    final stub = await openPage(tester);
    final boxes = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(boxes, hasLength(2), reason: 'terms and privacy are two different authorisations');
    expect(boxes.every((b) => b.value == false), isTrue, reason: 'never pre-checked');
    expect(boxes.every((b) => b.onChanged == null), isTrue, reason: 'nothing can be accepted unread');
    expect(find.text('Política de privacidad · versión prueba-privacidad-1'), findsOneWidget);
    await read(tester);
    await tester.tap(find.text('Acepto las condiciones de uso'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull, reason: 'both are needed');
    await read(tester);
    await tester.tap(find.text('Acepto la política de privacidad'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(stub.accepted, ['TERMS_OF_SERVICE=prueba-terminos-1', 'PRIVACY_POLICY=prueba-privacidad-1']);
    expect(find.text('Preparando cuenta'), findsOneWidget);
  });

  testWidgets('privacy recorded as CONSTANCIA: the box says «He leído», not «Acepto»', (tester) async {
    await openPage(tester, documents: PublishedDocuments(privacyRecord: PrivacyRecord.acknowledgement, documents: published.documents));
    expect(find.text('He leído la política de privacidad'), findsOneWidget);
    expect(find.text('Acepto la política de privacidad'), findsNothing);
  });

  testWidgets('a version the backend does not publish as a document cannot be accepted: it says so', (tester) async {
    final stub = await openPage(tester, documents: const PublishedDocuments());
    expect(find.text('Leer'), findsNothing);
    expect(find.textContaining('no está publicado para leerlo en la app'), findsNWidgets(2));
    expect(tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).every((b) => b.onChanged == null), isTrue);
    expect(stub.accepted, isEmpty);
  });
}
