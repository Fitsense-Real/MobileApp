import '../../domain/entities/user.dart';
import '../models/user_response.dart';

class UserMapper {
  UserMapper._();

  static User toEntity(UserResponse response) {
    return User(
      id: response.id,
      firstName: response.firstName,
      lastName: response.lastName,
      email: response.email,
      role: response.role,
    );
  }
}