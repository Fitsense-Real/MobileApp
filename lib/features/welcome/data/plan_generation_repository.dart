import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';
import '../domain/generation_operation.dart';

/// Asynchronous first-plan generation (backend V58).
class PlanGenerationRepository {
  PlanGenerationRepository(this.dio);
  final Dio dio;

  static const path = '/users/me/plan/generation';

  /// Idempotent: returns the active operation, or a COMPLETED one if the
  /// plan already exists, instead of starting a second generation.
  Future<GenerationOperation> start() async => GenerationOperation.fromJson(jsonMap((await dio.post(path)).data));

  /// Null when the operation does not exist or belongs to someone else (404).
  Future<GenerationOperation?> find(String operationId) async {
    try {
      return GenerationOperation.fromJson(jsonMap((await dio.get('$path/$operationId')).data));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

final planGenerationRepositoryProvider = Provider((ref) => PlanGenerationRepository(ref.watch(dioProvider)));
