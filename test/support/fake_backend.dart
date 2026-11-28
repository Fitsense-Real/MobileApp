import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fitsense_mobile/core/network/auth_interceptor.dart';

typedef FakeAnswer = ({int status, Object? body});

/// HTTP adapter that answers like the backend, recording every request.
/// A handler may throw a [DioException] to simulate a lost connection.
class ScriptedBackend implements HttpClientAdapter {
  ScriptedBackend(this.handler, {this.headers});
  final FakeAnswer Function(RequestOptions options) handler;

  /// Extra response headers (e.g. `Retry-After` on a 429).
  final Map<String, List<String>> Function(RequestOptions options)? headers;
  final requests = <RequestOptions>[];

  List<String> get routes => [for (final r in requests) '${r.method} ${r.path}'];
  Map<String, dynamic> bodyOf(String method, String path) =>
      Map<String, dynamic>.from(requests.lastWhere((r) => r.method == method && r.path == path).data as Map);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream, Future<void>? cancel) async {
    requests.add(options);
    final r = handler(options);
    return ResponseBody.fromString(r.body == null ? '' : jsonEncode(r.body), r.status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType], ...?headers?.call(options)});
  }

  @override
  void close({bool force = false}) {}
}

Dio scriptedDio(ScriptedBackend backend) => Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1', contentType: Headers.jsonContentType))
  ..httpClientAdapter = backend
  ..interceptors.add(AuthInterceptor());

/// `ApiErrorResource` of the backend.
Map<String, dynamic> apiErrorBody(int status, String message) =>
    {'timestamp': '2026-11-27T06:33:09Z', 'status': status, 'error': 'Error', 'message': message, 'details': []};

/// `UserResource` as the backend returns it.
Map<String, dynamic> userResource({int id = 41, String email = 'ana@audit.local', bool participant = true, String? withdrawnAt}) => {
      'userId': id, 'email': email, 'firstName': 'Ana', 'lastName': 'Prueba', 'timezone': 'America/Lima', 'status': 'ACTIVE',
      'studyParticipant': participant, 'participantCode': participant ? 'P-041' : null,
      'enrolledAt': participant ? '2026-11-27T06:33:10Z' : null, 'withdrawnAt': withdrawnAt, 'lastLoginAt': null, 'role': 'USER',
    };

DioException connectionLost(String path) => DioException(requestOptions: RequestOptions(path: path), type: DioExceptionType.connectionError);
