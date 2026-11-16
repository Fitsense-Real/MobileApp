import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/data/welcome_store.dart';
import 'package:fitsense_mobile/features/welcome/domain/generation_operation.dart';
import 'package:fitsense_mobile/features/welcome/presentation/first_plan_generation_controller.dart';
import 'support/welcome_fakes.dart';

Future<void> settle([int rounds = 40]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final defaultPoll = FirstPlanGenerationController.defaultPoll;
  final maxBackoff = FirstPlanGenerationController.maxBackoff;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    FirstPlanGenerationController.defaultPoll = const Duration(milliseconds: 10);
    FirstPlanGenerationController.maxBackoff = const Duration(milliseconds: 40);
  });
  tearDown(() {
    FirstPlanGenerationController.defaultPoll = defaultPoll;
    FirstPlanGenerationController.maxBackoff = maxBackoff;
  });

  ProviderContainer containerWith(FakeGeneration generation, {int user = 7}) {
    final c = ProviderContainer(overrides: [
      authViewModelProvider.overrideWith(() => SignedIn(user)),
      planGenerationRepositoryProvider.overrideWithValue(generation),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  // Polls use pollAfterSeconds from the backend; the fake answers 3 s, too slow for a unit test.
  GenerationOperation fast(String status, {int? planId}) => GenerationOperation(
      id: operationId, status: generationStatusOf(status), planId: planId,
      pollAfterSeconds: const {'PENDING', 'PROCESSING'}.contains(status) ? 0 : null);

  test('1 · a new user requests the plan once and polls until it is ready', () async {
    final generation = FakeGeneration(starts: [fast('PENDING')], finds: [fast('PROCESSING'), fast('PROCESSING'), fast('COMPLETED', planId: 42)]);
    final c = containerWith(generation);
    await c.read(firstPlanGenerationProvider.notifier).start();
    await settle();
    final state = c.read(firstPlanGenerationProvider);
    expect(state.operation?.status, GenerationStatus.completed);
    expect(state.operation?.planId, 42);
    expect(generation.startCalls, 1);
    final polls = generation.findCalls;
    await settle();
    expect(generation.findCalls, polls, reason: 'polling stops once the operation is terminal');
    expect((await WelcomeStore().load(7)).operationId, operationId, reason: 'kept to resume after closing the app');
  });

  test('7 · after reopening the app the stored operation is resumed, not requested again', () async {
    FlutterSecureStorage.setMockInitialValues({'kora_welcome_7': jsonEncode({'tourStatus': 'inProgress', 'tourStep': 3, 'operationId': 'op-guardada'})});
    final generation = FakeGeneration(finds: [fast('COMPLETED', planId: 9)]);
    final c = containerWith(generation);
    await c.read(firstPlanGenerationProvider.notifier).start();
    expect(generation.foundIds.first, 'op-guardada');
    expect(generation.startCalls, 0);
    expect(c.read(firstPlanGenerationProvider).operation?.planId, 9);
  });

  test('an operation the backend no longer knows (404) is requested again, idempotently', () async {
    FlutterSecureStorage.setMockInitialValues({'kora_welcome_7': jsonEncode({'operationId': 'desconocida'})});
    final generation = FakeGeneration(starts: [fast('COMPLETED', planId: 9)], finds: [null]);
    final c = containerWith(generation);
    await c.read(firstPlanGenerationProvider.notifier).start();
    expect(generation.startCalls, 1);
    expect(c.read(firstPlanGenerationProvider).operation?.status, GenerationStatus.completed);
  });

  test('8, 18 · repeated starts (double tap, tour and result screen) never ask twice', () async {
    final generation = FakeGeneration(starts: [fast('PENDING')], finds: [fast('PROCESSING')]);
    final c = containerWith(generation);
    final controller = c.read(firstPlanGenerationProvider.notifier);
    await Future.wait([controller.start(), controller.start(), controller.start()]);
    await controller.start();
    expect(generation.startCalls, 1);
  });

  test('13 · losing the connection keeps the generation and keeps checking', () async {
    final generation = FakeGeneration(starts: [fast('PENDING')], finds: [offline(), offline(), fast('COMPLETED', planId: 5)]);
    final c = containerWith(generation);
    await c.read(firstPlanGenerationProvider.notifier).start();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    await settle(3);
    expect(c.read(firstPlanGenerationProvider).problem, CheckProblem.connection);
    expect(c.read(firstPlanGenerationProvider).isWaiting, isTrue, reason: 'not shown as a failure');
    await settle(60);
    final state = c.read(firstPlanGenerationProvider);
    expect(state.operation?.status, GenerationStatus.completed);
    expect(state.problem, CheckProblem.none);
    expect(generation.startCalls, 1, reason: 'no new generation because of the connection');
  });

  test('a 5xx while checking is a server problem, not a connection problem', () async {
    final generation = FakeGeneration(starts: [fast('PENDING')], finds: [httpError(503)]);
    final c = containerWith(generation);
    await c.read(firstPlanGenerationProvider.notifier).start();
    await settle(8);
    expect(c.read(firstPlanGenerationProvider).problem, CheckProblem.server);
  });

  test('a refused request (422) is an error with the backend message', () async {
    final generation = FakeGeneration(starts: [httpError(422, 'Completa tu perfil antes de preparar tu primera rutina.')]);
    final c = containerWith(generation);
    await c.read(firstPlanGenerationProvider.notifier).start();
    expect(c.read(firstPlanGenerationProvider).error, contains('Completa tu perfil'));
  });

  test('12 · a retryable failure is retried only when the user asks', () async {
    final generation = FakeGeneration(
      starts: [fast('PENDING'), GenerationOperation(id: 'op-2', status: GenerationStatus.pending, pollAfterSeconds: 0)],
      finds: [operation('FAILED', reason: 'ERROR_TECNICO', message: 'Problema técnico', retryable: true)],
    );
    final c = containerWith(generation);
    final controller = c.read(firstPlanGenerationProvider.notifier);
    await controller.start();
    await settle();
    expect(c.read(firstPlanGenerationProvider).operation?.status, GenerationStatus.failed);
    expect(generation.startCalls, 1, reason: 'no automatic retry');
    await controller.start();
    expect(generation.startCalls, 1, reason: 'start does not hide a failure behind a new request');
    await controller.retry();
    expect(generation.startCalls, 2);
    expect(c.read(firstPlanGenerationProvider).operation?.id, 'op-2');
  });

  test('19 · two users on the same phone never share progress or operation', () async {
    final store = WelcomeStore();
    await store.save(7, const WelcomeProgress(tourStatus: TourStatus.completed, tourStep: 9, operationId: 'op-ana'));
    await store.save(8, const WelcomeProgress(tourStatus: TourStatus.inProgress, tourStep: 2, operationId: 'op-beto'));
    expect((await store.load(7)).operationId, 'op-ana');
    expect((await store.load(8)).tourStep, 2);
    final generation = FakeGeneration(finds: [fast('PROCESSING')]);
    final c = containerWith(generation, user: 8);
    await c.read(firstPlanGenerationProvider.notifier).start();
    expect(generation.foundIds.first, 'op-beto');
  });

  test('consume forgets the operation once its plan was presented', () async {
    final generation = FakeGeneration(starts: [fast('COMPLETED', planId: 4)]);
    final c = containerWith(generation);
    await c.read(firstPlanGenerationProvider.notifier).start();
    await c.read(firstPlanGenerationProvider.notifier).consume();
    expect((await WelcomeStore().load(7)).operationId, isNull);
  });

  // ---- Backend #71 + #72 (V59): same REST contract, operations may stay active up to 30 min ----

  test('#72 · a generation that stays PROCESSING for many checks (with drops and 5xx) is never requested again', () async {
    final finds = <Object?>[
      for (var i = 0; i < 120; i++) fast('PROCESSING'),
      offline(), httpError(503), offline(),
      for (var i = 0; i < 120; i++) fast('PROCESSING'),
      fast('COMPLETED', planId: 77),
    ];
    final generation = FakeGeneration(starts: [fast('PENDING')], finds: finds);
    final c = containerWith(generation);
    await c.read(firstPlanGenerationProvider.notifier).start();
    for (var i = 0; i < 80 && c.read(firstPlanGenerationProvider).isWaiting; i++) {
      await settle(20);
    }
    final state = c.read(firstPlanGenerationProvider);
    expect(state.operation?.status, GenerationStatus.completed);
    expect(state.operation?.planId, 77);
    expect(generation.startCalls, 1, reason: 'time and connection problems never start a new generation');
    expect(generation.findCalls, greaterThanOrEqualTo(240));
    expect(generation.foundIds.toSet(), {operationId}, reason: 'always the same operation');
  });

  test('#72 · the documented PlanGenerationOperationResource is parsed as before', () {
    final processing = GenerationOperation.fromJson({
      'operationId': '3f1c9a2e-0000-4000-8000-000000000001', 'status': 'PROCESSING', 'terminal': false,
      'weekStartDate': '2026-11-16', 'planId': null, 'reasonCode': null, 'message': null, 'retryable': false,
      'createdAt': '2026-11-16T10:00:00Z', 'startedAt': '2026-11-16T10:00:02Z', 'finishedAt': null, 'pollAfterSeconds': 3,
    });
    expect(processing.isTerminal, isFalse);
    expect(processing.pollAfterSeconds, 3);
    final timedOut = GenerationOperation.fromJson({
      'operationId': 'x', 'status': 'FAILED', 'terminal': true, 'reasonCode': 'TIEMPO_EXCEDIDO',
      'message': 'La preparación de tu rutina tardó más de lo permitido. Puedes intentarlo de nuevo.', 'retryable': true,
      'pollAfterSeconds': null,
    });
    expect(timedOut.isTerminal, isTrue);
    expect(timedOut.retryable, isTrue);
    expect(timedOut.reasonCode, 'TIEMPO_EXCEDIDO');
    final interrupted = GenerationOperation.fromJson({'operationId': 'y', 'status': 'FAILED', 'reasonCode': 'EJECUCION_INTERRUMPIDA', 'retryable': true});
    expect(interrupted.retryable, isTrue);
    // A status the app does not know yet keeps it waiting instead of showing a failure.
    expect(GenerationOperation.fromJson({'operationId': 'z', 'status': 'NUEVO_ESTADO'}).isTerminal, isFalse);
  });

  test('#72 · a manual retry after TIEMPO_EXCEDIDO is one request, accepted as a new operation', () async {
    final generation = FakeGeneration(
      starts: [fast('PENDING'), GenerationOperation(id: 'op-reintento', status: GenerationStatus.completed, planId: 8)],
      finds: [operation('FAILED', reason: 'TIEMPO_EXCEDIDO', retryable: true)],
    );
    final c = containerWith(generation);
    await c.read(firstPlanGenerationProvider.notifier).start();
    await settle();
    expect(c.read(firstPlanGenerationProvider).operation?.reasonCode, 'TIEMPO_EXCEDIDO');
    await settle();
    expect(generation.startCalls, 1, reason: 'no automatic retry');
    await c.read(firstPlanGenerationProvider.notifier).retry();
    expect(generation.startCalls, 2);
    expect(c.read(firstPlanGenerationProvider).operation?.planId, 8);
  });
}
