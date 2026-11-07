import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

class PlanRepository {
  PlanRepository(this.dio);
  final Dio dio;

  /// Any plan of the user, including replaced versions.
  Future<Json> byId(Object id) async => jsonMap((await dio.get(ApiConstants.plan(id))).data);

  /// `PlanSummaryResource` list, newest week and version first.
  Future<List<Json>> history() async => jsonRows((await dio.get(ApiConstants.planHistory)).data)
    ..sort((a, b) {
      final week = '${b['weekStartDate']}'.compareTo('${a['weekStartDate']}');
      return week != 0 ? week : ((b['planVersion'] as num?) ?? 0).compareTo((a['planVersion'] as num?) ?? 0);
    });

  /// `PlanLimitationsResource`: what the plan cannot cover with the declared
  /// equipment and restrictions (`{weekStartDate, limitations: [...]}`).
  Future<Json> limitations() async => jsonMap((await dio.get(ApiConstants.planLimitations)).data);

  /// `AdaptationOutcome` per week. `resultado` says whether the plan really
  /// changed; `adjustmentApplied` on the plan is only the decision's name.
  Future<List<Json>> adaptations() async => jsonRows((await dio.get(ApiConstants.planAdaptations)).data);

  Future<Json> generate() async {
    // No body: the backend uses the profile associated with the JWT.
    final cancel = CancelToken();
    const limit = Duration(minutes: 5);
    final response = await dio.post(ApiConstants.generatePlan, cancelToken: cancel, options: Options(receiveTimeout: limit)).timeout(limit, onTimeout: () {
      cancel.cancel('Tiempo de generación agotado');
      throw DioException(requestOptions: RequestOptions(path: ApiConstants.generatePlan), type: DioExceptionType.receiveTimeout, message: 'La generación superó los cinco minutos.');
    });
    return jsonMap(response.data);
  }

  /// Active plan, or null when the backend answers 404 (no plan this week).
  Future<Json?> current() async {
    try {
      final response = await dio.get(ApiConstants.currentPlan);
      if (response.statusCode == 204 || response.data is! Map) return null;
      return jsonMap(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}

final planRepositoryProvider = Provider((ref) => PlanRepository(ref.read(dioProvider)));

// Reset cached plan when the account changes; preserve the generation response
// even when the backend schedules the first plan for the following week.
class GeneratedPlan extends Notifier<Json?> {
  @override
  Json? build() {
    ref.watch(authViewModelProvider.select((auth) => auth.user?.id));
    return null;
  }

  void setPlan(Json plan) => state = plan;
}

final generatedPlanProvider = NotifierProvider<GeneratedPlan, Json?>(GeneratedPlan.new);
final currentPlanProvider = FutureProvider<Json?>((ref) async {
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

final planHistoryProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(planRepositoryProvider).history();
});

final planByIdProvider = FutureProvider.autoDispose.family<Json, int>(
  (ref, id) => ref.watch(planRepositoryProvider).byId(id),
);

final planLimitationsProvider = FutureProvider.autoDispose<Json>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(planRepositoryProvider).limitations();
});

final planAdaptationsProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(planRepositoryProvider).adaptations();
});

/// Adaptation results that mean the published plan actually changed.
const appliedAdaptationResults = {'ADAPTACION_APLICADA', 'REGENERACION_SEGURA_SUSTITUCION'};
