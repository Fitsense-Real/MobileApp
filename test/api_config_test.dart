import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/app/config_error_app.dart';
import 'package:fitsense_mobile/core/api/api_config.dart';

ApiConfig resolve(String defined, {bool release = true, bool web = false, TargetPlatform platform = TargetPlatform.android, bool allowInsecure = false}) =>
    ApiConfig.resolve(defined: defined, release: release, web: web, platform: platform, allowInsecure: allowInsecure);

void main() {
  group('development (debug/profile)', () {
    test('without API_BASE_URL: local backend, 10.0.2.2 on the Android emulator', () {
      expect(resolve('', release: false).baseUrl, 'http://10.0.2.2:8080/api/v1');
      expect(resolve('', release: false, web: true).baseUrl, 'http://localhost:8080/api/v1');
      expect(resolve('', release: false, platform: TargetPlatform.iOS).baseUrl, 'http://localhost:8080/api/v1');
    });
    test('an explicit URL is used as is, HTTP included (adb reverse, LAN)', () {
      expect(resolve('http://localhost:8080/api/v1', release: false).baseUrl, 'http://localhost:8080/api/v1');
    });
  });

  group('release (Google Play)', () {
    test('a public HTTPS URL is accepted', () {
      final c = resolve('https://backend.example.org/api/v1');
      expect(c.isValid, isTrue);
      expect(c.baseUrl, 'https://backend.example.org/api/v1');
    });
    test('without API_BASE_URL there is NO fallback to the emulator or localhost', () {
      final c = resolve('');
      expect(c.isValid, isFalse);
      expect(c.baseUrl, isEmpty);
      expect(c.problem, contains('API_BASE_URL'));
      expect(resolve('', web: true).baseUrl, isEmpty);
    });
    test('HTTP is refused', () {
      expect(resolve('http://backend.example.org/api/v1').isValid, isFalse);
    });
    test('local, emulator and private-network addresses are refused even with HTTPS', () {
      for (final host in ['10.0.2.2', 'localhost', '127.0.0.1', '192.168.1.20', '172.20.0.5', '10.1.2.3', 'kora.local', '169.254.1.1']) {
        expect(resolve('https://$host:8080/api/v1').isValid, isFalse, reason: host);
      }
      expect(resolve('https://172.32.0.1/api/v1').isValid, isTrue, reason: '172.32 is public');
    });
    test('malformed URLs are refused', () {
      expect(resolve('backend.example.org').isValid, isFalse);
      expect(resolve('https://').isValid, isFalse);
    });
    test('ALLOW_INSECURE_API only for explicit local evaluation builds', () {
      expect(resolve('http://localhost:8080/api/v1', web: true, allowInsecure: true).isValid, isTrue);
      expect(resolve('', allowInsecure: true).isValid, isFalse, reason: 'never without a URL');
    });
  });

  testWidgets('a release without a valid URL shows a configuration error, not the app', (tester) async {
    await tester.pumpWidget(const ConfigErrorApp(problem: 'Esta versión se compiló sin la dirección del servidor (API_BASE_URL).'));
    expect(find.text('Kora no está configurada'), findsOneWidget);
    expect(find.textContaining('API_BASE_URL'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: 'no login, no request');
  });
}
