import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/consents_repository.dart';

/// A legal document published by the backend (`GET /api/v1/legal-documents`,
/// `LegalDocumentsController.DocumentoResource` of Backend `generation`
/// 41c498a): only documents `PUBLISHED`, with an approval reference and already
/// in force are listed. [version] is exactly what sign-up sends back.
class LegalDocument {
  const LegalDocument({required this.type, required this.title, required this.url, required this.version, this.effectiveFrom});
  final ConsentType type;
  final String title;
  final String url;
  final String version;
  final String? effectiveFrom;

  bool get readable => url.trim().isNotEmpty;

  static LegalDocument? fromJson(Json json) {
    final type = ConsentType.of(json['type']);
    final version = '${json['version'] ?? ''}'.trim();
    final url = '${json['url'] ?? ''}'.trim();
    // Only what the backend says is published and approved; anything else is ignored.
    if (type == null || version.isEmpty || url.isEmpty || (json['status'] != null && json['status'] != 'PUBLISHED')) return null;
    final title = '${json['title'] ?? ''}'.trim();
    return LegalDocument(type: type, title: title.isEmpty ? type.documentTitle : title, url: url, version: version, effectiveFrom: json['effectiveFrom'] as String?);
  }

  @override
  bool operator ==(Object other) => other is LegalDocument && other.type == type && other.url == url && other.version == version;

  @override
  int get hashCode => Object.hash(type, url, version);
}

/// How the backend records the privacy policy (`fitsense.consent.privacy-record`):
/// an acceptance, or a record that the person was informed.
enum PrivacyRecord { acceptance, acknowledgement }

/// `GET /api/v1/legal-documents` (`DocumentosResource`): public, no JWT.
class PublishedDocuments {
  const PublishedDocuments({this.enforcedOnSignup = false, this.privacyRecord = PrivacyRecord.acceptance, this.documents = const []});

  /// Whether the backend requires the documents at sign-up (`enforce-on-signup`).
  final bool enforcedOnSignup;
  final PrivacyRecord privacyRecord;
  final List<LegalDocument> documents;

  factory PublishedDocuments.fromJson(Json json) => PublishedDocuments(
        enforcedOnSignup: json['enforcedOnSignup'] == true,
        privacyRecord: json['privacyRecord'] == 'CONSTANCIA' ? PrivacyRecord.acknowledgement : PrivacyRecord.acceptance,
        documents: [for (final row in jsonRows(json['documents'])) ?LegalDocument.fromJson(row)],
      );

  LegalDocument? of(ConsentType type) => documents.where((d) => d.type == type).firstOrNull;
  LegalDocument? get terms => of(ConsentType.termsOfService);
  LegalDocument? get privacy => of(ConsentType.privacyPolicy);
  LegalDocument? get studyConsent => of(ConsentType.studyParticipation);

  /// The documents the definitive sign-up requires (the backend's
  /// `enforce-on-signup`): terms, privacy policy and the informed consent.
  static const required = [ConsentType.termsOfService, ConsentType.privacyPolicy, ConsentType.studyParticipation];

  /// Required documents the backend does not publish (yet).
  List<ConsentType> get missing => [for (final t in required) if (of(t) == null) t];

  /// Option A (Kora is only for participants of the study): an account can be
  /// created only with a valid acceptance of the three documents. Without the
  /// informed consent the backend would record the participation as
  /// `CASILLA_SIN_DOCUMENTO_APROBADO`, which is not valid evidence; without terms
  /// or privacy the definitive sign-up cannot be satisfied. Missing any of them,
  /// sign-up stays closed.
  bool get signUpOpen => missing.isEmpty;

  /// Every published document, in the order they are read at sign-up.
  List<LegalDocument> get toRead => [?terms, ?privacy, ?studyConsent];

  /// The published document of [type] whose version is [version], to read
  /// again what was accepted (Perfil). Null when it is no longer published.
  LegalDocument? find(ConsentType type, String version) => documents.where((d) => d.type == type && d.version == version).firstOrNull;

  /// True when [shown] (what the person read) is no longer exactly what is published.
  bool changedSince(List<LegalDocument> shown) {
    String key(LegalDocument d) => '${d.type.code}:${d.version}';
    return {for (final d in shown) key(d)}.difference({for (final d in documents) key(d)}).isNotEmpty ||
        {for (final d in toRead) key(d)}.difference({for (final d in shown) key(d)}).isNotEmpty;
  }
}

class LegalDocumentsRepository {
  LegalDocumentsRepository(this._dio);
  final Dio _dio;
  static const path = ApiConstants.legalDocuments;

  Future<PublishedDocuments> current() async => PublishedDocuments.fromJson(jsonMap((await _dio.get(path)).data));
}

final legalDocumentsRepositoryProvider = Provider((ref) => LegalDocumentsRepository(ref.read(dioProvider)));

/// What is published now. Re-read on every sign-up and before sending it.
/// No automatic retry: without connection the sign-up says so and offers «Reintentar».
final publishedDocumentsProvider = FutureProvider.autoDispose<PublishedDocuments>(
  (ref) => ref.read(legalDocumentsRepositoryProvider).current(),
  retry: (_, _) => null,
);

/// Stable codes of the consent contract (`ConsentimientoRechazadoException`,
/// Backend PR #96) in `details[0]` of the 422.
const documentRejectionCodes = {'CONSENTIMIENTO_REQUERIDO', 'PARTICIPACION_REQUERIDA', 'DOCUMENTO_NO_PUBLICADO', 'VERSION_NO_VIGENTE', 'VERSION_SIN_PARTICIPACION'};

/// The backend's 422 when an accepted version is not the current one
/// (`VERSION_NO_VIGENTE`; text "La version aceptada de X no es la vigente (v)").
bool isOutdatedDocument(Object? message, {String? code}) => code == 'VERSION_NO_VIGENTE' || '$message'.contains('no es la vigente');

/// The backend's 422 when no version of a document is approved yet (`DOCUMENTO_NO_PUBLICADO`).
bool isUnpublishedDocument(Object? message, {String? code}) =>
    code == 'DOCUMENTO_NO_PUBLICADO' || '$message'.toLowerCase().contains('no hay una version aprobada');

/// The backend's 422 when it requires a document the app did not send
/// (`CONSENTIMIENTO_REQUERIDO`; "Para registrarte tienes que aceptar…").
bool isMissingDocument(Object? message, {String? code}) => code == 'CONSENTIMIENTO_REQUERIDO' || '$message'.contains('tienes que aceptar');

/// Any 422 of the sign-up about documents: the account was not created and the
/// documents have to be read again as they are published now. The code decides
/// when the backend sends one (PR #96); the text is the fallback for older ones.
bool isDocumentProblem(Object? message, {String? code}) =>
    (code != null && documentRejectionCodes.contains(code)) ||
    isOutdatedDocument(message) || isUnpublishedDocument(message) || isMissingDocument(message);
