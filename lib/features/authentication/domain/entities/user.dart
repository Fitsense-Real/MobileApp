class User {
  final int id;

  final String firstName;

  final String lastName;

  final String email;

  final String role;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });

  String get fullName => "$firstName $lastName";
}