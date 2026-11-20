import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';

/// Kinds of consent of backend 5977d28 (`ConsentimientoService.Tipo`). They are
/// different authorisations and the app never merges them into one checkbox.
enum ConsentType {
  /// Taking part in the study: chosen at sign-up (`acceptsStudyParticipation`)
  /// and withdrawn with "Retirarme del estudio".
  studyParticipation('STUDY_PARTICIPATION', 'Participación en el estudio'),

  /// Terms of use.
  termsOfService('TERMS_OF_SERVICE', 'Condiciones de uso'),

  /// Acknowledgement of the privacy policy.
  privacyPolicy('PRIVACY_POLICY', 'Política de privacidad');

  const ConsentType(this.code, this.label);
  final String code;
  final String label;

  static ConsentType? of(Object? code) => values.where((t) => t.code == '$code').firstOrNull;
}

class ConsentRecord {
  const ConsentRecord({required this.type, required this.version, this.withdrawnAt});
  final ConsentType type;
  final String version;
  final String? withdrawnAt;
}

/// `GET /api/v1/users/me/consents` (`EstadoResource`).
class ConsentStatus {
  const ConsentStatus({required this.currentVersions, required this.enforcedOnSignup, required this.history});

  /// Current approved version of each document; null while there is none.
  final Map<ConsentType, String?> currentVersions;
  final bool enforcedOnSignup;
  final List<ConsentRecord> history;

  factory ConsentStatus.fromJson(Json json) {
    final versions = json['currentVersions'] is Map ? Map<String, dynamic>.from(json['currentVersions'] as Map) : const <String, dynamic>{};
    return ConsentStatus(
      currentVersions: {for (final t in ConsentType.values) t: versions[t.code] as String?},
      enforcedOnSignup: json['enforcedOnSignup'] == true,
      history: [
        for (final row in jsonRows(json['history']))
          if (ConsentType.of(row['type']) case final type?)
            ConsentRecord(type: type, version: '${row['documentVersion']}', withdrawnAt: row['withdrawnAt'] as String?),
      ],
    );
  }

  /// The version of [type] this person accepted and did not withdraw.
  String? acceptedVersion(ConsentType type) =>
      history.where((r) => r.type == type && r.withdrawnAt == null).map((r) => r.version).lastOrNull;

  /// Terms and privacy with an approved version not accepted yet. Empty while
  /// no document is approved (current state of the study): nothing is asked.
  List<ConsentType> get pendingDocuments => [
        for (final t in [ConsentType.termsOfService, ConsentType.privacyPolicy])
          if (currentVersions[t] != null && acceptedVersion(t) != currentVersions[t]) t,
      ];
}

class ConsentsRepository {
  ConsentsRepository(this._dio);
  final Dio _dio;
  static const path = '/users/me/consents';

  Future<ConsentStatus> status() async => ConsentStatus.fromJson(jsonMap((await _dio.get(path)).data));

  /// `POST /users/me/consents` `{type, documentVersion}`: only the current version.
  Future<void> accept(ConsentType type, String version) => _dio.post(path, data: {'type': type.code, 'documentVersion': version});
}

final consentsRepositoryProvider = Provider((ref) => ConsentsRepository(ref.read(dioProvider)));

final consentStatusProvider = FutureProvider.autoDispose<ConsentStatus>((ref) => ref.read(consentsRepositoryProvider).status());
