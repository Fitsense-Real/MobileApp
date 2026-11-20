import 'package:flutter/foundation.dart';

/// Where the app finds the Kora backend, by build mode.
///
/// - **debug/profile** (development): `--dart-define=API_BASE_URL=...`, or the
///   local backend by default (`10.0.2.2` on the Android emulator,
///   `localhost` elsewhere). Plain HTTP is allowed.
/// - **release** (Google Play): `API_BASE_URL` is mandatory and must be a
///   public `https://` URL. There is no fallback: without a valid URL the app
///   shows a configuration error instead of connecting anywhere. Android
///   release builds are also stopped by Gradle (`android/app/build.gradle.kts`).
///   `ALLOW_INSECURE_API=true` lifts the HTTPS rule only for local evaluation
///   builds (web against a local backend); Gradle never accepts it.
class ApiConfig {
  const ApiConfig._(this.baseUrl, this.problem);

  /// Base URL (`.../api/v1`); empty when [problem] is not null.
  final String baseUrl;

  /// Why there is no usable URL in this build, for the person installing it.
  final String? problem;

  bool get isValid => problem == null;

  static const _defined = String.fromEnvironment('API_BASE_URL');
  static const _allowInsecure = bool.fromEnvironment('ALLOW_INSECURE_API');

  /// The configuration of this build.
  static final ApiConfig current = resolve(
    defined: _defined,
    release: kReleaseMode,
    web: kIsWeb,
    platform: defaultTargetPlatform,
    allowInsecure: _allowInsecure,
  );

  /// Pure resolution, so every case can be tested.
  static ApiConfig resolve({
    required String defined,
    required bool release,
    required bool web,
    required TargetPlatform platform,
    bool allowInsecure = false,
  }) {
    final value = defined.trim();
    if (!release) {
      if (value.isNotEmpty) return ApiConfig._(value, null);
      final local = !web && platform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
      return ApiConfig._('http://$local:8080/api/v1', null);
    }
    if (value.isEmpty) {
      return const ApiConfig._('', 'Esta versión se compiló sin la dirección del servidor (API_BASE_URL).');
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return ApiConfig._('', 'La dirección del servidor no es válida: $value');
    }
    if (allowInsecure) return ApiConfig._(value, null);
    if (uri.scheme != 'https') {
      return ApiConfig._('', 'La versión publicada solo se conecta por HTTPS: $value');
    }
    if (isLocalHost(uri.host)) {
      return ApiConfig._('', 'La versión publicada no puede usar una dirección local: ${uri.host}');
    }
    return ApiConfig._(value, null);
  }

  /// Emulator, loopback, private networks and reserved local names.
  static bool isLocalHost(String host) {
    final h = host.toLowerCase();
    if (h == 'localhost' || h.endsWith('.localhost') || h.endsWith('.local') || h == '0.0.0.0' || h == '::1' || h == '[::1]') return true;
    final ip = RegExp(r'^(\d+)\.(\d+)\.(\d+)\.(\d+)$').firstMatch(h);
    if (ip == null) return false;
    final a = int.parse(ip.group(1)!), b = int.parse(ip.group(2)!);
    return a == 127 || a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31) || (a == 169 && b == 254) || a == 0;
  }
}
