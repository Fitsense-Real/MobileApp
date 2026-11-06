import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class PlanRepository {
  PlanRepository(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> byId(Object id) async => Map<String, dynamic>.from((await dio.get('/users/me/plan/$id')).data as Map);
  Future<Map<String, dynamic>> generate() async {
    // No body: the backend uses the profile associated with the JWT.
    final cancel = CancelToken();
    const limit = Duration(minutes: 5);
    final response = await dio.post('/users/me/plan/generate', cancelToken: cancel, options: Options(receiveTimeout: limit)).timeout(limit, onTimeout: () {
      cancel.cancel('Tiempo de generación agotado');
      throw DioException(requestOptions: RequestOptions(path: '/users/me/plan/generate'), type: DioExceptionType.receiveTimeout, message: 'La generación superó los cinco minutos.');
    });
    return Map<String, dynamic>.from(response.data as Map);
  }
  Future<Map<String, dynamic>?> current() async {
    try {
      final response = await dio.get('/users/me/plan/current');
      if (response.statusCode == 204 || response.data == null) return null;
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
final planRepositoryProvider = Provider((ref) => PlanRepository(ref.read(dioProvider)));
// Reset cached plan when the account changes; preserve the generation response
// even when the backend schedules the first plan for the following week.
class GeneratedPlan extends Notifier<Map<String, dynamic>?> {
  @override
  Map<String, dynamic>? build() {
    ref.watch(authViewModelProvider.select((auth) => auth.user?.id));
    return null;
  }
  void setPlan(Map<String, dynamic> plan) => state = plan;
}
final generatedPlanProvider = NotifierProvider<GeneratedPlan, Map<String, dynamic>?>(GeneratedPlan.new);
final currentPlanProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(authViewModelProvider);
  final generated = ref.watch(generatedPlanProvider);
  if (!auth.isAuthenticated) return null;
  final repository = ref.watch(planRepositoryProvider);
  final current = await repository.current();
  if (current != null) return current;
  // A freshly generated plan may start next week. Reload it by ID so workout
  // statuses never remain frozen at the original generation response.
  if (generated?['planId'] != null) return repository.byId(generated!['planId']);
  return null;
});
