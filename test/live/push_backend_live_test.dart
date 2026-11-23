// Live check of the Mobile push code against a running backend (Fitsense-Real/Backend
// PR #82). Skipped unless KORA_LIVE_API_BASE_URL is set, so `flutter test` and the CI
// never need a backend. Synthetic accounts only; see docs/push/PRUEBAS_PUSH_E_IDENTIFICADOR.md.
//
//   KORA_LIVE_API_BASE_URL=http://localhost:8080/api/v1 KORA_LIVE_EMAIL_A=... KORA_LIVE_EMAIL_B=... \
//   KORA_LIVE_PASSWORD=... KORA_LIVE_FID=... flutter test test/live/push_backend_live_test.dart
//
// Leaves account A registered with KORA_LIVE_FID, so the next step can generate a plan and
// look for the PLAN_GENERATED event of that FID in PostgreSQL.
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/push/data/push_device_repository.dart';

final env = Platform.environment;
final base = env['KORA_LIVE_API_BASE_URL'];

Future<String> login(String email) async {
  final response = await Dio(BaseOptions(baseUrl: base!)).post('/auth/login', data: {'email': email, 'password': env['KORA_LIVE_PASSWORD']});
  return response.data['token'] as String;
}

/// The same base options as the app's DioClient; the JWT header is what AuthInterceptor adds.
PushDeviceRepository repositoryFor(String? jwt) => PushDeviceRepository(Dio(BaseOptions(
  baseUrl: base!,
  contentType: Headers.jsonContentType,
  headers: {'Accept': 'application/json', 'Authorization': ?(jwt == null ? null : 'Bearer $jwt')},
)));

void main() {
  test('Mobile push code against the real backend contract', () async {
    final fid = env['KORA_LIVE_FID']!;
    final a = repositoryFor(await login(env['KORA_LIVE_EMAIL_A']!));
    final b = repositoryFor(await login(env['KORA_LIVE_EMAIL_B']!));

    // 1. Registration after login: 201, then 200 on every later start (renewal).
    final first = await a.register(installationId: fid, appVersion: '1.0.0+1');
    expect(first.status, PushDeviceStatus.registered);
    expect(first.created, isTrue);
    expect(first.device!.installationIdHint, '${fid.substring(0, 4)}…', reason: 'the full FID never comes back');
    final renewal = await a.register(installationId: fid, appVersion: '1.0.0+1');
    expect(renewal.created, isFalse);
    expect(renewal.device!.deviceId, first.device!.deviceId);
    expect((await a.devices()).single.receivesNotifications, isTrue);

    // 2. Preferences: defaults, save, restore.
    expect(await a.preferences(), const NotificationPreferences(planUpdates: true, accountNotices: true));
    expect(await a.savePreferences(const NotificationPreferences(planUpdates: false, accountNotices: true)),
        const NotificationPreferences(planUpdates: false, accountNotices: true));
    expect(await a.savePreferences(const NotificationPreferences(planUpdates: true, accountNotices: true)),
        const NotificationPreferences(planUpdates: true, accountNotices: true));

    // 3. Refusals the app must understand.
    final token = await a.register(installationId: 'dXy7:APA91b${'x' * 150}');
    expect((token.status, token.code), (PushDeviceStatus.rejected, 'IDENTIFICADOR_PUSH_INVALIDO'));
    expect((await repositoryFor(null).register(installationId: fid)).status, PushDeviceStatus.unauthorized);

    // 4. Another account on the same phone takes the FID; A stops receiving.
    expect((await b.register(installationId: fid)).status, PushDeviceStatus.registered);
    expect(await a.devices(), isEmpty);

    // 5. Logout of B: DELETE with the FID in the body, idempotent.
    expect((await b.unregister(fid)).status, PushDeviceStatus.removed);
    expect((await b.unregister(fid)).status, PushDeviceStatus.removed);
    expect(await b.devices(), isEmpty);

    // 6. A signs in again on this phone and stays registered for the plan step.
    expect((await a.register(installationId: fid, appVersion: '1.0.0+1')).status, PushDeviceStatus.registered);
    expect(await a.devices(), hasLength(1));
  }, skip: base == null ? 'KORA_LIVE_API_BASE_URL not set (needs a running backend)' : false);
}
