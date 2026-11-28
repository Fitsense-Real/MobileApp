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

  Future<String> fetch(String url) async {
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
    final text = plainText(raw);
    if (text.trim().isEmpty) throw const FormatException('El documento está vacío.');
    return text;
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
    const entities = {'&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&aacute;': 'á', '&eacute;': 'é', '&iacute;': 'í', '&oacute;': 'ó', '&uacute;': 'ú', '&ntilde;': 'ñ'};
    entities.forEach((k, v) => s = s.replaceAll(k, v));
    return s.split('\n').map((l) => l.trim()).join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

final documentTextRepositoryProvider = Provider((ref) => DocumentTextRepository());
