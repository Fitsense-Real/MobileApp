import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Downloads a public legal document (terms, privacy policy, study consent) to
/// show it complete inside the app. Uses its own client: no JWT is ever sent to
/// a document address.
class DocumentTextRepository {
  DocumentTextRepository([Dio? dio])
      : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 20), responseType: ResponseType.plain));
  final Dio _dio;

  /// The document as ordered blocks (subtitles and paragraphs) for the reader.
  Future<List<DocumentBlock>> fetchBlocks(String url) async => blocks(await fetchRaw(url));

  Future<String> fetch(String url) async => plainText(await fetchRaw(url));

  /// Subtitles (`<h1>`…`<h4>`) and paragraphs of a text or simple HTML
  /// document, in order. The text of each block is [plainText] (entities
  /// decoded, links with their destination, nothing active).
  static List<DocumentBlock> blocks(String raw) {
    const mark = '\u0001';
    // Plain text: paragraphs are separated by blank lines; line breaks inside a
    // paragraph (lists, numbered items) are kept as they are.
    if (!raw.contains('<')) {
      return [
        for (final paragraph in plainText(raw).split(RegExp(r'\n\s*\n')))
          if (paragraph.trim().isNotEmpty) DocumentBlock(paragraph.trim()),
      ];
    }
    final marked = raw.replaceAllMapped(RegExp(r'<h[1-4][^>]*>([\s\S]*?)</h[1-4]>', caseSensitive: false),
        (m) => '<p>$mark${m[1]!.replaceAll(RegExp(r'<[^>]+>'), ' ')}</p>');
    final text = plainText(marked);
    final result = <DocumentBlock>[];
    for (final paragraph in text.split(RegExp(r'\n\s*\n|\n(?=$mark)'))) {
      for (final line in paragraph.split('\n')) {
        final value = line.trim();
        if (value.isEmpty || value == mark) continue;
        result.add(value.startsWith(mark)
            ? DocumentBlock(value.substring(1).replaceAll(RegExp(r'\s+'), ' ').trim(), heading: true)
            : DocumentBlock(value));
      }
    }
    return result;
  }

  /// Downloads the document and checks it can be shown (text or HTML, not
  /// empty). The only network step: [fetch] and [fetchBlocks] read from it.
  Future<String> fetchRaw(String url) async {
    final uri = Uri.tryParse(url);
    final allowed = uri != null && (uri.scheme == 'https' || (!kReleaseMode && uri.scheme == 'http')) && uri.host.isNotEmpty;
    if (!allowed) throw const FormatException('La dirección del documento no es válida.');
    final response = await _dio.get<String>(url, options: Options(responseType: ResponseType.plain));
    final raw = response.data ?? '';
    // A PDF, an image or any binary file cannot be shown as text: it would appear
    // as unreadable characters and could even be «read» to the end. It is
    // reported as not openable, so it can never be accepted.
    // Some servers repeat Content-Type; value() would throw, so the last one is used.
    final types = response.headers[Headers.contentTypeHeader] ?? const <String>[];
    if (!isDisplayable(types.isEmpty ? null : types.last, raw)) throw const FormatException(unsupportedFormat);
    if (plainText(raw).trim().isEmpty) throw const FormatException('El documento está vacío.');
    return raw;
  }

  static const unsupportedFormat = 'El documento no está en un formato que Kora pueda mostrar (texto o HTML). Contacta al equipo del estudio.';

  /// Text or HTML that the app can show. An unknown content type is judged by
  /// its content: a PDF signature or control characters mean binary.
  static bool isDisplayable(String? contentType, String raw) {
    final type = (contentType ?? '').toLowerCase().split(';').first.trim();
    if (type.isNotEmpty && !(type.startsWith('text/') || type.endsWith('+xml') || type == 'application/xhtml+xml' || type == 'application/xml')) {
      return false;
    }
    final head = raw.trimLeft();
    if (head.startsWith('%PDF') || head.startsWith('PK\u0003\u0004')) return false;
    return !RegExp(r'[\u0000-\u0008\u000E-\u001F]').hasMatch(raw.length > 4096 ? raw.substring(0, 4096) : raw);
  }

  /// Plain text from a text or simple HTML document: block tags become line
  /// breaks, other tags are removed and common entities decoded.
  static const _entities = {
    'nbsp': ' ', 'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'",
    'aacute': 'á', 'eacute': 'é', 'iacute': 'í', 'oacute': 'ó', 'uacute': 'ú', 'ntilde': 'ñ', 'uuml': 'ü',
    'Aacute': 'Á', 'Eacute': 'É', 'Iacute': 'Í', 'Oacute': 'Ó', 'Uacute': 'Ú', 'Ntilde': 'Ñ', 'Uuml': 'Ü',
    'iquest': '¿', 'iexcl': '¡', 'laquo': '«', 'raquo': '»', 'ldquo': '“', 'rdquo': '”', 'lsquo': '‘', 'rsquo': '’',
    'mdash': '—', 'ndash': '–', 'hellip': '…', 'middot': '·', 'bull': '•', 'ordm': 'º', 'ordf': 'ª', 'deg': '°',
    'copy': '©', 'reg': '®', 'euro': '€',
  };

  static String plainText(String raw) {
    if (!raw.contains('<')) return raw.trim();
    var s = raw.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), '');
    // Links keep their destination, or a contact address or page would vanish:
    // «el equipo (equipo@estudio.org)». Shown as selectable text, so it can be copied.
    s = s.replaceAllMapped(RegExp(r'''<a\s[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a>''', caseSensitive: false), (m) {
      final target = m[1]!.trim().replaceFirst(RegExp('^mailto:', caseSensitive: false), '');
      final label = m[2]!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      if (target.isEmpty || target.startsWith('#') || target.toLowerCase().startsWith('javascript:')) return label;
      return label.isEmpty || label == target ? target : '$label ($target)';
    });
    s = s.replaceAll(RegExp(r'<\s*(br|/p|/h[1-6]|/li|/div|/tr)\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    // One pass, so «&amp;lt;» stays «&lt;»; numeric entities (&#243;, &#xE9;) and
    // the named ones of Spanish legal texts are decoded, unknown ones are kept.
    s = s.replaceAllMapped(RegExp(r'&(#\d{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z]{2,8});'), (m) {
      final e = m[1]!;
      if (e.startsWith('#')) {
        final code = e[1] == 'x' || e[1] == 'X' ? int.tryParse(e.substring(2), radix: 16) : int.tryParse(e.substring(1));
        return code != null && code > 0 && code <= 0x10FFFF ? String.fromCharCode(code) : m[0]!;
      }
      return _entities[e] ?? m[0]!;
    });
    return s.split('\n').map((l) => l.trim()).join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

final documentTextRepositoryProvider = Provider((ref) => DocumentTextRepository());

/// A subtitle or a paragraph of a legal document.
class DocumentBlock {
  const DocumentBlock(this.text, {this.heading = false});
  final String text;
  final bool heading;

  @override
  bool operator ==(Object other) => other is DocumentBlock && other.text == text && other.heading == heading;

  @override
  int get hashCode => Object.hash(text, heading);

  @override
  String toString() => heading ? '## $text' : text;
}
