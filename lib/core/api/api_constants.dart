import 'package:flutter/foundation.dart';

/// Endpoints of the Fitsense backend (`/api/v1`). Keep in sync with the
/// Spring controllers in Fitsense-Real/Backend.
class ApiConstants {
  ApiConstants._();

  /// Emulador Android: 10.0.2.2. Web/escritorio: localhost.
  static String get baseUrl => const String.fromEnvironment('API_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8080/api/v1'
          : 'http://localhost:8080/api/v1';

  // Autenticación (públicos, sin JWT)
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const publicPaths = {login, register, forgotPassword, resetPassword};

  /// The backend (AuthenticationController) has no password recovery yet.
  /// While false, the app explains it instead of calling missing endpoints.
  static const passwordRecoveryAvailable = false;
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';

  // Usuario
  static const me = '/users/me';
  static const withdraw = '/users/me/withdraw';
  static const profile = '/users/me/profile';

  // Catálogo
  static const equipment = '/catalog/equipment-types';
  static const bodyParts = '/catalog/body-parts';
  static const exercises = '/catalog/exercises';
  static String exercise(Object id) => '/catalog/exercises/$id';

  // Planes
  static const currentPlan = '/users/me/plan/current';
  static const generatePlan = '/users/me/plan/generate';
  static const planHistory = '/users/me/plans';
  static String plan(Object id) => '/users/me/plan/$id';

  // Ejecución
  static String startWorkout(Object id) => '/workouts/$id/start';
  static String skipWorkout(Object id) => '/workouts/$id/skip';
  static String reportWorkout(Object id) => '/workouts/$id/report';
  static const currentSession = '/sessions/current';
  static String session(Object id) => '/sessions/$id';
  static String sessionExercise(Object sessionId, Object plannedExerciseId) =>
      '/sessions/$sessionId/exercises/$plannedExerciseId';
  static String finishSession(Object id) => '/sessions/$id/finish';
  static String abandonSession(Object id) => '/sessions/$id/abandon';

  // Analítica y adaptación
  static const weeklyMetrics = '/users/me/metrics/weekly';
  static const interventions = '/users/me/interventions';
  static const runCycle = '/cycle/run-for-me';
}
