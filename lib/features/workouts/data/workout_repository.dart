import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';

/// Execution endpoints. Every write returns the `WorkoutSessionResource`.
class WorkoutRepository {
  WorkoutRepository(this.dio);
  final Dio dio;

  /// Session in progress, or null (the backend answers 204 when none).
  Future<Json?> current() async {
    try {
      final response = await dio.get(ApiConstants.currentSession);
      if (response.statusCode == 204 || response.data is! Map) return null;
      return jsonMap(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Json> byId(Object sessionId) async => jsonMap((await dio.get(ApiConstants.session(sessionId))).data);
  Future<Json> start(Object workoutId) async => jsonMap((await dio.post(ApiConstants.startWorkout(workoutId))).data);

  /// PUT replaces the previous result for that exercise; it never accumulates.
  Future<Json> record(Object sessionId, Object plannedExerciseId, Json body) async =>
      jsonMap((await dio.put(ApiConstants.sessionExercise(sessionId, plannedExerciseId), data: body)).data);

  /// Body: `{sessionRpe (1–10, required), satisfaction?, activeMinutes?}`.
  Future<Json> finish(Object sessionId, Json body) async =>
      jsonMap((await dio.post(ApiConstants.finishSession(sessionId), data: body)).data);
  Future<Json> abandon(Object sessionId) async => jsonMap((await dio.post(ApiConstants.abandonSession(sessionId))).data);

  /// Retroactive report: `{performedAt, sessionRpe, satisfaction?, activeMinutes?, exercises: [...]}`.
  Future<Json> report(Object workoutId, Json body) async =>
      jsonMap((await dio.post(ApiConstants.reportWorkout(workoutId), data: body)).data);

  /// The backend answers 204; reason is a `SkipReason` code. With
  /// LACK_OF_TIME, `lackOfTimeContext` (IMPREVISTO, SIN_TIEMPO_ESE_DIA,
  /// MENOS_TIEMPO_HABITUAL) and `availableMinutes` (15–180, required with
  /// MENOS_TIEMPO_HABITUAL) are optional.
  Future<void> skip(Object workoutId, String reason, {String? lackOfTimeContext, int? availableMinutes}) async {
    await dio.post(ApiConstants.skipWorkout(workoutId), data: {
      'reason': reason,
      if (lackOfTimeContext != null) 'lackOfTimeContext': lackOfTimeContext,
      if (availableMinutes != null) 'availableMinutes': availableMinutes,
    });
  }
}

final workoutRepositoryProvider = Provider((ref) => WorkoutRepository(ref.watch(dioProvider)));
