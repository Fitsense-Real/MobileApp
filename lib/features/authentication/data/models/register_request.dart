class RegisterRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String timezone;
  final bool acceptsStudyParticipation;

  /// Versions read and accepted when signing up (`SignUpResource`, V63). Sent
  /// only when this build has an approved document; the backend checks they
  /// are the current ones (422 otherwise).
  final String? acceptedTermsVersion;
  final String? acceptedPrivacyVersion;

  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.timezone = 'America/Lima',
    this.acceptsStudyParticipation = false,
    this.acceptedTermsVersion,
    this.acceptedPrivacyVersion,
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
    };
  }
}