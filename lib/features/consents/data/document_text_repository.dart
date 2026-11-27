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
    final text = plainText(response.data ?? '');
    if (text.trim().isEmpty) throw const FormatException('El documento está vacío.');
    return text;
  }

  /// Plain text from a text or simple HTML document: block tags become line
  /// breaks, other tags are removed and common entities decoded.
  static String plainText(String raw) {
    if (!raw.contains('<')) return raw.trim();
    var s = raw.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<\s*(br|/p|/h[1-6]|/li|/div|/tr)\s*/?>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    const entities = {'&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'", '&aacute;': 'á', '&eacute;': 'é', '&iacute;': 'í', '&oacute;': 'ó', '&uacute;': 'ú', '&ntilde;': 'ñ'};
    entities.forEach((k, v) => s = s.replaceAll(k, v));
    return s.split('\n').map((l) => l.trim()).join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

final documentTextRepositoryProvider = Provider((ref) => DocumentTextRepository());
