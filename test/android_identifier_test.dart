import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/push/data/push_notifier.dart';

/// Kora's definitive Android identity (pe.fit.kora, Firebase kora-fitpe) and
/// the push configuration Android uses while the app is in the background.
void main() {
  String read(String path) => File(path).readAsStringSync();
  final gradle = read('android/app/build.gradle.kts');

  test('pe.fit.kora is the default application ID and the namespace; no example IDs left', () {
    expect(gradle, contains('val approvedApplicationId = "pe.fit.kora"'));
    expect(gradle, contains('?: approvedApplicationId'));
    expect(gradle, contains('namespace = "pe.fit.kora"'));
    expect(gradle, isNot(contains('com.example.fitsense_mobile')));
    expect(read('android/app/src/main/kotlin/pe/fit/kora/MainActivity.kt'), startsWith('package pe.fit.kora'));
    expect(Directory('android/app/src/main/kotlin/com').existsSync(), isFalse);
  });

  test('the Play bundle only accepts the approved ID and its Firebase configuration', () {
    expect(gradle, contains('applicationId de ejemplo'), reason: 'com.example.* stays blocked');
    expect(gradle, contains('distinto del aprobado para Kora'));
    expect(gradle, contains('Falta android/app/google-services.json'));
    expect(gradle, contains('no contiene la app Android'));
    expect(gradle, contains('JavaVersion.VERSION_21'), reason: 'release lint needs JDK 21; fail with a clear message, never skip lint');
    expect(gradle, isNot(contains('checkReleaseBuilds = false')));
    expect(gradle, isNot(contains('abortOnError = false')));
    expect(gradle, contains('if (hasGoogleServices) apply(plugin = "com.google.gms.google-services")'));
    expect(read('android/settings.gradle.kts'), contains('id("com.google.gms.google-services") version'));
  });

  test('background push uses Kora\'s monochrome icon and the channel the app creates', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');
    expect(manifest, contains('com.google.firebase.messaging.default_notification_icon'));
    expect(manifest, contains('android:resource="@drawable/ic_stat_kora"'));
    expect(manifest, contains('android:value="${LocalPushNotifier.channelId}"'));
  });

  test('no Firebase admin credentials or temporary files are versioned', () {
    final tracked = Process.runSync('git', ['ls-files']).stdout as String;
    for (final forbidden in ['firebase-adminsdk', 'service-account', 'serviceAccount', '.firebase/', 'firebase-debug.log']) {
      expect(tracked.contains(forbidden), isFalse, reason: forbidden);
    }
  });
}
