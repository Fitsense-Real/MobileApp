import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/router/app_routes.dart';
import 'package:fitsense_mobile/features/consents/data/consents_repository.dart';
import 'package:fitsense_mobile/features/consents/presentation/consent_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/consents_fakes.dart';

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

  testWidgets('separate unchecked boxes per document; accepts each current version', (tester) async {
    final stub = ConsentsStub(consentsJson(terms: 'prueba-terminos-1', privacy: 'prueba-privacidad-1'));
    final router = GoRouter(initialLocation: AppRoutes.consents, routes: [
      GoRoute(path: AppRoutes.consents, builder: (_, __) => const ConsentPage()),
      GoRoute(path: AppRoutes.accountSetup, builder: (_, __) => const Scaffold(body: Text('Preparando cuenta'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [consentsRepositoryProvider.overrideWithValue(stub)],
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light)));
    await tester.pumpAndSettle();
    final boxes = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(boxes, hasLength(2), reason: 'terms and privacy are two different authorisations');
    expect(boxes.every((b) => b.value == false), isTrue, reason: 'never pre-checked');
    expect(find.text('Versión prueba-terminos-1'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.tap(find.text('Acepto las condiciones de uso'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull, reason: 'both are needed');
    await tester.tap(find.text('He leído la política de privacidad'));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(stub.accepted, ['TERMS_OF_SERVICE=prueba-terminos-1', 'PRIVACY_POLICY=prueba-privacidad-1']);
    expect(find.text('Preparando cuenta'), findsOneWidget);
  });
}
