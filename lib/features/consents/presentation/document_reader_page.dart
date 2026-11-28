import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../data/document_text_repository.dart';
import '../domain/legal_documents.dart';

/// Shows a legal document complete, inside the app, before it can be
/// accepted. Pops `true` when the person reached the end of the text.
class DocumentReaderPage extends ConsumerStatefulWidget {
  const DocumentReaderPage({super.key, required this.document});
  final LegalDocument document;

  static Future<bool> open(BuildContext context, LegalDocument document) async =>
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => DocumentReaderPage(document: document))) ?? false;

  @override
  ConsumerState<DocumentReaderPage> createState() => _DocumentReaderPageState();
}

class _DocumentReaderPageState extends ConsumerState<DocumentReaderPage> {
  String? text, error;
  bool reachedEnd = false;
  final scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    load();
    scroll.addListener(_checkEnd);
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void _checkEnd() {
    if (!reachedEnd && scroll.hasClients && scroll.position.pixels >= scroll.position.maxScrollExtent - 24) setState(() => reachedEnd = true);
  }

  Future<void> load() async {
    setState(() { text = null; error = null; });
    try {
      final value = await ref.read(documentTextRepositoryProvider).fetch(widget.document.url);
      if (!mounted) return;
      setState(() => text = value);
      // A short document fits on the screen: reading it is reaching its end.
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && scroll.hasClients && scroll.position.maxScrollExtent <= 24) setState(() => reachedEnd = true); });
    } catch (e) {
      if (mounted) setState(() => error = e is FormatException ? e.message : apiError(e));
    }
  }

  @override
  Widget build(BuildContext context) => KoraPage(
    maxWidth: 680,
    // The document text grows up to the system size (200 %). The fixed parts
    // (bar, title and button) grow less, so on a small phone with large text the
    // document still has room and no word of the title is split.
    bottomNavigationBar: text == null ? null : SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.5, child: KoraButton(
        label: reachedEnd ? 'He leído el documento' : 'Desplázate hasta el final para continuar',
        onPressed: reachedEnd ? () => Navigator.of(context).pop(true) : null,
      )),
    )),
    // Only a compact bar stays fixed (back and the title on one line): with large text a
    // fixed header would leave no room for the document on a small phone. The
    // full title and the version open the scrollable text.
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 8, 20, 0), child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.6, child: Row(children: [
        IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.arrow_back), tooltip: 'Volver'),
        Expanded(child: Text(widget.document.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
      ]))),
      Expanded(child: text != null
          ? Scrollbar(controller: scroll, child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MediaQuery.withClampedTextScaling(maxScaleFactor: 1.4,
                    child: Text(widget.document.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                const SizedBox(height: 4),
                Text('Versión ${widget.document.version}', style: const TextStyle(color: Kora.muted, fontSize: 14)),
                const SizedBox(height: 12),
                SelectableText(text!, style: const TextStyle(fontSize: 16, height: 1.55)),
              ]),
            ))
          : SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
              Text('Versión ${widget.document.version}', style: const TextStyle(color: Kora.muted, fontSize: 14)),
              const SizedBox(height: 24),
              if (error == null) const CircularProgressIndicator()
              else ...[
                Text('No se pudo abrir el documento. $error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                KoraButton(label: 'Reintentar', onPressed: load),
              ],
            ]))),
    ]),
  );
}
