import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_links.dart';
import '../../../core/config/study_config.dart';
import '../data/consents_repository.dart';

/// A document the person can read in the app before accepting it.
///
/// [version] is what the backend records (terms and privacy). The study
/// consent has a displayed version only: the backend stores its own.
class LegalDocument {
  const LegalDocument({required this.type, required this.title, required this.url, required this.version});
  final ConsentType type;
  final String title;
  final String url;
  final String version;

  bool get readable => url.trim().isNotEmpty;

  @override
  bool operator ==(Object other) => other is LegalDocument && other.type == type && other.url == url && other.version == version;

  @override
  int get hashCode => Object.hash(type, url, version);
}

/// Documents of the sign-up, from the build configuration. A document appears
/// only when its address **and** its approved version are configured: nothing
/// is shown, and nothing is sent, while a document is not approved.
class SignUpDocuments {
  const SignUpDocuments({this.terms, this.privacy, this.studyConsent});

  final LegalDocument? terms;
  final LegalDocument? privacy;
  final LegalDocument? studyConsent;

  static LegalDocument? _of(ConsentType type, String title, String url, String version) =>
      url.trim().isEmpty || version.trim().isEmpty ? null : LegalDocument(type: type, title: title, url: url.trim(), version: version.trim());

  factory SignUpDocuments.fromConfig({
    String termsUrl = AppLinks.termsUrl,
    String termsVersion = StudyConfig.termsVersion,
    String privacyUrl = AppLinks.privacyPolicyUrl,
    String privacyVersion = StudyConfig.privacyVersion,
    String studyConsentUrl = StudyConfig.studyConsentUrl,
    String studyConsentVersion = StudyConfig.studyConsentVersion,
  }) => SignUpDocuments(
        terms: _of(ConsentType.termsOfService, 'Condiciones de uso', termsUrl, termsVersion),
        privacy: _of(ConsentType.privacyPolicy, 'Política de privacidad', privacyUrl, privacyVersion),
        studyConsent: studyConsentUrl.trim().isEmpty
            ? null
            : LegalDocument(type: ConsentType.studyParticipation, title: 'Consentimiento informado del estudio', url: studyConsentUrl.trim(),
                version: studyConsentVersion.trim().isEmpty ? 'sin versión indicada' : studyConsentVersion.trim()),
      );

  /// Terms and privacy that must be accepted to create the account.
  List<LegalDocument> get required => [?terms, ?privacy];

  /// Address of the document of [type] whose version is [version], to read
  /// again what was accepted (Perfil). Null when this build does not have it.
  String? urlFor(ConsentType type, String version) {
    final doc = switch (type) {
      ConsentType.termsOfService => terms,
      ConsentType.privacyPolicy => privacy,
      ConsentType.studyParticipation => studyConsent,
    };
    if (doc == null) return null;
    if (type != ConsentType.studyParticipation && doc.version != version) return null;
    return doc.url;
  }
}

/// The backend's 422 when an accepted version is not the current one
/// (`ConsentimientoService.vigente`): "La version aceptada de X no es la vigente (v)".
bool isOutdatedDocument(Object? message) => '$message'.contains('no es la vigente');

/// The backend's 422 when no version of a document is approved yet.
bool isUnpublishedDocument(Object? message) => '$message'.contains('no hay una version aprobada');

/// Public address of each document in this build (empty: not available).
/// Overridable in tests.
final legalDocumentUrlsProvider = Provider<Map<ConsentType, String>>((ref) => {
      ConsentType.termsOfService: AppLinks.termsUrl,
      ConsentType.privacyPolicy: AppLinks.privacyPolicyUrl,
      ConsentType.studyParticipation: StudyConfig.studyConsentUrl,
    });
