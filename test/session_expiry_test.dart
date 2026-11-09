import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/app/session_expiry.dart';
import 'package:fitsense_mobile/core/network/auth_interceptor.dart';
import 'package:fitsense_mobile/core/storage/token_storage.dart';
import 'package:fitsense_mobile/features/authentication/domain/entities/user.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:fitsense_mobile/features/reminders/data/reminder_scheduler.dart';
import 'package:fitsense_mobile/features/reminders/domain/reminder_planner.dart';
import 'package:fitsense_mobile/features/reminders/presentation/reminders_controller.dart';

class Backend implements HttpClientAdapter {
  Backend(this.status);
  final int Function(RequestOptions) status;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final code = status(o);
    return ResponseBody.fromString(jsonEncode({'status': code, 'message': 'x', 'details': []}), code,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }
  @override
  void close({bool force = false}) {}
}

Dio dioWith(int Function(RequestOptions) status) =>
    Dio(BaseOptions(baseUrl: 'http://localhost:8080/api/v1'))
      ..httpClientAdapter = Backend(status)
      ..interceptors.add(AuthInterceptor());

Future<void> call(Dio dio, String path, {String method = 'GET'}) async {
  try {
    await dio.request(path, options: Options(method: method));
  } on DioException catch (_) {}
}

class FakeScheduler implements ReminderScheduler {
  int cancels = 0;
  @override
  Future<void> cancelAll() async => cancels++;
  @override
  DateTime nowIn(String? timezone) => DateTime(2026, 11, 9);
  @override
  Future<void> replaceAll(List<PlannedReminder> reminders, {String? timezone}) async {}
  @override
  Future<bool> requestPermission() async => true;
}

class SignedIn extends AuthViewModel {
  @override
  AuthState build() {
    super.build(); // initialises the use cases logout() relies on
    return const AuthState(isAuthenticated: true, user: User(id: 7, firstName: 'Ana', lastName: 'Demo', email: 'a@b.com'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var expirations = 0;
  setUp(() {
    expirations = 0;
    FlutterSecureStorage.setMockInitialValues({'access_token': 'jwt'});
    AuthInterceptor.onSessionExpired = () => expirations++;
  });
  tearDown(() => AuthInterceptor.onSessionExpired = null);

  group('AuthInterceptor', () {
    test('a 401 with a JWT expires the session once, even with parallel requests', () async {
      final dio = dioWith((_) => 401);
      await Future.wait([call(dio, '/users/me/profile'), call(dio, '/users/me/plan/current'), call(dio, '/users/me/metrics/weekly')]);
      expect(expirations, 1);
      expect(await TokenStorage.getToken(), isNull);
      // A later request without token is not a second expiry.
      await call(dio, '/users/me/interventions');
      expect(expirations, 1);
    });

    test('wrong credentials on login are not an expired session', () async {
      await call(dioWith((_) => 401), '/auth/login', method: 'POST');
      expect(expirations, 0);
      expect(await TokenStorage.getToken(), 'jwt');
    });

    test('a request without a stored token never expires anything', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await call(dioWith((_) => 401), '/users/me');
      expect(expirations, 0);
    });

    test('other errors keep the session', () async {
      for (final code in [403, 404, 422, 500]) {
        await call(dioWith((_) => code), '/users/me');
      }
      expect(expirations, 0);
      expect(await TokenStorage.getToken(), 'jwt');
    });
  });

  group('handleSessionExpired', () {
    Future<(ProviderContainer, FakeScheduler, GoRouter)> pumpApp(WidgetTester tester, String location) async {
      final scheduler = FakeScheduler();
      final container = ProviderContainer(overrides: [
        authViewModelProvider.overrideWith(SignedIn.new),
        reminderSchedulerProvider.overrideWithValue(scheduler),
      ]);
      addTearDown(container.dispose);
      final router = GoRouter(initialLocation: location, routes: [
        for (final path in ['/dashboard', '/login', '/splash'])
          GoRoute(path: path, builder: (_, __) => Scaffold(body: Text('Pantalla $path'))),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router, scaffoldMessengerKey: rootMessengerKey),
      ));
      await tester.pumpAndSettle();
      return (container, scheduler, router);
    }

    testWidgets('clears the session, cancels reminders, goes to login and explains why', (tester) async {
      final (container, scheduler, router) = await pumpApp(tester, '/dashboard');
      expect(container.read(authViewModelProvider).isAuthenticated, isTrue);
      await handleSessionExpired(auth: container.read(authViewModelProvider.notifier), router: router);
      await tester.pumpAndSettle();
      expect(find.text('Pantalla /login'), findsOneWidget);
      expect(find.text(sessionExpiredMessage), findsOneWidget);
      expect(container.read(authViewModelProvider).user, isNull);
      expect(scheduler.cancels, 1);
      expect(await TokenStorage.getToken(), isNull);
    });

    testWidgets('on a public screen it stays there and only shows the message', (tester) async {
      final (container, _, router) = await pumpApp(tester, '/splash');
      await handleSessionExpired(auth: container.read(authViewModelProvider.notifier), router: router);
      await tester.pumpAndSettle();
      expect(find.text('Pantalla /splash'), findsOneWidget);
      expect(find.text(sessionExpiredMessage), findsOneWidget);
    });

    testWidgets('a 401 from the API triggers the whole flow', (tester) async {
      final (container, scheduler, router) = await pumpApp(tester, '/dashboard');
      AuthInterceptor.onSessionExpired = () => handleSessionExpired(auth: container.read(authViewModelProvider.notifier), router: router);
      await tester.runAsync(() => call(dioWith((_) => 401), '/users/me/plan/current'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla /login'), findsOneWidget);
      expect(find.text(sessionExpiredMessage), findsOneWidget);
      expect(scheduler.cancels, 1);
    });
  });
}
