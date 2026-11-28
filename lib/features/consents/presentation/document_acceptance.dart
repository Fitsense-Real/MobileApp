import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../data/consents_repository.dart';
import 'document_reader_page.dart';

/// «☐ Acepto los Términos y condiciones»: the name of the document is a link
/// that opens it (and never ticks the box); only the box ticks or unticks it.
///
/// The name is part of the sentence, so with large text it wraps word by word
/// like the rest (text up to 170 %). Keys: the checkbox takes [checkboxKey]; the sentence is
/// `read-<type>`.
class DocumentAcceptance extends StatefulWidget {
  const DocumentAcceptance({
    super.key,
    required this.type,
    required this.before,
    this.after = '',
    required this.value,
    required this.onChanged,
    required this.onOpen,
    required this.checkboxKey,
    this.note,
    this.noteIsError = false,
  });

  final ConsentType type;
  final String before;
  final String after;
  final bool value;

  /// Null: the box cannot be changed (busy, or the document cannot be shown).
  final ValueChanged<bool>? onChanged;

  /// Null: the document cannot be opened now.
  final VoidCallback? onOpen;
  final Key checkboxKey;
  final String? note;
  final bool noteIsError;

  static const link = Color(0xFF1B5E9A);

  @override
  State<DocumentAcceptance> createState() => _DocumentAcceptanceState();
}

class _DocumentAcceptanceState extends State<DocumentAcceptance> {
  final _open = TapGestureRecognizer();

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = DocumentReaderPage.titleOf(widget.type);
    _open.onTap = widget.onOpen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
          key: widget.checkboxKey,
          value: widget.value,
          semanticLabel: '${widget.before}$title${widget.after}',
          onChanged: widget.onChanged == null ? null : (v) => widget.onChanged!(v ?? false),
        ),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Up to 170 %: at 200 % «Consentimiento» alone is wider than a
            // 320 px phone and would be split in the middle.
            MediaQuery.withClampedTextScaling(maxScaleFactor: 1.7, child: Text.rich(
              key: Key('read-${widget.type.code}'),
              TextSpan(style: const TextStyle(fontSize: 15, height: 1.4, color: Kora.forest), children: [
                TextSpan(text: widget.before),
                TextSpan(
                  text: title,
                  recognizer: _open,
                  style: const TextStyle(color: DocumentAcceptance.link, fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline, decorationColor: DocumentAcceptance.link),
                ),
                if (widget.after.isNotEmpty) TextSpan(text: widget.after),
              ]),
            )),
            if (widget.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.note!, style: TextStyle(color: widget.noteIsError ? Colors.red.shade800 : Kora.muted, fontSize: 13, height: 1.4)),
              ),
          ]),
        )),
      ]),
    );
  }
}
