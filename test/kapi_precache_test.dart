import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/welcome/presentation/kapi_precache.dart';
import 'package:fitsense_mobile/shared/widgets/mascot/kora_mascot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Regression (E2E web, offline): the error screens showed no Kapi because
  // their SVG had never been downloaded before the connection dropped.
  test('every expression of Kapi is cached with the key SvgPicture.asset uses', () async {
    svg.cache.clear();
    await precacheKapi();
    expect(svg.cache.count, MascotMood.values.length);
    for (final mood in MascotMood.values) {
      final key = SvgAssetLoader(mood.asset).cacheKey(null);
      expect(svg.cache.evict(key), isTrue, reason: '${mood.name} cached');
    }
  });
}
