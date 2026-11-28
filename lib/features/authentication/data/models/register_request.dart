class RegisterRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String timezone;
  final bool acceptsStudyParticipation;

  /// Versions read and accepted when signing up (`SignUpResource`). Each one is
  /// the version of the document the person read, as `GET /legal-documents`
  /// published it; sent only when that document is published. The backend
  /// checks they are the current ones (422 otherwise).
  final String? acceptedTermsVersion;
  final String? acceptedPrivacyVersion;

  /// Version of the informed consent of the study that was read (B2.1). Only
  /// with [acceptsStudyParticipation]; mandatory once the backend enforces it.
  final String? acceptedStudyConsentVersion;

  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.timezone = 'America/Lima',
    this.acceptsStudyParticipation = false,
    this.acceptedTermsVersion,
    this.acceptedPrivacyVersion,
    this.acceptedStudyConsentVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
      "password": password,
      "timezone": timezone,
      "acceptsStudyParticipation": acceptsStudyParticipation,
      if (acceptedTermsVersion != null) "acceptedTermsVersion": acceptedTermsVersion,
      if (acceptedPrivacyVersion != null) "acceptedPrivacyVersion": acceptedPrivacyVersion,
      if (acceptedStudyConsentVersion != null) "acceptedStudyConsentVersion": acceptedStudyConsentVersion,
    };
  }
}