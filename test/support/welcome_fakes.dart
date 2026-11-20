import 'package:dio/dio.dart';
import 'package:fitsense_mobile/features/authentication/domain/entities/user.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/domain/generation_operation.dart';

const operationId = '5b0c2f7e-0000-4000-8000-000000000001';

GenerationOperation operation(String status, {String id = operationId, int? planId, String? reason, String? message, bool retryable = false}) =>
    GenerationOperation.fromJson({
      'operationId': id,
      'status': status,
      'planId': planId,
      'reasonCode': reason,
      'message': message,
      'retryable': retryable,
      'pollAfterSeconds': const {'PENDING', 'PROCESSING'}.contains(status) ? 3 : null,
    });

DioException httpError(int status, [String message = 'Rechazada']) {
  final options = RequestOptions(path: PlanGenerationRepository.path);
  return DioException(requestOptions: options, type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: status, data: {'status': status, 'message': message, 'details': []}));
}

DioException offline() => DioException(requestOptions: RequestOptions(path: PlanGenerationRepository.path), type: DioExceptionType.connectionError);

/// Scripted backend for the asynchronous generation: each call to [start] or
/// [find] takes the next answer (an operation or an error) from its queue;
/// when a queue runs out, the last answer repeats.
class FakeGeneration extends PlanGenerationRepository {
  FakeGeneration({List<Object>? starts, List<Object?>? finds})
      : starts = starts ?? [operation('PENDING')],
        finds = finds ?? [operation('PROCESSING')],
        super(Dio());
  final List<Object> starts;
  final List<Object?> finds;
  int startCalls = 0, findCalls = 0;
  final foundIds = <String>[];

  @override
  Future<GenerationOperation> start() async {
    final answer = starts[startCalls.clamp(0, starts.length - 1)];
    startCalls++;
    if (answer is Exception) throw answer;
    return answer as GenerationOperation;
  }

  @override
  Future<GenerationOperation?> find(String id) async {
    foundIds.add(id);
    final answer = finds[findCalls.clamp(0, finds.length - 1)];
    findCalls++;
    if (answer is Exception) throw answer;
    return answer as GenerationOperation?;
  }
}

class SignedIn extends AuthViewModel {
  SignedIn([this.id = 7]);
  final int id;
  @override
  AuthState build() {
    super.build();
    return AuthState(isAuthenticated: true, user: User(id: id, firstName: 'Ana', lastName: 'Demo', email: 'ana$id@example.com', timezone: 'America/Lima'));
  }
}
