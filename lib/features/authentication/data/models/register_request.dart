class RegisterRequest {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String timezone;
  final bool acceptsStudyParticipation;

  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    this.timezone = 'America/Lima',
    this.acceptsStudyParticipation = false,
  });

  Map<String, dynamic> toJson() {
    return {
      "firstName": firstName,
      "lastName": lastName,
      "email": email,
      "password": password,
      "timezone": timezone,
      "acceptsStudyParticipation": acceptsStudyParticipation,
    };
  }
}