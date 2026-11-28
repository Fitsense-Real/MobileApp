/// Settings of the study that the app receives at build time
/// (`--dart-define`). None has an invented default: an empty value means
/// "not approved / not available yet" and the app behaves accordingly.
///
/// See `docs/integracion_final_estudio/03_DOCUMENTOS_Y_CONSENTIMIENTOS.md`.
class StudyConfig {
  StudyConfig._();

  // Option A is decided: Kora is only for participants of the study. There is
  // no switch for plans to non-participants. The legal documents and their
  // versions come from the backend (`GET /legal-documents`), never from the
  // build: a version is sent only if the person read that published document.

  /// Contact approved by the study team (e-mail, phone or both, as one line).
  /// Empty: the app tells the person to contact the team that invited them,
  /// without inventing an address.
  static const contact = String.fromEnvironment('STUDY_CONTACT');

  /// Safety message about pain approved by the study team (M-24), shown when
  /// pain is reported and in Ayuda. Empty: not shown (the app writes no
  /// medical advice of its own).
  static const painSafetyMessage = String.fromEnvironment('PAIN_SAFETY_MESSAGE');

  /// Shows the backend's dropout risk level in Progreso. On by default so the
  /// study intervention does not change without a methodological decision
  /// (M-15); `--dart-define=SHOW_DROPOUT_RISK=false` hides it.
  static const showDropoutRisk = bool.fromEnvironment('SHOW_DROPOUT_RISK', defaultValue: true);

  /// Time zone preselected when signing up (IANA).
  static const defaultTimezone = String.fromEnvironment('DEFAULT_TIMEZONE', defaultValue: 'America/Lima');
}
