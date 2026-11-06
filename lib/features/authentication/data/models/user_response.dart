/// `UserResource` (register, /users/me, /users/me/withdraw) and the user part
/// of `AuthenticatedUserResource` (login: userId, email, fullName, token).
class UserResponse {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? timezone;
  final String? status;
  final bool studyParticipant;
  final String? participantCode;
  final DateTime? enrolledAt;
  final DateTime? withdrawnAt;

  const UserResponse({
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

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    DateTime? date(Object? value) => value == null ? null : DateTime.tryParse('$value');
    return UserResponse(
      id: (json['userId'] as num).toInt(),
      firstName: (json['firstName'] ?? json['fullName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      email: json['email'] as String,
      timezone: json['timezone'] as String?,
      status: json['status'] as String?,
      studyParticipant: json['studyParticipant'] == true,
      participantCode: json['participantCode'] as String?,
      enrolledAt: date(json['enrolledAt']),
      withdrawnAt: date(json['withdrawnAt']),
    );
  }
}
