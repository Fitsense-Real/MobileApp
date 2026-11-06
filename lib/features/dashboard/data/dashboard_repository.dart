import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../onboarding/data/profile_repository.dart';

export '../../../core/api/json.dart';

class DashboardRepository {
  DashboardRepository(this.dio);
  final Dio dio;

  /// `WeeklyMetricsResource` history, newest week first.
  Future<List<Json>> metrics() async => jsonRows((await dio.get(ApiConstants.weeklyMetrics)).data)
    ..sort((a, b) => '${b['weekStartDate']}'.compareTo('${a['weekStartDate']}'));

  /// `InterventionResource` history, newest adjustment first.
  Future<List<Json>> interventions() async => jsonRows((await dio.get(ApiConstants.interventions)).data)
    ..sort((a, b) => '${b['appliedAt']}'.compareTo('${a['appliedAt']}'));

  /// Closes last week, computes metrics and generates the new plan.
  /// Returns `{measuredWeekStart, newWeekStart, generatedPlanId}`.
  Future<Json> runCycle() async {
    final response = await dio.post(ApiConstants.runCycle, options: Options(receiveTimeout: const Duration(minutes: 3)));
    return response.data is Map ? jsonMap(response.data) : <String, dynamic>{};
  }
}

final dashboardRepositoryProvider = Provider((ref) => DashboardRepository(ref.watch(dioProvider)));
final weeklyMetricsProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(dashboardRepositoryProvider).metrics();
});
final interventionsProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(dashboardRepositoryProvider).interventions();
});
final dashboardProfileProvider = FutureProvider.autoDispose<Json?>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(profileRepositoryProvider).fetch();
});
