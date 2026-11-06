import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';

/// Read-only exercise catalog (`CatalogController`).
class CatalogRepository {
  CatalogRepository(this.dio);
  final Dio dio;

  /// `ExerciseSummaryResource` list of the active catalog. Null filters do
  /// not restrict; `search` matches the Spanish name.
  Future<List<Json>> exercises({String? search, String? bodyPart, String? equipment, int? maxDifficulty, int limit = 30}) async {
    final response = await dio.get(ApiConstants.exercises, queryParameters: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (bodyPart != null) 'bodyPart': bodyPart,
      if (equipment != null) 'equipment': equipment,
      if (maxDifficulty != null) 'maxDifficulty': maxDifficulty,
      'limit': limit,
    });
    return jsonRows(response.data);
  }

  /// `ExerciseDetailResource`: instructions, muscles and media.
  Future<Json> exercise(Object id) async => jsonMap((await dio.get(ApiConstants.exercise(id))).data);
}

final catalogRepositoryProvider = Provider((ref) => CatalogRepository(ref.watch(dioProvider)));

final exerciseDetailProvider = FutureProvider.autoDispose.family<Json, int>(
  (ref, id) => ref.watch(catalogRepositoryProvider).exercise(id),
);
