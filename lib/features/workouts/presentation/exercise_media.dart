import 'package:material_ui/material_ui.dart';
import '../../../core/api/json.dart';

/// Whether the app may still build media addresses from the catalog paths
/// (third-party dataset on GitHub, `hasaneyldrm/exercises-dataset`). Kept on
/// so nothing changes until the backend serves authorised addresses
/// (`gifUrl`/`imageUrl`, proposal of the backend's MATRIZ_CONTRATOS_API) and
/// the licence is confirmed (M-06). `--dart-define=EXERCISE_MEDIA_LEGACY_SOURCE=false`
/// shows only authorised addresses.
const legacyMediaSource = bool.fromEnvironment('EXERCISE_MEDIA_LEGACY_SOURCE', defaultValue: true);

String? _legacyUrl(Object? path, String folder, String extension) {
  final value = path?.toString().trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value.replaceAll('\\', '/'));
  if (uri == null) return null;
  if (uri.hasScheme && uri.scheme != 'https' && uri.scheme != 'http') return null;
  if (uri.hasScheme && uri.host != 'github.com') return uri.toString();
  final name = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
  if (name == null || !name.toLowerCase().endsWith(extension)) return null;
  return Uri.https('raw.githubusercontent.com', '/hasaneyldrm/exercises-dataset/main/$folder/$name').toString();
}

/// Address of the animation built from a catalog `gifPath` (current source).
String? exerciseGifUrl(Object? path) => _legacyUrl(path, 'videos', '.gif');

/// Address of the still image built from a catalog `imagePath` (current source).
String? exerciseImageUrl(Object? path) => _legacyUrl(path, 'images', '.jpg');

String? _authorised(Object? value) {
  final uri = Uri.tryParse('${value ?? ''}'.trim());
  return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty ? uri.toString() : null;
}

/// Animation, still image and attribution of an exercise: authorised
/// addresses from the backend first, the current construction otherwise.
class ExerciseMediaSource {
  const ExerciseMediaSource({this.gifUrl, this.imageUrl, this.attribution});
  final String? gifUrl, imageUrl, attribution;

  factory ExerciseMediaSource.of(Json exercise, {bool legacy = legacyMediaSource}) => ExerciseMediaSource(
        gifUrl: _authorised(exercise['gifUrl']) ?? (legacy ? exerciseGifUrl(exercise['gifPath']) : null),
        imageUrl: _authorised(exercise['imageUrl']) ?? (legacy ? exerciseImageUrl(exercise['imagePath']) : null),
        attribution: (exercise['mediaAttribution'] as String?)?.trim().isEmpty == true ? null : exercise['mediaAttribution'] as String?,
      );

  bool get isEmpty => gifUrl == null && imageUrl == null;
}

/// The exercise animation. Paused with [paused] (and by Flutter itself when
/// the system asks to reduce motion). If the animation cannot be loaded it
/// falls back to the still image of the same exercise, then to a text.
class ExerciseMedia extends StatefulWidget {
  const ExerciseMedia({super.key, required this.source, this.height = 220, this.paused = false, this.showAttribution = false, this.onTap});
  final ExerciseMediaSource source;
  final double height;
  final bool paused;
  final bool showAttribution;
  final VoidCallback? onTap;
  @override
  State<ExerciseMedia> createState() => _ExerciseMediaState();
}

class _ExerciseMediaState extends State<ExerciseMedia> {
  int attempt = 0;
  bool gifFailed = false, imageFailed = false;

  Future<void> retry() async {
    for (final url in [widget.source.gifUrl, widget.source.imageUrl]) {
      if (url != null) await NetworkImage(url).evict();
    }
    if (mounted) setState(() { attempt++; gifFailed = false; imageFailed = false; });
  }

  // Minimum height only: with large text the message grows instead of overflowing.
  Widget _message(String text) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: widget.height * .64),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
          if (!widget.source.isEmpty) TextButton(onPressed: retry, child: const Text('Reintentar')),
        ])),
      );

  Widget _image(String url, {required bool still}) => Image.network(
        url, key: ValueKey('$url-$attempt'), height: widget.height, width: double.infinity, fit: BoxFit.contain,
        // Accessibility: the media only illustrates what the card already says
        // in text, so screen readers do not announce the card as an image.
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, synchronous) => frame != null || synchronous
            ? child
            : SizedBox(height: widget.height, child: const Center(child: ExcludeSemantics(child: CircularProgressIndicator()))),
        errorBuilder: (_, __, ___) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => still ? imageFailed = true : gifFailed = true);
          });
          return SizedBox(height: widget.height);
        },
      );

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final Widget body;
    if (source.isEmpty) {
      body = _message('Este ejercicio no tiene animación disponible.');
    } else if (source.gifUrl != null && !gifFailed) {
      body = TickerMode(enabled: !widget.paused, child: _image(source.gifUrl!, still: false));
    } else if (source.imageUrl != null && !imageFailed) {
      body = Column(children: [
        _image(source.imageUrl!, still: true),
        if (source.gifUrl != null) ...[
          const Text('No se pudo cargar la animación; se muestra la imagen del ejercicio.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
          TextButton(onPressed: retry, child: const Text('Reintentar animación')),
        ],
      ]);
    } else {
      body = _message('No se pudo cargar la imagen del ejercicio. Revisa tu conexión.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: widget.onTap == null ? body : InkWell(onTap: widget.onTap, child: body),
      ),
      if (widget.showAttribution && source.attribution != null)
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(source.attribution!, style: const TextStyle(fontSize: 12, color: Color(0xFF5E7865)))),
    ]);
  }
}
