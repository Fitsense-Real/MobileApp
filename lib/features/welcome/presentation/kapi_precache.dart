import 'package:flutter_svg/flutter_svg.dart';
import '../../../shared/widgets/mascot/kora_mascot.dart';

/// Loads every expression of Kapi into flutter_svg's cache.
///
/// On the web each asset is downloaded the first time it is shown: if the
/// connection drops during the tour, the "no connection" and error screens
/// would appear without Kapi. With no [DefaultSvgTheme] in the tree the cache
/// key is the same one [SvgPicture.asset] uses, so they render from memory.
/// On Android and iOS the assets are bundled and this only saves a parse.
Future<void> precacheKapi() => Future.wait([
      for (final mood in MascotMood.values)
        SvgAssetLoader(mood.asset).loadBytes(null).then((_) {}, onError: (Object _) {}),
    ]);
