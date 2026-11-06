import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../onboarding/data/profile_repository.dart';

typedef Json = Map<String, dynamic>;
List<Json> jsonRows(dynamic value) => (value as List).map((e) => Json.from(e as Map)).toList();

class DashboardRepository {
  DashboardRepository(this.dio);
  final Dio dio;
  Future<List<Json>> metrics() async => jsonRows((await dio.get('/users/me/metrics/weekly')).data)
    ..sort((a, b) => '${b['weekStartDate']}'.compareTo('${a['weekStartDate']}'));
  Future<List<Json>> interventions() async => jsonRows((await dio.get('/users/me/interventions')).data)
    ..sort((a, b) => '${b['appliedAt']}'.compareTo('${a['appliedAt']}'));
  Future<void> runCycle() async => dio.post('/cycle/run-for-me', options: Options(receiveTimeout: const Duration(minutes: 3)));
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
