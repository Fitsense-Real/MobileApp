import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_error.dart';
import '../data/consents_repository.dart';
import '../data/document_text_repository.dart';
import '../domain/legal_documents.dart';

/// Shows a legal document (terms, privacy policy, informed consent) inside the
/// app, only to read it: white page, dark text, the title, subtitles and
/// paragraphs, vertical scroll and a back arrow. Accepting happens only with
/// the checkbox of the form that opened it.
///
/// [open] answers whether the document could be shown: `true` shown, `false`
/// it could not be opened (unavailable: it cannot be accepted), `null` closed
/// before it finished loading.
class DocumentReaderPage extends ConsumerStatefulWidget {
  const DocumentReaderPage({super.key, required this.document});
  final LegalDocument document;

  static Future<bool?> open(BuildContext context, LegalDocument document) =>
      Navigator.of(context).push<bool?>(MaterialPageRoute(builder: (_) => DocumentReaderPage(document: document)));

  /// The title of each kind of document, as the person knows it.
  static String titleOf(ConsentType type) => switch (type) {
        ConsentType.termsOfService => 'Términos y condiciones',
        ConsentType.privacyPolicy => 'Política de privacidad',
        ConsentType.studyParticipation => 'Consentimiento informado',
      };

  @override
  ConsumerState<DocumentReaderPage> createState() => _DocumentReaderPageState();
}

class _DocumentReaderPageState extends ConsumerState<DocumentReaderPage> {
  static const _ink = Color(0xFF1F2421);
  static const _muted = Color(0xFF5B635E);

  List<DocumentBlock>? blocks;
  String? error;

  /// The bar shows the title only once the title of the text has scrolled away.
  final _scroll = ScrollController();
  bool _titleInBar = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final past = _scroll.offset > 48;
      if (past != _titleInBar) setState(() => _titleInBar = past);
    });
    load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() { blocks = null; error = null; });
    try {
      final value = await ref.read(documentTextRepositoryProvider).fetchBlocks(widget.document.url);
      if (mounted) setState(() => blocks = value);
    } catch (e) {
      if (mounted) setState(() => error = e is FormatException ? e.message : apiError(e));
    }
  }

  /// What the form learns when the person goes back.
  bool? get _outcome => blocks != null ? true : error != null ? false : null;

  @override
  Widget build(BuildContext context) {
    final title = DocumentReaderPage.titleOf(widget.document.type);
    return PopScope<bool?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_outcome);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Volver', onPressed: () => Navigator.of(context).pop(_outcome)),
          title: AnimatedOpacity(
            opacity: _titleInBar || blocks == null ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: switch ((blocks, error)) {
                (final content?, _) => Scrollbar(
                    controller: _scroll,
                    child: SelectionArea(
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                        children: [
                          // The full title wraps by whole words (up to 140 %, so «Consentimiento»
                          // fits a 320 px phone); the text of the document grows up to 200 %.
                          MediaQuery.withClampedTextScaling(
                            maxScaleFactor: 1.4,
                            child: Text(title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
                          ),
                          const SizedBox(height: 4),
                          Text('Versión ${widget.document.version}', style: const TextStyle(color: _muted, fontSize: 13)),
                          const SizedBox(height: 16),
                          for (final block in content)
                            Padding(
                              padding: EdgeInsets.only(top: block.heading ? 12 : 0, bottom: block.heading ? 8 : 14),
                              child: Text(
                                block.text,
                                style: block.heading
                                    ? const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700, height: 1.35)
                                    : const TextStyle(color: _ink, fontSize: 16, height: 1.55),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                (_, final message?) => ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text('No se pudo abrir el documento. $message', style: const TextStyle(color: _ink, fontSize: 16, height: 1.5)),
                      const SizedBox(height: 16),
                      Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: load, child: const Text('Reintentar'))),
                    ],
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ),
        ),
      ),
    );
  }
}
