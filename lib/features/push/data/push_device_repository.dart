import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/providers/dio_provider.dart';

/// Push device registration and notification preferences.
///
/// Contract: Fitsense-Real/Backend PR #82 (`CONTRATO_PUSH_MOBILE.md`,
/// `EJEMPLOS_REALES_HTTP.md`). The identifier is the **Firebase Installation
/// ID** (FID) that `FirebaseMessaging.onRegistered` provides; the backend
/// rejects FCM registration tokens. Every request carries the current JWT
/// (AuthInterceptor); the base URL already ends in `/api/v1`.
class PushDeviceRepository {
  PushDeviceRepository(this.dio);
  final Dio dio;

  /// The only `appId` the backend accepts. Must equal the Android
  /// applicationId (android/app/build.gradle.kts).
  static const appId = 'pe.fit.kora';
  static const platform = 'ANDROID';

  /// `^[A-Za-z0-9_-]{16,64}$`, as validated by the backend. An FCM
  /// registration token (with `:` and 150+ characters) never matches.
  static bool isInstallationId(String? value) => value != null && RegExp(r'^[A-Za-z0-9_-]{16,64}$').hasMatch(value);

  /// `PUT /users/me/push-devices`: register or renew this installation
  /// (idempotent: 201 the first time, 200 afterwards). The same FID used by
  /// another account moves to this one; the backend revokes the old link.
  Future<PushDeviceResult> register({required String installationId, String? appVersion}) async {
    final body = {'installationId': installationId, 'platform': platform, 'appId': appId, 'appVersion': ?appVersion};
    for (var attempt = 1;; attempt++) {
      try {
        final response = await dio.put(ApiConstants.pushDevices, data: body);
        final data = response.data;
        return PushDeviceResult(
          PushDeviceStatus.registered,
          device: data is Map ? PushDevice.fromJson(data.cast<String, dynamic>()) : null,
          created: response.statusCode == 201,
        );
      } on DioException catch (e) {
        // Two simultaneous PUTs of the same FID: the contract says retry once.
        if (e.response?.statusCode == 409 && attempt == 1) continue;
        return PushDeviceResult.fromError(e);
      }
    }
  }

  /// `DELETE /users/me/push-devices` with `{"installationId": "<FID>"}`
  /// (idempotent, 204). Called before the JWT is deleted at logout. A 401 here
  /// (account already deleted, session already over) is not a new session
  /// expiry: it must not start another logout.
  Future<PushDeviceResult> unregister(String installationId) async {
    try {
      await dio.delete(
        ApiConstants.pushDevices,
        data: {'installationId': installationId},
        options: Options(extra: const {AuthInterceptor.quietUnauthorized: true}),
      );
      return const PushDeviceResult(PushDeviceStatus.removed);
    } on DioException catch (e) {
      return PushDeviceResult.fromError(e);
    }
  }

  /// `GET /users/me/push-devices`: active devices of the account (the full
  /// FID never comes back, only a 4-character hint).
  Future<List<PushDevice>> devices() async {
    final response = await dio.get(ApiConstants.pushDevices);
    final data = response.data;
    return data is List ? [for (final d in data) if (d is Map) PushDevice.fromJson(d.cast<String, dynamic>())] : const [];
  }

  /// `GET /users/me/notification-preferences`.
  Future<NotificationPreferences> preferences() async {
    final response = await dio.get(ApiConstants.notificationPreferences);
    return NotificationPreferences.fromJson((response.data as Map).cast<String, dynamic>());
  }

  /// `PUT /users/me/notification-preferences`: both fields are required.
  Future<NotificationPreferences> savePreferences(NotificationPreferences preferences) async {
    final response = await dio.put(ApiConstants.notificationPreferences, data: preferences.toJson());
    return NotificationPreferences.fromJson((response.data as Map).cast<String, dynamic>());
  }
}

enum PushDeviceStatus {
  /// 200/201: this phone receives the account's notifications.
  registered,

  /// 204: unlinked.
  removed,

  /// 400: the backend refused the data ([PushDeviceResult.code] says why).
  rejected,

  /// 401: no valid session (the app's session handling takes over).
  unauthorized,

  /// No connection, timeout or 5xx: try again on the next start.
  unavailable,

  /// 404/405/501: a backend without the push endpoints.
  backendNotReady,
}

class PushDeviceResult {
  const PushDeviceResult(this.status, {this.code, this.device, this.created = false});

  factory PushDeviceResult.fromError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final details = data is Map ? data['details'] : null;
    final code = details is List && details.isNotEmpty ? '${details.first}' : null;
    return switch (status) {
      400 => PushDeviceResult(PushDeviceStatus.rejected, code: code),
      401 => const PushDeviceResult(PushDeviceStatus.unauthorized),
      404 || 405 || 501 => const PushDeviceResult(PushDeviceStatus.backendNotReady),
      _ => const PushDeviceResult(PushDeviceStatus.unavailable),
    };
  }

  final PushDeviceStatus status;

  /// Machine code from `details[0]`, e.g. `IDENTIFICADOR_PUSH_INVALIDO`.
  final String? code;
  final PushDevice? device;

  /// 201 (first registration) rather than 200 (renewal).
  final bool created;
}

/// `Dispositivo` of the contract.
class PushDevice {
  const PushDevice({required this.deviceId, this.installationIdHint, this.platform, this.appVersion, this.receivesNotifications = true});

  factory PushDevice.fromJson(Map<String, dynamic> json) => PushDevice(
    deviceId: (json['deviceId'] as num?)?.toInt() ?? 0,
    installationIdHint: json['installationIdHint'] as String?,
    platform: json['platform'] as String?,
    appVersion: json['appVersion'] as String?,
    receivesNotifications: json['receivesNotifications'] != false,
  );

  final int deviceId;
  final String? installationIdHint;
  final String? platform;
  final String? appVersion;

  /// False after a password change until this phone registers again.
  final bool receivesNotifications;
}

/// `Preferencias` of the contract. Applied by the backend when sending.
class NotificationPreferences {
  const NotificationPreferences({required this.planUpdates, required this.accountNotices});

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(planUpdates: json['planUpdates'] != false, accountNotices: json['accountNotices'] != false);

  /// PLAN_GENERATED, PLAN_ADAPTED and WEEKLY_PLAN_READY.
  final bool planUpdates;

  /// ACCOUNT_NOTICE.
  final bool accountNotices;

  NotificationPreferences copyWith({bool? planUpdates, bool? accountNotices}) =>
      NotificationPreferences(planUpdates: planUpdates ?? this.planUpdates, accountNotices: accountNotices ?? this.accountNotices);

  Map<String, dynamic> toJson() => {'planUpdates': planUpdates, 'accountNotices': accountNotices};

  @override
  bool operator ==(Object other) => other is NotificationPreferences && other.planUpdates == planUpdates && other.accountNotices == accountNotices;

  @override
  int get hashCode => Object.hash(planUpdates, accountNotices);
}

final pushDeviceRepositoryProvider = Provider((ref) => PushDeviceRepository(ref.read(dioProvider)));
