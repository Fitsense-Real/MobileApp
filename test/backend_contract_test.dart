import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/network/auth_interceptor.dart';
import 'package:fitsense_mobile/core/storage/token_storage.dart';
import 'package:fitsense_mobile/features/authentication/data/datasource/auth_remote_datasource.dart';
import 'package:fitsense_mobile/features/authentication/data/models/register_request.dart';
import 'package:fitsense_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';

class RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final user = {'userId': 7, 'firstName': 'Ana', 'lastName': 'Pérez', 'email': 'test@example.com', 'role': 'USER'};
    final Object data = switch (options.path) {
      '/auth/login' => {'userId': 7, 'email': 'test@example.com', 'fullName': 'Ana Pérez', 'token': 'test-token', 'role': 'USER'},
      '/auth/register' || '/users/me' => user,
      '/catalog/equipment-types' => [{'code': 'dumbbell', 'nameEs': 'Mancuernas', 'requiresGym': false}],
      '/users/me/plan/generate' => {'planId': 42, 'workouts': []},
      _ => options.data ?? {},
    };
    return ResponseBody.fromString(jsonEncode(data), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Register does not require a token; login persists JWT before /users/me', () async {
    final adapter = RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'))..httpClientAdapter = adapter;
    dio.interceptors.add(AuthInterceptor());
    final repository = AuthRepositoryImpl(AuthRemoteDataSource(dio));
    await repository.register(firstName: 'Ana', lastName: 'Pérez', email: 'test@example.com', password: 'password123', timezone: 'America/Lima', acceptsStudyParticipation: false);
    expect(await TokenStorage.getToken(), isNull);
    expect(adapter.requests.single.headers['Authorization'], isNull);
    expect(adapter.requests.single.data['acceptsStudyParticipation'], false);
    final user = await repository.login(email: 'test@example.com', password: 'password123');
    expect(user.firstName, 'Ana');
    expect(await TokenStorage.getToken(), 'test-token');
    expect(adapter.requests[1].headers['Authorization'], isNull);
    expect(adapter.requests[2].path, '/users/me');
    expect(adapter.requests[2].headers['Authorization'], 'Bearer test-token');
    final profiles = ProfileRepository(dio);
    await profiles.equipment();
    await profiles.save({'availableDays': [1,3,5], 'allowHighImpact': false}, exists: false);
    await profiles.save({'sessionMinutes': 30}, exists: true);
    expect(adapter.requests[3].headers['Authorization'], 'Bearer test-token');
    expect(adapter.requests[4].method, 'POST');
    // The backend has no movement-permission fields; they must not be sent.
    expect(adapter.requests[4].data.containsKey('allowHighImpact'), isFalse);
    expect(adapter.requests[4].data['availableDays'], [1, 3, 5]);
    expect(adapter.requests[5].method, 'PUT');
    final plan = await PlanRepository(dio).generate();
    expect(plan['planId'], 42);
    expect(adapter.requests.last.path, '/users/me/plan/generate');
    expect(adapter.requests.last.method, 'POST');
    expect(adapter.requests.last.data, isNull);
    expect(adapter.requests.last.receiveTimeout, const Duration(minutes: 5));
    expect(adapter.requests.last.headers['Authorization'], 'Bearer test-token');
  });
  test('Study participation defaults to false', () {
    expect(const RegisterRequest(firstName: 'Ana', lastName: '', email: 'a@b.com', password: 'password123').toJson()['acceptsStudyParticipation'], false);
  });
  test('Gym selection includes shared equipment requested by the user', () {
    for (final code in ['dumbbell', 'band', 'rope', 'other', 'bench', 'pull-up bar', 'suspension straps', 'step platform', 'stationary bike', 'treadmill']) {
      expect(Equipment(code, code, false).selectedForGym, true, reason: code);
    }
    expect(const Equipment('cable', 'Polea', true).selectedForGym, true);
  });
  testWidgets('Generation stops waiting after five minutes', (tester) async {
    final dio = Dio();
    // Hold the request before network dispatch, including connection setup.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (_, __) {}));
    Object? error;
    final operation = PlanRepository(dio).generate().then<void>((_) {}, onError: (Object e) { error = e; });
    await tester.pump(const Duration(minutes: 4, seconds: 59));
    expect(error, isNull);
    await tester.pump(const Duration(seconds: 1));
    await operation;
    expect(error, isA<DioException>());
    expect((error as DioException).type, DioExceptionType.receiveTimeout);
  });
}
