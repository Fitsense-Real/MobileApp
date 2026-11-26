import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/token_storage.dart';

/// Everything the app keeps on the phone for one account. Removed when the
/// account is deleted (or its deletion is accepted), so nothing of that
/// person stays on the device. Other accounts on the same phone are kept.
class LocalAccountData {
  const LocalAccountData([this._storage = appSecureStorage]);
  final FlutterSecureStorage _storage;

  static List<String> keysOf(int userId) => [
        'kora_welcome_$userId', // tour progress and first-plan operation
        'kora_reminders_$userId', // reminder settings
        'kora_favorites_$userId', // favourite workouts
        'kora_pending_results_$userId', // workout results not sent yet (PendingResultsStore)
      ];

  Future<void> clear(int userId) async {
    for (final key in keysOf(userId)) {
      await _storage.delete(key: key);
    }
    await TokenStorage.deleteToken();
  }
}
