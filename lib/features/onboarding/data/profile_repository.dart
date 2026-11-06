import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';

class Equipment {
  const Equipment(this.code, this.name, this.requiresGym);
  final String code, name;
  final bool requiresGym;
  bool get selectedForGym => requiresGym || const {
    'dumbbell', 'band', 'rope', 'other', 'bench', 'pull-up bar',
    'suspension straps', 'step platform', 'stationary bike', 'treadmill',
  }.contains(code.toLowerCase().trim());
  factory Equipment.fromJson(Json json) => Equipment(json['code'] as String, json['nameEs'] as String, json['requiresGym'] == true);
}

/// Fields accepted by `CreateUserProfileResource`. Anything else is silently
/// ignored by the backend, so it is never sent.
const createProfileFields = {
  'birthDate', 'biologicalSex', 'heightCm', 'currentWeightKg', 'targetWeightKg',
  'fitnessLevel', 'goalType', 'goalText', 'trainingLocation', 'daysPerWeek',
  'availableDays', 'sessionMinutes', 'equipmentCodes', 'blockedExerciseIds', 'healthNotes',
};

/// `UpdateUserProfileResource`: same as create except the birth date, which
/// cannot change after creation.
final updateProfileFields = {...createProfileFields}..remove('birthDate');

class ProfileRepository {
  ProfileRepository(this.dio);
  final Dio dio;

  /// `UserProfileResource`, or null when the user has no profile yet (404).
  Future<Json?> fetch() async {
    try {
      final response = await dio.get(ApiConstants.profile);
      return jsonMap(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Equipment>> equipment() async {
    final response = await dio.get(ApiConstants.equipment);
    return jsonRows(response.data).map(Equipment.fromJson).toList();
  }

  /// POST creates (once per user); PUT updates and applies from next Monday.
  Future<Json?> save(Json body, {required bool exists}) async {
    final allowed = exists ? updateProfileFields : createProfileFields;
    final payload = {for (final e in body.entries) if (allowed.contains(e.key)) e.key: e.value};
    final response = exists
        ? await dio.put(ApiConstants.profile, data: payload)
        : await dio.post(ApiConstants.profile, data: payload);
    return response.data is Map ? jsonMap(response.data) : null;
  }
}

final profileRepositoryProvider = Provider((ref) => ProfileRepository(ref.read(dioProvider)));
