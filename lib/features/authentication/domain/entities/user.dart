/// Account of the authenticated user (`UserResource` in the backend).
class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? timezone;

  /// ACTIVE, WITHDRAWN… as sent by the backend.
  final String? status;
  final bool studyParticipant;
  final String? participantCode;
  final DateTime? enrolledAt;
  final DateTime? withdrawnAt;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.timezone,
    this.status,
    this.studyParticipant = false,
    this.participantCode,
    this.enrolledAt,
    this.withdrawnAt,
  });

  String get fullName => [firstName, lastName].where((s) => s.trim().isNotEmpty).join(' ');

  /// Enrolled and not withdrawn: the only state where withdrawal makes sense.
  bool get canWithdraw => studyParticipant && withdrawnAt == null;
}
