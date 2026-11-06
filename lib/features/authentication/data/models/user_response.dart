class UserResponse {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;

  const UserResponse({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: (json["userId"] as num).toInt(),
      firstName: (json['firstName'] ?? json['fullName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      email: json["email"],
      role: (json['role'] ?? 'USER') as String,
    );
  }
}