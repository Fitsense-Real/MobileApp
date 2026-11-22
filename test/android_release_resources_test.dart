import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Android resources a Google Play build depends on. They cannot be seen in
/// debug (no resource shrinker), so a mistake here only shows up in release.
void main() {
  const res = 'android/app/src/main/res';
  String read(String path) => File(path).readAsStringSync();

  test('launcher icon: adaptive on Android 8+, with a themed (monochrome) layer', () {
    expect(read('android/app/src/main/AndroidManifest.xml'), contains('android:icon="@mipmap/ic_launcher"'));
    final adaptive = read('$res/mipmap-anydpi-v26/ic_launcher.xml');
    expect(adaptive, contains('<background android:drawable="@color/kora_icon_background"'));
    expect(adaptive, contains('<foreground android:drawable="@drawable/ic_launcher_foreground"'));
    expect(adaptive, contains('<monochrome android:drawable="@drawable/ic_launcher_monochrome"'));
    expect(read('$res/values/kora_colors.xml'), contains('<color name="kora_icon_background">#D9FF59</color>'));
  });

  test('Android 7.x PNG icons are Kora artwork, not the Flutter template', () {
    for (final (density, size) in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]) {
      final png = File('$res/mipmap-$density/ic_launcher.png').readAsBytesSync();
      final width = png[16] << 24 | png[17] << 16 | png[18] << 8 | png[19];
      expect(width, size, reason: density);
      expect(png[25], 6, reason: '$density: RGBA, with transparent corners (the template is an 8-bit palette)');
    }
  });

  test('notification icon: monochrome, named from Dart and kept by the release shrinker', () {
    final icon = read('$res/drawable/ic_stat_kora.xml');
    expect(icon, contains('#FFFFFFFF'));
    expect(icon, isNot(contains('#D9FF59')), reason: 'a small icon is drawn as a silhouette: no coloured square');
    expect(read('$res/raw/keep.xml'), contains('tools:keep="@drawable/ic_stat_kora"'));
    expect(read('lib/features/reminders/data/reminder_scheduler.dart'), contains("AndroidInitializationSettings('ic_stat_kora')"));
  });

  test('release guard is still there (HTTPS backend, Play bundle requirements)', () {
    final gradle = read('android/app/build.gradle.kts');
    for (final rule in [
      'API_BASE_URL debe usar https:// en release',
      'no puede ser una direccion local o del emulador en release',
      'Falta android/key.properties',
      'applicationId de ejemplo',
      'La eliminacion de cuenta esta desactivada',
      'PRIVACY_POLICY_URL',
    ]) {
      expect(gradle, contains(rule));
    }
    expect(gradle, contains('targetSdk = 36'));
  });
}
