import 'user_response.dart';

class AuthenticationResponse {
  final String token;
  final UserResponse user;

  const AuthenticationResponse({
    required this.token,
    required this.user,
  });

  factory AuthenticationResponse.fromJson(
      Map<String, dynamic> json,
      ) {
    return AuthenticationResponse(
      token: json["token"] as String,
      user: UserResponse.fromJson(json),
    );
  }
}