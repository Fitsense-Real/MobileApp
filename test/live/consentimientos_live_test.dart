// Mobile-C1, live: the sign-up contract of option A against a running backend
// (Fitsense-Real/Backend `generation` 41c498a, B2 merged). Skipped unless
// KORA_LIVE_API_BASE_URL is set. Synthetic accounts and synthetic documents
// only; the backend must run with enforce-on-signup=true and the three
// synthetic documents published (docs/integracion_final_estudio/evidencia).
//
//   KORA_LIVE_API_BASE_URL=http://localhost:8080/api/v1 KORA_LIVE_PASSWORD=... KORA_LIVE_DOCS=si \
//   flutter test test/live/consentimientos_live_test.dart
//
// With KORA_LIVE_DOCS=no (backend without documents) only I-02 runs.
// Uses the app's real LegalDocumentsRepository, RegisterRequest,
// AuthRemoteDataSource, ConsentStatus and PlanGenerationRepository.
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/api_error.dart';
import 'package:fitsense_mobile/features/authentication/data/datasource/auth_remote_datasource.dart';
import 'package:fitsense_mobile/features/authentication/data/models/login_request.dart';
import 'package:fitsense_mobile/features/authentication/data/models/register_request.dart';
import 'package:fitsense_mobile/features/consents/data/consents_repository.dart';
import 'package:fitsense_mobile/features/consents/domain/legal_documents.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/domain/generation_operation.dart';

final env = Platform.environment;
final base = env['KORA_LIVE_API_BASE_URL'];
final docsMode = env['KORA_LIVE_DOCS'] ?? 'si';
final stamp = DateTime.now().millisecondsSinceEpoch;

void log(String line) => stdout.writeln('CONTRATO $line');

Dio plain([String? jwt]) => Dio(BaseOptions(baseUrl: base!, contentType: Headers.jsonContentType,
    headers: {'Accept': 'application/json', 'Authorization': ?(jwt == null ? null : 'Bearer $jwt')}));

final auth = AuthRemoteDataSource(plain());

RegisterRequest request(String tag, {bool participates = true, String? terms, String? privacy, String? study}) => RegisterRequest(
      firstName: 'Contrato', lastName: tag, email: 'audit-contrato-$tag-$stamp@audit.local', password: env['KORA_LIVE_PASSWORD']!,
      acceptsStudyParticipation: participates, acceptedTermsVersion: terms, acceptedPrivacyVersion: privacy, acceptedStudyConsentVersion: study);

Future<String?> loginOf(String email) async {
  try {
    return (await auth.login(LoginRequest(email: email, password: env['KORA_LIVE_PASSWORD']!))).token;
  } on ApiException catch (e) {
    if (e.statusCode == 401) return null;
    rethrow;
  }
}

void main() {
  final skip = base == null ? 'KORA_LIVE_API_BASE_URL not set (needs a running backend)' : false;
  late PublishedDocuments docs;

  test('I-02 · no documents published: nothing to accept, sign-up stays closed in the app', () async {
    docs = await LegalDocumentsRepository(plain()).current();
    log('I-02 GET /legal-documents → enforcedOnSignup=${docs.enforcedOnSignup}, ${docs.documents.length} documentos, registro ${docs.signUpOpen ? 'ABIERTO' : 'cerrado'}');
    expect(docs.documents, isEmpty);
    expect(docs.signUpOpen, isFalse, reason: 'no informed consent: no valid acceptance possible');
  }, skip: skip == false && docsMode != 'no' ? 'backend with documents' : skip);

  group('with the synthetic documents published and enforcement on', () {
    setUpAll(() async {
      if (base == null || docsMode == 'no') return;
      docs = await LegalDocumentsRepository(plain()).current();
    });

    test('I-01 · published documents: the three types, their versions and addresses', () async {
      log('I-01 GET /legal-documents → enforcedOnSignup=${docs.enforcedOnSignup}, privacyRecord=${docs.privacyRecord.name}, '
          '${[for (final d in docs.toRead) '${d.type.code}=${d.version}'].join(', ')}');
      expect(docs.enforcedOnSignup, isTrue);
      expect([for (final d in docs.toRead) d.type], [ConsentType.termsOfService, ConsentType.privacyPolicy, ConsentType.studyParticipation]);
      expect(docs.toRead.every((d) => d.url.startsWith('https://')), isTrue);
      expect(docs.signUpOpen, isTrue);
    });

    Future<void> refused(String id, RegisterRequest r, bool Function(Object?) kind) async {
      try {
        await auth.register(r);
        fail('$id: the account was created');
      } on ApiException catch (e) {
        log('$id POST /auth/register → ${e.statusCode} «${e.message}»');
        expect(e.statusCode, 422);
        expect(kind(e.message), isTrue, reason: e.message);
      }
      expect(await loginOf(r.email), isNull, reason: '$id: no partial account');
      log('$id login con ese correo → 401 (no quedó ninguna cuenta)');
    }

    test('I-05 · wrong terms version: refused, no account', () async {
      await refused('I-05', request('i05', terms: 'T-QA-0', privacy: docs.privacy!.version, study: docs.studyConsent!.version), isOutdatedDocument);
    });

    test('I-06 · wrong privacy version: refused, no account', () async {
      await refused('I-06', request('i06', terms: docs.terms!.version, privacy: 'P-QA-0', study: docs.studyConsent!.version), isOutdatedDocument);
    });

    test('I-07 · acceptedStudyConsentVersion missing while required: refused, no account', () async {
      await refused('I-07', request('i07', terms: docs.terms!.version, privacy: docs.privacy!.version), isMissingDocument);
    });

    test('I-08 · wrong study consent version: refused, no account', () async {
      await refused('I-08', request('i08', terms: docs.terms!.version, privacy: docs.privacy!.version, study: 'C-QA-0'), isOutdatedDocument);
    });

    test('I-04 / I-09 · valid versions: account created; the history has exactly what was read', () async {
      final r = request('i04', terms: docs.terms!.version, privacy: docs.privacy!.version, study: docs.studyConsent!.version);
      final user = await auth.register(r);
      log('I-04 POST /auth/register ${r.toJson()..remove('password')} → 201, studyParticipant=${user.studyParticipant}');
      expect(user.studyParticipant, isTrue);
      final jwt = (await loginOf(r.email))!;
      final status = await ConsentsRepository(plain(jwt)).status();
      for (final type in ConsentType.values) {
        final row = status.accepted(type)!;
        log('I-09 historial ${type.code}: versión ${row.version}, ${row.affirmativeAction}, ${row.grantedAt}');
        expect(row.version, docs.of(type)!.version);
        expect(row.affirmativeAction, 'CASILLA_REGISTRO', reason: 'acceptance with the version shown, not a label');
        expect(row.withoutApprovedDocument, isFalse);
      }
      expect(status.pendingDocuments, isEmpty);
    });

    test('I-10 · account without participation (only possible through the API): no plan', () async {
      final r = request('i10', participates: false, terms: docs.terms!.version, privacy: docs.privacy!.version);
      final user = await auth.register(r);
      final jwt = (await loginOf(r.email))!;
      await plain(jwt).post('/users/me/profile', data: profile);
      try {
        final op = await PlanGenerationRepository(plain(jwt)).start();
        log('I-10 POST /users/me/plan/generation → ${op.status} ${op.reasonCode ?? ''} ${op.message ?? ''}');
        expect(op.isTerminal && op.status != GenerationStatus.completed, isTrue, reason: 'never a plan for a non-participant');
      } on DioException catch (e) {
        log('I-10 POST /users/me/plan/generation → ${e.response?.statusCode} «${apiError(e)}»');
        expect(e.response?.statusCode, anyOf(403, 409, 422));
      }
      log('I-10 registro sin participar por la API → 201 (studyParticipant=${user.studyParticipant}); la app no ofrece este camino');
      expect(user.studyParticipant, isFalse);
    });

    late String participantJwt;
    test('I-11 · active participant: profile and first plan by the rules engine', () async {
      final r = request('i11', terms: docs.terms!.version, privacy: docs.privacy!.version, study: docs.studyConsent!.version);
      await auth.register(r);
      participantJwt = (await loginOf(r.email))!;
      await plain(participantJwt).post('/users/me/profile', data: profile);
      final generations = PlanGenerationRepository(plain(participantJwt));
      var op = await generations.start();
      for (var i = 0; i < 60 && !op.isTerminal; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        op = (await generations.find(op.id))!;
      }
      log('I-11 generación ${op.id} → ${op.status}, plan ${op.planId}');
      expect(op.status, GenerationStatus.completed);
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('I-14 · generation again while a plan exists: the same plan, nothing overwritten', () async {
      final dio = plain(participantJwt);
      final before = (await dio.get('/users/me/plan/current')).data['planId'];
      final answers = await Future.wait([for (var i = 0; i < 2; i++) dio.post('/users/me/plan/generation', options: Options(validateStatus: (_) => true))]);
      for (final a in answers) {
        log('I-14 POST /users/me/plan/generation (simultáneo) → ${a.statusCode} ${a.data is Map ? (a.data['status'] ?? a.data['message']) : ''}');
        expect(a.statusCode, anyOf(200, 202, 409, 422), reason: '${a.data}');
      }
      final after = (await dio.get('/users/me/plan/current')).data['planId'];
      log('I-14 plan actual antes $before, después $after');
      expect(after, before, reason: 'an existing plan is never replaced by a repeated request');
    });

    test('I-12 · withdrawn participant: no new plan, withdrawal recorded, not reactivated', () async {
      final r = request('i12', terms: docs.terms!.version, privacy: docs.privacy!.version, study: docs.studyConsent!.version);
      await auth.register(r);
      final jwt = (await loginOf(r.email))!;
      await plain(jwt).post('/users/me/profile', data: profile);
      final withdrawn = await AuthRemoteDataSource(plain(jwt)).withdraw();
      log('I-12 POST /users/me/withdraw → withdrawnAt=${withdrawn.withdrawnAt}');
      expect(withdrawn.withdrawnAt, isNotNull);
      try {
        final op = await PlanGenerationRepository(plain(jwt)).start();
        log('I-12 POST /users/me/plan/generation → ${op.status} ${op.reasonCode ?? ''} ${op.message ?? ''}');
        expect(op.status, isNot(GenerationStatus.completed));
      } on DioException catch (e) {
        log('I-12 POST /users/me/plan/generation → ${e.response?.statusCode} «${apiError(e)}»');
        expect(e.response?.statusCode, anyOf(403, 409, 422));
      }
      final status = await ConsentsRepository(plain(jwt)).status();
      log('I-12 historial: STUDY_PARTICIPATION retirado=${status.history.firstWhere((h) => h.type == ConsentType.studyParticipation).withdrawnAt != null}');
      expect(status.accepted(ConsentType.studyParticipation), isNull, reason: 'withdrawn, never reactivated by the app');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('I-13 · 429 after repeated wrong passwords: message and how long to wait', () async {
      final r = request('i13', terms: docs.terms!.version, privacy: docs.privacy!.version, study: docs.studyConsent!.version);
      await auth.register(r);
      ApiException? last;
      for (var i = 0; i < 8; i++) {
        try {
          await auth.login(LoginRequest(email: r.email, password: 'clave-incorrecta-$i'));
        } on ApiException catch (e) {
          last = e;
          if (e.statusCode == 429) break;
        }
      }
      log('I-13 login con clave incorrecta repetida → ${last?.statusCode} «${last?.message}»');
      expect(last?.statusCode, 429);
      expect(last!.message, isNot(contains('DEMASIADAS_SOLICITUDES')));
      expect(last.message, contains('Podrás intentarlo de nuevo'));
    });
  }, skip: skip == false && docsMode == 'no' ? 'backend without documents' : skip);
}

const profile = {
  'birthDate': '1990-05-05', 'heightCm': 170, 'currentWeightKg': 70, 'fitnessLevel': 'BEGINNER', 'goalType': 'GENERAL_FITNESS',
  'goalText': 'Constancia', 'trainingLocation': 'HOME', 'daysPerWeek': 3, 'availableDays': [1, 3, 5], 'sessionMinutes': 45,
  'equipmentCodes': ['body weight'], 'blockedExerciseIds': [],
};
