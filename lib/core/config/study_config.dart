/// Settings of the study that the app receives at build time
/// (`--dart-define`). None has an invented default: an empty value means
/// "not approved / not available yet" and the app behaves accordingly.
///
/// See `docs/cierre_preproduccion/02_REGISTRO_Y_CONSENTIMIENTOS.md`.
class StudyConfig {
  StudyConfig._();

  /// The backend generates plans only for active study participants
  /// (`User.isEligibleForPlanGeneration`, Backend `generation` 77b9df3).
  /// Set to true only when the backend also prepares plans for people who do
  /// not take part in the study (decision M-01, option B).
  static const plansForNonParticipants = bool.fromEnvironment('PLANS_FOR_NON_PARTICIPANTS');

  /// Approved version of the terms of use, exactly as configured in the
  /// backend (`fitsense.consent.terms-version`). With [termsUrl] it enables
  /// reading and accepting the terms when signing up.
  static const termsVersion = String.fromEnvironment('TERMS_VERSION');

  /// Approved version of the privacy policy (`fitsense.consent.privacy-version`).
  static const privacyVersion = String.fromEnvironment('PRIVACY_VERSION');

  /// Public address of the study's informed consent (plain text or simple
  /// HTML). Shown before the participation box when present.
  static const studyConsentUrl = String.fromEnvironment('STUDY_CONSENT_URL');

  /// Version label of that consent, shown to the participant. It is not sent:
  /// the backend records its own `fitsense.study.consent-version`, and
  /// `acceptedStudyConsentVersion` is not part of the contract yet.
  static const studyConsentVersion = String.fromEnvironment('STUDY_CONSENT_VERSION');

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
