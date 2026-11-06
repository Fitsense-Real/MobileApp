import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';

class WorkoutRepository {
  WorkoutRepository(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> report(Object workoutId, Map<String, dynamic> body) async => Map<String, dynamic>.from((await dio.post('/workouts/$workoutId/report', data: body)).data as Map);
  Future<Map<String, dynamic>?> current() async {
    try {
      final response = await dio.get('/sessions/current');
      if (response.statusCode == 204 || response.data == null) return null;
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
  Future<Map<String, dynamic>> start(Object workoutId) async => Map<String, dynamic>.from((await dio.post('/workouts/$workoutId/start')).data as Map);
  Future<Map<String, dynamic>> record(Object sessionId, Object exerciseId, Map<String, dynamic> body) async => Map<String, dynamic>.from((await dio.put('/sessions/$sessionId/exercises/$exerciseId', data: body)).data as Map);
  Future<Map<String, dynamic>> finish(Object sessionId, Map<String, dynamic> body) async => Map<String, dynamic>.from((await dio.post('/sessions/$sessionId/finish', data: body)).data as Map);
  Future<Map<String, dynamic>> abandon(Object sessionId) async => Map<String, dynamic>.from((await dio.post('/sessions/$sessionId/abandon')).data as Map);
  Future<void> skip(Object workoutId, String reason) async { await dio.post('/workouts/$workoutId/skip', data: {'reason': reason}); }
}
final workoutRepositoryProvider = Provider((ref) => WorkoutRepository(ref.watch(dioProvider)));
