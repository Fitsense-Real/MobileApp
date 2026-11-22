import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/providers/dio_provider.dart';

/// Result of telling the backend about this device's FCM registration token.
enum PushRegistration { registered, removed, backendNotReady, failed }

/// Associates the FCM **registration token** (from `FirebaseMessaging.getToken`,
/// what the backend needs to send a message) with the signed-in user. It is
/// not the Firebase Installation ID, which cannot be used to send messages.
///
/// The endpoints are a proposal for the backend (docs/push/). Until they exist
/// the backend answers 404/405/501: that is reported as [PushRegistration.backendNotReady]
/// and never breaks the app.
class PushDeviceRepository {
  PushDeviceRepository(this.dio);
  final Dio dio;

  static const _notReady = {404, 405, 501};

  /// Idempotent upsert by token: the backend keeps one row per token and
  /// moves it to this user if another account used the phone before.
  Future<PushRegistration> register({required String token, required String platform, String? appVersion, String? locale}) async {
    try {
      await dio.put(ApiConstants.pushDevices, data: {
        'token': token,
        'platform': platform,
        'appVersion': ?appVersion,
        'locale': ?locale,
      });
      return PushRegistration.registered;
    } on DioException catch (e) {
      return _notReady.contains(e.response?.statusCode) ? PushRegistration.backendNotReady : PushRegistration.failed;
    }
  }

  /// Before logging out: this phone stops receiving the account's messages.
  Future<PushRegistration> unregister(String token) async {
    try {
      await dio.delete(ApiConstants.pushDevice(token));
      return PushRegistration.removed;
    } on DioException catch (e) {
      return _notReady.contains(e.response?.statusCode) ? PushRegistration.backendNotReady : PushRegistration.failed;
    }
  }
}

final pushDeviceRepositoryProvider = Provider((ref) => PushDeviceRepository(ref.read(dioProvider)));
