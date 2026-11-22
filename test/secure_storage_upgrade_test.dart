import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/storage/secure_storage.dart';
import 'package:fitsense_mobile/core/storage/token_storage.dart';
import 'package:fitsense_mobile/features/reminders/domain/reminder_planner.dart';
import 'package:fitsense_mobile/features/reminders/presentation/reminders_controller.dart';
import 'package:fitsense_mobile/features/welcome/data/welcome_store.dart';

/// flutter_secure_storage 9.2.4 → 10.x. The native migration (old RSA/AES-CBC
/// data re-encrypted on first read) can only be exercised on a device; see
/// docs/preparacion_google_play/ACTUALIZACION_NOTIFICACIONES_ALMACENAMIENTO.md.
/// Here: the app asks for that migration, and keeps reading the same keys and
/// formats that earlier builds wrote, so nothing changes for the session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one storage for the whole app, with migration and a crash-safe backup', () {
    final android = appSecureStorage.aOptions.toMap();
    expect(android['migrateOnAlgorithmChange'], 'true', reason: '9.x data is re-encrypted, not dropped');
    expect(android['migrateWithBackup'], 'true', reason: 'a crash mid-migration must not lose the session');
    expect(android['encryptedSharedPreferences'], 'false', reason: 'never used by Kora; no Jetpack Security data to move');
  });

  test('values written by earlier builds (same keys and JSON) are read as they were', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'token-de-una-version-anterior',
      'kora_welcome_7': '{"tourStatus":"completed","tourStep":9,"operationId":"5b0c2f7e-0000-4000-8000-000000000001"}',
      'kora_reminders_7': '{"enabled":true,"hour":7,"minute":30,"dueWarning":false,"configured":true}',
    });
    expect(await TokenStorage.getToken(), 'token-de-una-version-anterior');
    expect(await TokenStorage.hasToken(), isTrue);
    final welcome = await WelcomeStore().load(7);
    expect(welcome.tourStatus, TourStatus.completed);
    expect(welcome.tourStep, 9);
    expect(welcome.operationId, '5b0c2f7e-0000-4000-8000-000000000001');
    expect(await const ReminderSettingsStore().load(7),
        const ReminderSettings(enabled: true, hour: 7, minute: 30, dueWarning: false, configured: true));
  });

  test('another user on the same phone does not see them', () async {
    FlutterSecureStorage.setMockInitialValues({'kora_welcome_7': '{"tourStatus":"completed","tourStep":9}'});
    expect((await WelcomeStore().load(8)).tourStatus, TourStatus.notStarted);
  });
}
