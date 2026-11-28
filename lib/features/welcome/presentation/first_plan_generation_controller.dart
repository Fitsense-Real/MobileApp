import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../push/presentation/push_controller.dart';
import '../data/plan_generation_repository.dart';
import '../data/welcome_store.dart';
import '../domain/generation_operation.dart';

/// Why the last status check did not get an answer.
enum CheckProblem {
  none,

  /// The phone could not reach the server (no signal, server down).
  connection,

  /// The server answered with a 5xx: temporary backend problem.
  server,
}

/// State of the first-plan generation as the app knows it.
class FirstPlanGenerationState {
  const FirstPlanGenerationState({this.operation, this.problem = CheckProblem.none, this.error, this.errorStatus, this.errorCode});

  /// Last state reported by the backend; null until the first answer.
  final GenerationOperation? operation;

  /// The last check failed; the generation itself may be fine and keeps
  /// running on the server, so polling continues.
  final CheckProblem problem;

  /// The backend refused the request (e.g. 422 incomplete profile).
  final String? error;

  /// HTTP status and stable code (`details[0]`) of [error]: 409 means the plan
  /// changed or a generation is already running (consult the current plan, do
  /// not retry blindly); `PARTICIPACION_NO_VIGENTE` means the account is no
  /// longer an active participant (e.g. withdrew while the plan was prepared).
  final int? errorStatus;
  final String? errorCode;

  /// The backend says this account cannot receive plans now.
  bool get participationEnded => errorCode == 'PARTICIPACION_NO_VIGENTE';

  /// A conflict with the plan of the account (HTTP 409).
  bool get planConflict => errorStatus == 409;

  bool get isWaiting => error == null && (operation == null || !operation!.isTerminal);

  FirstPlanGenerationState copyWith({GenerationOperation? operation, CheckProblem? problem, String? error, int? errorStatus, String? errorCode, bool clearError = false}) =>
      FirstPlanGenerationState(
        operation: operation ?? this.operation,
        problem: problem ?? this.problem,
        error: clearError ? null : error ?? this.error,
        errorStatus: clearError ? null : errorStatus ?? this.errorStatus,
        errorCode: clearError ? null : errorCode ?? this.errorCode,
      );
}

/// Drives the asynchronous first-plan generation:
/// - [start] resumes the stored operation or asks for one (the backend is
///   idempotent, so this never triggers a second AI generation);
/// - polls every `pollAfterSeconds` until the operation is terminal, with a
///   growing delay while there is no connection;
/// - [retry] asks again only after a failure the backend marks retryable.
class FirstPlanGenerationController extends Notifier<FirstPlanGenerationState> {
  Timer? _timer;
  int _failures = 0;
  bool _starting = false;

  /// Polling delays, overridable in tests.
  static Duration defaultPoll = const Duration(seconds: 3);
  static Duration maxBackoff = const Duration(seconds: 20);

  int? get _userId => ref.read(authViewModelProvider).user?.id;
  PlanGenerationRepository get _repository => ref.read(planGenerationRepositoryProvider);
  WelcomeStore get _store => ref.read(welcomeStoreProvider);

  @override
  FirstPlanGenerationState build() {
    ref.watch(authViewModelProvider.select((s) => s.user?.id));
    ref.onDispose(() => _timer?.cancel());
    _timer?.cancel();
    _failures = 0;
    return const FirstPlanGenerationState();
  }

  /// Resumes the stored operation if the backend still knows it; otherwise
  /// requests one. Safe to call repeatedly (double taps, app restarts).
  Future<void> start() async {
    final userId = _userId;
    if (userId == null || _starting) return;
    final current = state.operation;
    if (current != null && (!current.isTerminal || current.status == GenerationStatus.completed)) {
      if (!current.isTerminal) _schedule();
      return;
    }
    _starting = true;
    try {
      final stored = (await _store.load(userId)).operationId;
      GenerationOperation? operation;
      if (stored != null) operation = await _repository.find(stored);
      operation ??= await _startOperation();
      await _accept(userId, operation);
    } catch (e) {
      _onError(e);
    } finally {
      _starting = false;
    }
  }

  /// A new attempt after a retryable failure. The backend creates a new
  /// operation only because the previous one is closed.
  Future<void> retry() async {
    final userId = _userId;
    if (userId == null) return;
    _timer?.cancel();
    state = state.copyWith(clearError: true, problem: CheckProblem.none);
    try {
      await _accept(userId, await _startOperation());
    } catch (e) {
      _onError(e);
    }
  }

  /// Checks the status now (e.g. "Reintentar consulta" after losing signal).
  Future<void> refresh() async {
    _timer?.cancel();
    await _poll();
  }

  /// Forgets the operation once its plan was presented.
  Future<void> consume() async {
    final userId = _userId;
    _timer?.cancel();
    if (userId != null) await _store.update(userId, (p) => p.copyWith(clearOperation: true));
  }

  /// Requests a new generation only after this phone's push registration
  /// (FID + the backend's 200/201) ended, so the PLAN_GENERATED notification
  /// finds an active device. Without permission, Firebase or backend it goes
  /// on right away or after PushController.syncTimeout: never blocks.
  Future<GenerationOperation> _startOperation() async {
    try {
      await ref.read(pushControllerProvider).ensureSynced();
    } catch (_) {}
    return _repository.start();
  }

  Future<void> _accept(int userId, GenerationOperation operation) async {
    _failures = 0;
    state = FirstPlanGenerationState(operation: operation);
    await _store.update(userId, (p) => p.copyWith(operationId: operation.id));
    if (!operation.isTerminal) _schedule(Duration(seconds: operation.pollAfterSeconds ?? defaultPoll.inSeconds));
  }

  void _schedule([Duration? after]) {
    _timer?.cancel();
    final base = after ?? defaultPoll;
    // Without connection: 3 s, 6 s, 12 s... up to maxBackoff.
    final delay = _failures == 0 ? base : Duration(milliseconds: (base.inMilliseconds * (1 << _failures.clamp(0, 4))).clamp(0, maxBackoff.inMilliseconds));
    _timer = Timer(delay, _poll);
  }

  Future<void> _poll() async {
    final userId = _userId;
    final id = state.operation?.id;
    if (userId == null) return;
    if (id == null) return start();
    try {
      final operation = await _repository.find(id);
      // Unknown to the backend (e.g. database restored): ask again; idempotent.
      await _accept(userId, operation ?? await _startOperation());
    } catch (e) {
      _onError(e);
    }
  }

  void _onError(Object e) {
    final status = statusOf(e);
    final problem = e is DioException && status == null
        ? CheckProblem.connection
        : status != null && status >= 500
            ? CheckProblem.server
            : null;
    if (problem != null) {
      // The generation keeps running on the server: keep checking, slower.
      _failures++;
      state = state.copyWith(problem: problem);
      _schedule();
      return;
    }
    state = state.copyWith(error: apiError(e), errorStatus: status, errorCode: apiErrorCode(e), problem: CheckProblem.none);
  }
}

final firstPlanGenerationProvider =
    NotifierProvider<FirstPlanGenerationController, FirstPlanGenerationState>(FirstPlanGenerationController.new);
