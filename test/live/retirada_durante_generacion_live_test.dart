// Backend PR #96, live: a participant who withdraws WHILE the first plan is
// being prepared never gets it published. Needs a backend whose AI points to a
// local SIMULATED provider that answers late (never Replicate), so there is a
// window between the request and the publication. Skipped unless
// KORA_LIVE_API_BASE_URL and KORA_LIVE_AI_SIMULADA=si are set.
//
//   KORA_LIVE_API_BASE_URL=http://localhost:8080/api/v1 KORA_LIVE_PASSWORD=... KORA_LIVE_AI_SIMULADA=si \
//   flutter test test/live/retirada_durante_generacion_live_test.dart
//
// Uses the app's real LegalDocumentsRepository, RegisterRequest, AuthRemoteDataSource
// and PlanGenerationRepository.
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/authentication/data/datasource/auth_remote_datasource.dart';
import 'package:fitsense_mobile/features/authentication/data/models/login_request.dart';
import 'package:fitsense_mobile/features/authentication/data/models/register_request.dart';
import 'package:fitsense_mobile/features/consents/domain/legal_documents.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/domain/generation_operation.dart';

final env = Platform.environment;
final base = env['KORA_LIVE_API_BASE_URL'];

Dio plain([String? jwt]) => Dio(BaseOptions(baseUrl: base!, contentType: Headers.jsonContentType, validateStatus: (s) => s != null && s < 500 && s != 401 && s != 422,
    headers: {'Accept': 'application/json', 'Authorization': ?(jwt == null ? null : 'Bearer $jwt')}));

void log(String line) => stdout.writeln('RETIRADA $line');

void main() {
  final skip = base == null || env['KORA_LIVE_AI_SIMULADA'] != 'si' ? 'needs KORA_LIVE_API_BASE_URL and KORA_LIVE_AI_SIMULADA=si' : false;

  test('withdrawal during the generation: the plan is not published and no new generation is possible', () async {
    final docs = await LegalDocumentsRepository(plain()).current();
    final email = 'audit-retirada-gen-${DateTime.now().millisecondsSinceEpoch}@audit.local';
    final auth = AuthRemoteDataSource(plain());
    await auth.register(RegisterRequest(firstName: 'Retirada', lastName: 'Durante', email: email, password: env['KORA_LIVE_PASSWORD']!,
        acceptsStudyParticipation: true, acceptedTermsVersion: docs.terms!.version, acceptedPrivacyVersion: docs.privacy!.version,
        acceptedStudyConsentVersion: docs.studyConsent!.version));
    final jwt = (await auth.login(LoginRequest(email: email, password: env['KORA_LIVE_PASSWORD']!))).token;
    final dio = plain(jwt);
    await dio.post('/users/me/profile', data: {
      'birthDate': '1990-05-05', 'heightCm': 170, 'currentWeightKg': 70, 'fitnessLevel': 'BEGINNER', 'goalType': 'GENERAL_FITNESS',
      'goalText': 'Constancia', 'trainingLocation': 'HOME', 'daysPerWeek': 3, 'availableDays': [1, 3, 5], 'sessionMinutes': 45,
      'equipmentCodes': ['body weight'], 'blockedExerciseIds': [],
    });
    final generations = PlanGenerationRepository(dio);
    var op = await generations.start();
    log('1. POST /users/me/plan/generation → ${op.status} (${op.id})');
    for (var i = 0; i < 30 && op.status != GenerationStatus.processing && !op.isTerminal; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      op = (await generations.find(op.id))!;
    }
    log('2. la operación está en ${op.status}: la IA simulada todavía no respondió');
    expect(op.status, GenerationStatus.processing, reason: 'the simulated provider must leave a window');
    final withdrawn = await AuthRemoteDataSource(dio).withdraw();
    log('3. POST /users/me/withdraw durante la generación → withdrawnAt=${withdrawn.withdrawnAt}');
    final started = DateTime.now();
    while (!op.isTerminal && DateTime.now().difference(started) < const Duration(minutes: 4)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      op = (await generations.find(op.id))!;
    }
    log('4. la operación termina → ${op.status} ${op.reasonCode ?? ''} «${op.message ?? ''}» planId=${op.planId}');
    expect(op.isTerminal, isTrue);
    expect(op.status, isNot(GenerationStatus.completed), reason: 'never published for someone who withdrew');
    expect(op.planId, isNull);
    final current = await dio.get('/users/me/plan/current');
    log('5. GET /users/me/plan/current → ${current.statusCode}');
    expect(current.statusCode, anyOf(204, 404), reason: 'no plan');
    try {
      await generations.start();
      fail('a new generation was accepted');
    } on DioException catch (e) {
      log('6. nueva petición de generación → ${e.response?.statusCode} ${e.response?.data is Map ? (e.response!.data as Map)['details'] : ''}');
      expect(e.response?.statusCode, 422);
    }
    stdout.writeln('RETIRADA_CUENTA $email');
  }, skip: skip, timeout: const Timeout(Duration(minutes: 6)));
}
