import 'package:flutter/material.dart';

String? exerciseGifUrl(Object? path) {
  final value = path?.toString().trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value.replaceAll('\\', '/'));
  if (uri == null) return null;
  if (uri.hasScheme && uri.scheme != 'https' && uri.scheme != 'http') return null;
  if (uri.hasScheme && uri.host != 'github.com') return uri.toString();
  final name = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
  if (name == null || !name.toLowerCase().endsWith('.gif')) return null;
  return Uri.https('raw.githubusercontent.com', '/hasaneyldrm/exercises-dataset/main/videos/$name').toString();
}

class ExerciseMedia extends StatefulWidget {
  const ExerciseMedia({super.key, required this.gifPath, this.attribution});
  final Object? gifPath;
  final String? attribution;
  @override
  State<ExerciseMedia> createState() => _ExerciseMediaState();
}
class _ExerciseMediaState extends State<ExerciseMedia> {
  int attempt = 0;
  @override
  Widget build(BuildContext context) {
    final url = exerciseGifUrl(widget.gifPath);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (url == null) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Este ejercicio no tiene GIF disponible.'))
      else ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(
        url, key: ValueKey('$url-$attempt'), height: 220, width: double.infinity, fit: BoxFit.contain,
        // Public media is fetched separately from the authenticated API client.
        frameBuilder: (context, child, frame, synchronous) => frame != null || synchronous ? child : const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
        errorBuilder: (_, __, ___) => SizedBox(height: 140, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('No se pudo cargar el GIF.'), TextButton(onPressed: () async { await NetworkImage(url).evict(); if (mounted) setState(() => attempt++); }, child: const Text('Reintentar GIF'))]))),
      )),
    ]);
  }
}
