// Contract tests against the Fitsense-Real/Backend REST API. Fixtures copy
// the field names and enum values of the Spring resources (records under
// */interfaces/rest/resources) so a drift on either side fails here.
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/api_constants.dart';
import 'package:fitsense_mobile/core/api/api_error.dart';
import 'package:fitsense_mobile/core/network/auth_interceptor.dart';
import 'package:fitsense_mobile/core/services/session_service.dart';
import 'package:fitsense_mobile/core/storage/token_storage.dart';
import 'package:fitsense_mobile/features/authentication/data/datasource/auth_remote_datasource.dart';
import 'package:fitsense_mobile/features/authentication/data/models/user_response.dart';
import 'package:fitsense_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:fitsense_mobile/features/authentication/domain/usecases/get_current_user_use_case.dart';
import 'package:fitsense_mobile/features/authentication/presentation/pages/login_page.dart';
import 'package:fitsense_mobile/features/catalog/data/catalog_repository.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/widgets/plan_history_sheet.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/domain/workout_rules.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

/// Routes declared by the backend controllers (method + path under /api/v1).
const backendRoutes = {
  'POST /auth/register', 'POST /auth/login',
  'GET /users/me', 'POST /users/me/withdraw',
  'GET /users/me/profile', 'POST /users/me/profile', 'PUT /users/me/profile',
  'GET /catalog/body-parts', 'GET /catalog/equipment-types', 'GET /catalog/exercises', 'GET /catalog/exercises/{id}',
  'GET /users/me/plan/current', 'POST /users/me/plan/generate', 'GET /users/me/plan/{id}', 'GET /users/me/plans',
  'POST /workouts/{id}/skip', 'POST /workouts/{id}/start', 'POST /workouts/{id}/report',
  'GET /sessions/current', 'GET /sessions/{id}', 'PUT /sessions/{id}/exercises/{id}',
  'POST /sessions/{id}/finish', 'POST /sessions/{id}/abandon',
  'GET /users/me/metrics/weekly', 'GET /users/me/metrics/weekly/{id}',
  'GET /users/me/interventions', 'POST /cycle/run-for-me', 'GET /config/active',
};

/// `UserResource`.
const userResource = {
  'userId': 7, 'email': 'ana@example.com', 'firstName': 'Ana', 'lastName': 'Pérez',
  'timezone': 'America/Lima', 'status': 'ACTIVE', 'studyParticipant': true, 'participantCode': 'P-007',
  'enrolledAt': '2026-10-01T10:00:00-05:00', 'withdrawnAt': null, 'lastLoginAt': '2026-11-05T08:00:00-05:00',
};

/// `PlannedExerciseResource` (DURATION) and (SETS_REPS).
const plankExercise = {
  'plannedExerciseId': 501, 'exerciseId': 77, 'exerciseName': 'Plancha', 'targetMuscle': 'abs', 'bodyPart': 'waist',
  'equipment': 'body weight', 'difficultyLevel': 1, 'exerciseOrder': 2, 'prescriptionType': 'DURATION',
  'plannedSets': 3, 'plannedReps': null, 'plannedDurationSeconds': 30, 'targetLoadKg': null, 'restSeconds': 45,
  'notes': null, 'gifPath': 'videos/0001-abc.gif', 'imagePath': null, 'mediaAttribution': 'ExerciseDB',
};
const squatExercise = {
  'plannedExerciseId': 500, 'exerciseId': 76, 'exerciseName': 'Sentadilla', 'targetMuscle': 'quads', 'bodyPart': 'upper legs',
  'equipment': 'body weight', 'difficultyLevel': 1, 'exerciseOrder': 1, 'prescriptionType': 'SETS_REPS',
  'plannedSets': 3, 'plannedReps': 12, 'plannedDurationSeconds': null, 'targetLoadKg': 10.5, 'restSeconds': 60,
  'notes': 'Controla la bajada', 'gifPath': null, 'imagePath': null, 'mediaAttribution': null,
};

String isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

/// `PlannedWorkoutResource`.
Map<String, dynamic> plannedWorkout({required int id, required DateTime date, String status = 'SCHEDULED', String focus = 'LOWER_BODY', DateTime? expiresAt, String? skipReason}) => {
  'plannedWorkoutId': id, 'scheduledDate': isoDate(date), 'focusCode': focus, 'workoutName': 'Piernas y core $id',
  'expectedDurationMinutes': 40, 'displayOrder': id, 'status': status, 'skipReason': skipReason,
  'expiresAt': (expiresAt ?? DateTime(date.year, date.month, date.day, 23, 59)).toIso8601String(),
  'exercises': [squatExercise, plankExercise],
};

/// `WeeklyTrainingPlanResource`.
Map<String, dynamic> weeklyPlan(List<Map<String, dynamic>> workouts) {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  return {
    'planId': 3, 'weekNumber': 2, 'weekStartDate': isoDate(monday), 'weekEndDate': isoDate(monday.add(const Duration(days: 6))),
    'planVersion': 2, 'parentPlanId': 2, 'plannedDaysCount': workouts.length, 'status': 'ACTIVE',
    'generationSource': 'AI', 'modelName': 'model', 'adjustmentApplied': 'REDUCE_VOLUME', 'adjustmentReason': 'Semana con fatiga',
    'activatedAt': '2026-11-02T00:30:00-05:00', 'workouts': workouts,
    'effortGuidance': {'repsInReserve': '2-3', 'setsRepsText': '3x12', 'durationText': '30 s', 'loadText': 'ligera'},
  };
}

class FakeBackend implements HttpClientAdapter {
  FakeBackend(this.handler);
  final ({int status, Object? body}) Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    requests.add(options);
    final r = handler(options);
    return ResponseBody.fromString(r.body == null ? '' : jsonEncode(r.body), r.status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

Dio dioWith(FakeBackend backend) => Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'))
  ..httpClientAdapter = backend
  ..interceptors.add(AuthInterceptor());

String route(RequestOptions o) => '${o.method} ${o.path.replaceAll(RegExp(r'/\d+'), '/{id}').replaceAll(RegExp(r'/\d{4}-\d{2}-\d{2}'), '/{id}')}';

DioException httpError(int status, Object? body, {String path = '/x'}) {
  final options = RequestOptions(path: path);
  return DioException(requestOptions: options, type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: status, data: body));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({'access_token': 'jwt'}));

  group('ApiErrorResource', () {
    test('validation details (List<String>) are shown, not only the summary', () {
      final message = apiError(httpError(400, {
        'timestamp': '2026-11-06T10:00:00Z', 'status': 400, 'error': 'Bad Request',
        'message': 'La solicitud tiene campos invalidos.',
        'details': ['sessionMinutes: debe ser mayor que o igual a 15', 'heightCm: no debe ser nulo'],
      }));
      expect(message, contains('La solicitud tiene campos invalidos.'));
      expect(message, contains('sessionMinutes: debe ser mayor que o igual a 15'));
      expect(message, contains('heightCm: no debe ser nulo'));
    });
    test('domain rules (422) show the backend message', () {
      expect(apiError(httpError(422, {'status': 422, 'message': 'El entrenamiento ya vencio.', 'details': []})), 'El entrenamiento ya vencio.');
    });
    test('status-specific fallbacks', () {
      expect(apiError(httpError(401, null)), contains('Vuelve a iniciar sesión'));
      expect(apiError(httpError(403, null)), contains('No tienes acceso'));
      expect(apiError(httpError(503, null)), contains('503'));
      expect(apiError(DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError)), contains('No se pudo conectar'));
    });
    test('an existing plan is reported as 422 (DomainRuleViolation) and reconciled', () {
      expect(isPlanConflict(httpError(422, null)), isTrue);
      expect(isPlanConflict(httpError(409, null)), isTrue);
      expect(isPlanConflict(httpError(500, null)), isFalse);
      expect(isPlanConflict(const ApiException('x', statusCode: 422)), isTrue);
    });
  });

  group('Every mobile call exists in the backend', () {
    test('paths and methods match the Spring controllers', () async {
      final backend = FakeBackend((o) => switch (o.path) {
        '/users/me/metrics/weekly' || '/users/me/interventions' || '/users/me/plans' || '/catalog/exercises' || '/catalog/equipment-types' => (status: 200, body: []),
        '/sessions/current' => (status: 204, body: null),
        '/workouts/21/skip' => (status: 204, body: null),
        _ => (status: 200, body: {...userResource, 'planId': 3, 'sessionId': 8, 'exerciseId': 77, 'token': 't'}),
      });
      final dio = dioWith(backend);
      final auth = AuthRemoteDataSource(dio);
      await auth.me(); await auth.withdraw();
      final profiles = ProfileRepository(dio);
      await profiles.fetch(); await profiles.equipment();
      await profiles.save({'birthDate': '1990-01-01'}, exists: false); await profiles.save({}, exists: true);
      final catalog = CatalogRepository(dio);
      await catalog.exercises(search: 'sentadilla'); await catalog.exercise(77);
      final plans = PlanRepository(dio);
      await plans.current(); await plans.byId(3); await plans.history(); await plans.generate();
      final workouts = WorkoutRepository(dio);
      expect(await workouts.current(), isNull);
      await workouts.byId(8); await workouts.start(21); await workouts.record(8, 500, {}); await workouts.finish(8, {'sessionRpe': 7});
      await workouts.abandon(8); await workouts.skip(21, 'FATIGUE'); await workouts.report(21, {});
      final dashboard = DashboardRepository(dio);
      await dashboard.metrics(); await dashboard.interventions();
      expect((await dashboard.runCycle())['planId'], 3);
      for (final request in backend.requests) {
        expect(backendRoutes, contains(route(request)), reason: 'Not in backend: ${route(request)}');
        expect(request.headers['Authorization'], 'Bearer jwt', reason: route(request));
      }
      expect(backend.requests.map(route), containsAll(['POST /users/me/withdraw', 'GET /users/me/plans', 'GET /catalog/exercises/{id}', 'GET /sessions/{id}']));
      final search = backend.requests.firstWhere((r) => r.path == '/catalog/exercises');
      expect(search.queryParameters, {'search': 'sentadilla', 'limit': 30});
    });
    test('password recovery is not called while the backend lacks it', () {
      expect(ApiConstants.passwordRecoveryAvailable, isFalse);
      expect(backendRoutes.any((r) => r.contains('password')), isFalse);
    });
  });

  group('Profile payloads', () {
    final body = {
      'birthDate': '1990-05-04', 'biologicalSex': null, 'heightCm': 170, 'currentWeightKg': 70, 'targetWeightKg': null,
      'fitnessLevel': 'BEGINNER', 'goalType': 'GENERAL_FITNESS', 'goalText': 'Moverme', 'trainingLocation': 'HOME',
      'daysPerWeek': 3, 'availableDays': [1, 3, 5], 'sessionMinutes': 45, 'equipmentCodes': <String>[],
      'blockedExerciseIds': [76], 'healthNotes': null, 'allowHighImpact': false,
    };
    test('create sends exactly CreateUserProfileResource fields', () async {
      final backend = FakeBackend((o) => (status: 201, body: o.data));
      await ProfileRepository(dioWith(backend)).save(body, exists: false);
      final sent = backend.requests.single;
      expect(sent.method, 'POST');
      expect((sent.data as Map).keys.toSet(), createProfileFields);
      expect(sent.data['blockedExerciseIds'], [76]);
    });
    test('update omits birthDate, which UpdateUserProfileResource does not accept', () async {
      final backend = FakeBackend((o) => (status: 200, body: o.data));
      await ProfileRepository(dioWith(backend)).save(body, exists: true);
      final sent = backend.requests.single;
      expect(sent.method, 'PUT');
      expect((sent.data as Map).containsKey('birthDate'), isFalse);
      expect((sent.data as Map).containsKey('allowHighImpact'), isFalse);
      expect((sent.data as Map).keys.toSet(), updateProfileFields);
    });
  });

  group('Users and session', () {
    test('UserResource is parsed with study participation', () {
      final user = UserResponse.fromJson(userResource);
      expect(user.id, 7);
      expect(user.studyParticipant, isTrue);
      expect(user.participantCode, 'P-007');
      expect(user.withdrawnAt, isNull);
    });
    test('AuthenticatedUserResource (login) is parsed', () {
      final user = UserResponse.fromJson({'userId': 7, 'email': 'a@b.com', 'fullName': 'Ana Pérez', 'token': 't'});
      expect(user.firstName, 'Ana Pérez');
      expect(user.studyParticipant, isFalse);
    });
    test('withdraw updates the account from the response', () async {
      final backend = FakeBackend((o) => (status: 200, body: {...userResource, 'withdrawnAt': '2026-11-06T10:00:00-05:00'}));
      final user = await AuthRepositoryImpl(AuthRemoteDataSource(dioWith(backend))).withdrawFromStudy();
      expect(backend.requests.single.method, 'POST');
      expect(user.withdrawnAt, isNotNull);
      expect(user.canWithdraw, isFalse);
    });
    SessionService sessionWith(FakeBackend backend) =>
        SessionService(GetCurrentUserUseCase(AuthRepositoryImpl(AuthRemoteDataSource(dioWith(backend)))));
    test('a rejected JWT (401) is deleted', () async {
      expect(await sessionWith(FakeBackend((_) => (status: 401, body: null))).restore(), isNull);
      expect(await TokenStorage.getToken(), isNull);
    });
    test('a network failure or 5xx keeps the JWT', () async {
      final down = FakeBackend((o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError));
      expect(await sessionWith(down).restore(), isNull);
      expect(await TokenStorage.getToken(), 'jwt');
      expect(await sessionWith(FakeBackend((_) => (status: 500, body: null))).restore(), isNull);
      expect(await TokenStorage.getToken(), 'jwt');
    });
    test('a valid JWT restores the user', () async {
      final user = await sessionWith(FakeBackend((_) => (status: 200, body: userResource))).restore();
      expect(user?.email, 'ana@example.com');
    });
  });

  group('Workout rules mirror the backend', () {
    final now = DateTime(2026, 11, 6, 12);
    test('every WorkoutStatus has a Spanish label', () {
      for (final status in ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'PARTIAL', 'SKIPPED', 'REPLACED']) {
        expect(workoutStatusLabel(status), isNot(status), reason: status);
      }
    });
    test('every WorkoutFocus has a Spanish label', () {
      for (final focus in ['FULL_BODY', 'UPPER_BODY', 'LOWER_BODY', 'PUSH', 'PULL', 'LEGS', 'CORE']) {
        expect(workoutFocusLabels[focus], isNotNull, reason: focus);
      }
    });
    test('start needs an open workout before expiresAt', () {
      Map<String, dynamic> w(String status, String expires) => {'status': status, 'expiresAt': expires};
      expect(canStartWorkout(w('SCHEDULED', '2026-11-06T23:59:00-05:00'), now: now), isTrue);
      expect(canStartWorkout(w('IN_PROGRESS', '2026-11-06T23:59:00-05:00'), now: now), isTrue);
      expect(canStartWorkout(w('SCHEDULED', '2026-11-05T23:59:00-05:00'), now: now), isFalse);
      for (final closed in ['COMPLETED', 'PARTIAL', 'SKIPPED', 'REPLACED']) {
        expect(canStartWorkout(w(closed, '2026-11-07T23:59:00-05:00'), now: now), isFalse, reason: closed);
      }
    });
    test('report is rejected only for COMPLETED/PARTIAL (and replaced plans)', () {
      expect(canReportWorkout({'status': 'SKIPPED'}), isTrue);
      expect(canReportWorkout({'status': 'SCHEDULED'}), isTrue);
      expect(canReportWorkout({'status': 'COMPLETED'}), isFalse);
      expect(canReportWorkout({'status': 'PARTIAL'}), isFalse);
      expect(canReportWorkout({'status': 'REPLACED'}), isFalse);
    });
    test('"Lo completé" on a DURATION exercise sends sets × seconds (backend denominator)', () {
      final result = prescribedResult(plankExercise);
      expect(result['actualDurationSeconds'], 90);
      expect(result['actualRepsTotal'], 0);
      expect(result['actualDurationSeconds'], plannedTotal(plankExercise));
    });
    test('"Lo completé" on SETS_REPS sends sets × reps and the target load', () {
      final result = prescribedResult(squatExercise);
      expect(result, {'actualSets': 3, 'actualRepsTotal': 36, 'actualDurationSeconds': 0, 'actualLoadKg': 10.5, 'skipReason': null});
    });
  });

  group('Screens with real backend payloads', () {
    Widget app(Widget home, {List overrides = const []}) => ProviderScope(
      overrides: [...overrides.cast()],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );
    testWidgets('an upcoming SCHEDULED workout can be started, skipped or reported', (tester) async {
      tester.view.physicalSize = const Size(500, 1400); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final backend = FakeBackend((o) => o.path == '/sessions/current' ? (status: 204, body: null) : (status: 200, body: {}));
      final workout = plannedWorkout(id: 21, date: DateTime.now().add(const Duration(days: 1)));
      await tester.pumpWidget(app(PlannedWorkoutPage(workout: workout), overrides: [workoutRepositoryProvider.overrideWithValue(WorkoutRepository(dioWith(backend)))]));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tren inferior'), findsOneWidget);
      expect(find.text('3 series · 12 repeticiones por serie · 10.5 kg'), findsOneWidget);
      expect(find.text('3 series · 30 s por serie'), findsOneWidget);
      expect(find.text('Ver instrucciones'), findsNWidgets(2));
      await tester.scrollUntilVisible(find.text('Omitir entrenamiento'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Comenzar entrenamiento'), findsOneWidget);
      expect(find.text('Ya lo hice · registrar entrenamiento'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('an expired SCHEDULED workout offers only the retroactive report', (tester) async {
      tester.view.physicalSize = const Size(500, 1400); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final backend = FakeBackend((o) => (status: 204, body: null));
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final workout = plannedWorkout(id: 22, date: yesterday);
      await tester.pumpWidget(app(PlannedWorkoutPage(workout: workout), overrides: [workoutRepositoryProvider.overrideWithValue(WorkoutRepository(dioWith(backend)))]));
      await tester.pumpAndSettle();
      expect(find.textContaining('venció'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ya lo hice · registrar entrenamiento'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Comenzar entrenamiento'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('a COMPLETED workout is read-only', (tester) async {
      final backend = FakeBackend((o) => (status: 204, body: null));
      final workout = plannedWorkout(id: 23, date: DateTime.now(), status: 'COMPLETED');
      await tester.pumpWidget(app(PlannedWorkoutPage(workout: workout), overrides: [workoutRepositoryProvider.overrideWithValue(WorkoutRepository(dioWith(backend)))]));
      await tester.pumpAndSettle();
      expect(find.textContaining('ya está registrado como completado'), findsOneWidget);
      expect(find.text('Registrar ejercicio'), findsNothing);
      expect(find.text('Comenzar entrenamiento'), findsNothing);
      expect(find.text('Ya lo hice · registrar entrenamiento'), findsNothing);
    });
    testWidgets('exercise instructions come from GET /catalog/exercises/{id}', (tester) async {
      final backend = FakeBackend((o) => switch (o.path) {
        '/catalog/exercises/76' => (status: 200, body: {'exerciseId': 76, 'name': 'Sentadilla', 'targetMuscle': 'quads', 'secondaryMuscles': ['glutes'], 'instructions': 'Baja con la espalda recta.', 'mediaAttribution': 'ExerciseDB'}),
        _ => (status: 204, body: null),
      });
      final dio = dioWith(backend);
      final workout = plannedWorkout(id: 24, date: DateTime.now().add(const Duration(days: 1)));
      await tester.pumpWidget(app(PlannedWorkoutPage(workout: workout), overrides: [
        workoutRepositoryProvider.overrideWithValue(WorkoutRepository(dio)),
        catalogRepositoryProvider.overrideWithValue(CatalogRepository(dio)),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver instrucciones').first); await tester.pumpAndSettle();
      expect(find.text('Baja con la espalda recta.'), findsOneWidget);
      expect(find.textContaining('Secundarios: glutes'), findsOneWidget);
    });
    testWidgets('dashboard renders a full WeeklyTrainingPlanResource', (tester) async {
      tester.view.physicalSize = const Size(420, 900); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final plan = weeklyPlan([
        plannedWorkout(id: 1, date: tomorrow, focus: 'UPPER_BODY'),
        plannedWorkout(id: 2, date: tomorrow.add(const Duration(days: 1)), focus: 'CORE', status: 'SKIPPED', skipReason: 'FATIGUE'),
      ]);
      await tester.pumpWidget(app(const DashboardPage(), overrides: [
        currentPlanProvider.overrideWith((ref) async => plan),
        weeklyMetricsProvider.overrideWith((ref) async => [{'weekStartDate': '2026-10-26', 'weightedAdherencePct': 72.5, 'completedWorkouts': 2, 'scheduledWorkouts': 3, 'totalTrainingMinutes': 80, 'riskLevel': 'MODERATE', 'calculatedAt': '2026-11-02T00:30:00-05:00'}]),
        interventionsProvider.overrideWith((ref) async => []),
        dashboardProfileProvider.overrideWith((ref) async => null),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('TU PLAN DE LA SEMANA · V2'), findsOneWidget);
      await tester.tap(find.text('Rutinas')); await tester.pumpAndSettle();
      expect(find.text('TREN SUPERIOR'), findsOneWidget);
      expect(find.text('CORE'), findsOneWidget);
      expect(find.text('Omitido'), findsOneWidget);
      await tester.tap(find.text('Progreso')); await tester.pumpAndSettle();
      expect(find.text('72.5%'), findsOneWidget);
      expect(find.textContaining('Riesgo de abandono: Moderado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('plan history lists versions from GET /users/me/plans', (tester) async {
      await tester.pumpWidget(app(const Scaffold(body: PlanHistorySheet()), overrides: [
        planHistoryProvider.overrideWith((ref) async => [
          {'planId': 3, 'weekNumber': 2, 'weekStartDate': '2026-11-02', 'weekEndDate': '2026-11-08', 'planVersion': 2, 'plannedDaysCount': 3, 'status': 'ACTIVE', 'generationSource': 'AI', 'adjustmentApplied': 'REDUCE_VOLUME'},
          {'planId': 2, 'weekNumber': 2, 'weekStartDate': '2026-11-02', 'weekEndDate': '2026-11-08', 'planVersion': 1, 'plannedDaysCount': 3, 'status': 'REPLACED', 'generationSource': 'RULES', 'adjustmentApplied': null},
        ]),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Semana del 02/11/2026 · v2'), findsOneWidget);
      expect(find.text('Vigente · 3 días · Menos volumen'), findsOneWidget);
      expect(find.text('Reemplazado · 3 días'), findsOneWidget);
    });
    test('plan history is sorted by week and version', () async {
      final backend = FakeBackend((_) => (status: 200, body: [
        {'planId': 1, 'weekStartDate': '2026-10-26', 'planVersion': 1},
        {'planId': 2, 'weekStartDate': '2026-11-02', 'planVersion': 1},
        {'planId': 3, 'weekStartDate': '2026-11-02', 'planVersion': 2},
      ]));
      expect((await PlanRepository(dioWith(backend)).history()).map((p) => p['planId']), [3, 2, 1]);
    });
    testWidgets('forgot password explains it is unavailable instead of calling the API', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginPage())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('¿Olvidaste la clave?')); await tester.pumpAndSettle();
      expect(find.textContaining('todavía no está disponible'), findsOneWidget);
    });
  });

  test('timestamps with offset are shown in local time', () {
    final local = DateTime.parse('2026-11-06T23:59:00-05:00').toLocal();
    expect(displayDate('2026-11-06T23:59:00-05:00'), '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}');
    expect(displayDate('2026-11-06'), '06/11/2026');
  });
}
