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

  /// Title of the document itself, when the backend sends none.
  String get documentTitle => switch (this) {
        studyParticipation => 'Consentimiento informado del estudio',
        termsOfService => 'Condiciones de uso',
        privacyPolicy => 'Política de privacidad',
      };

  static ConsentType? of(Object? code) => values.where((t) => t.code == '$code').firstOrNull;
}

/// One row of the history the backend keeps (`ConsentimientoResource`).
class ConsentRecord {
  const ConsentRecord({required this.type, required this.version, this.grantedAt, this.affirmativeAction, this.withdrawnAt});
  final ConsentType type;
  final String version;
  final String? grantedAt;

  /// How it was recorded: `CASILLA_REGISTRO`, `BOTON_ACEPTAR`, `CONSTANCIA_DE_LECTURA`,
  /// `CASILLA_SIN_VERSION_CONFIRMADA` or `CASILLA_SIN_DOCUMENTO_APROBADO`.
  final String? affirmativeAction;
  final String? withdrawnAt;

  /// The participation was recorded without an approved informed consent: the
  /// backend keeps the row but it is not valid evidence of informed consent.
  bool get withoutApprovedDocument => affirmativeAction == 'CASILLA_SIN_DOCUMENTO_APROBADO';

  /// The privacy policy was recorded as "informed", not as accepted.
  bool get acknowledgement => affirmativeAction == 'CONSTANCIA_DE_LECTURA';
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
            ConsentRecord(type: type, version: '${row['documentVersion']}', grantedAt: row['grantedAt'] as String?,
                affirmativeAction: row['affirmativeAction'] as String?, withdrawnAt: row['withdrawnAt'] as String?),
      ],
    );
  }

  /// The version of [type] this person accepted and did not withdraw.
  String? acceptedVersion(ConsentType type) => accepted(type)?.version;

  /// The last row of [type] not withdrawn, as the backend has it.
  ConsentRecord? accepted(ConsentType type) => history.where((r) => r.type == type && r.withdrawnAt == null).lastOrNull;

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
