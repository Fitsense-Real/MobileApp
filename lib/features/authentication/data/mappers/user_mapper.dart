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
      timezone: response.timezone,
      status: response.status,
      studyParticipant: response.studyParticipant,
      participantCode: response.participantCode,
      enrolledAt: response.enrolledAt,
      withdrawnAt: response.withdrawnAt,
    );
  }
}
