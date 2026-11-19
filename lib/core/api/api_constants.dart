import 'api_config.dart';

/// Endpoints of the Fitsense backend (`/api/v1`). Keep in sync with the
/// Spring controllers in Fitsense-Real/Backend, branch `generation`.
class ApiConstants {
  ApiConstants._();

  /// From [ApiConfig]: local backend in development, mandatory HTTPS
  /// `API_BASE_URL` in release (empty, never a local fallback, if missing).
  static String get baseUrl => ApiConfig.current.baseUrl;

  // Autenticación (públicos, sin JWT)
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const publicPaths = {login, register, forgotPassword, resetPassword};

  /// PasswordResetController: request a code by email, then confirm it.
  static const passwordRecoveryAvailable = true;
  static const forgotPassword = '/auth/password-reset/request';
  static const resetPassword = '/auth/password-reset/confirm';

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
  static const planLimitations = '/users/me/plan/limitations';
  static const planAdaptations = '/users/me/plan/adaptations';

  // Exclusiones por dolor
  static const painExclusions = '/users/me/pain-exclusions';
  static String reactivatePainExclusion(Object exerciseId) => '/users/me/pain-exclusions/$exerciseId/reactivation';

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
