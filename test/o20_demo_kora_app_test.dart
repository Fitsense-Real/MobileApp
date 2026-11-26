// O20 · the Demo Kora account seen through the app. The app's real screens, providers and repositories run
// on a Dio whose answers are the ones the backend gave for that account (test/fixtures/o20_demo_kora, recorded
// read-only by test/live/o20_grabar_live_test.dart from a local copy of dataset_demo_kora, backend 98276a9).
// Only GET requests are allowed: anything else fails the test (nothing is generated, closed or recorded).
// With KORA_CAPTURAS set, it also saves screenshots.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/authentication/domain/entities/user.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:fitsense_mobile/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_confirmation_sheet.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

const fixtures = 'test/fixtures/o20_demo_kora';
final out = Platform.environment['KORA_CAPTURAS'];

/// Answers each GET with what the backend answered for that path; anything else is refused.
class ReplayAdapter implements HttpClientAdapter {
  final requests = <String>[];
  final missing = <String>{};
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancel) async {
    requests.add('${options.method} ${options.path}');
    final json = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    if (options.method != 'GET') return ResponseBody.fromString('{"message":"solo lectura"}', 405, headers: json);
    final file = File('$fixtures/${options.path.replaceAll('/', '_')}.json');
    if (!file.existsSync()) {
      missing.add(options.path);
      return ResponseBody.fromString('{"message":"no grabado"}', 404, headers: json);
    }
    final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final status = saved['status'] as int;
    return ResponseBody.fromString(saved['data'] == null ? '' : jsonEncode(saved['data']), status, headers: json);
  }
  @override
  void close({bool force = false}) {}
  int count(String path) => requests.where((r) => r == 'GET $path').length;
}

class DemoKora extends AuthViewModel {
  @override
  AuthState build() {
    super.build();
    return const AuthState(isAuthenticated: true, user: User(id: 1, firstName: 'Usuario', lastName: 'Demo Kora',
        email: 'usuario.demo.kora@example.com', timezone: 'America/Lima', status: 'ACTIVE'));
  }
}

final shot = GlobalKey();

Future<void> capture(WidgetTester tester, String name) async {
  if (out == null) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')..createSync(recursive: true)..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> loadFonts() async {
  final poppins = FontLoader('Poppins');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
    poppins.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Poppins-$w.ttf').readAsBytesSync())));
  }
  await poppins.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    await (FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync()))))
        .load();
  }
}

void main() {
  setUpAll(() async { if (out != null) await loadFonts(); });

  testWidgets('Demo Kora: profile, current routine, four plans and their sessions, adherence, adaptations, exclusion 1025, refresh on return', (tester) async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'demo'});
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final adapter = ReplayAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8081/api/v1'))..httpClientAdapter = adapter;
    await tester.pumpWidget(RepaintBoundary(key: shot, child: ProviderScope(overrides: [
      dioProvider.overrideWithValue(dio),
      authViewModelProvider.overrideWith(DemoKora.new),
    ], child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.light,
        home: const PainSafetyResumeRefresher(child: DashboardPage())))));
    await tester.pumpAndSettle();

    // 1. Inicio: the current routine (plan 910000003), no safety notice (nothing pending, nothing infeasible).
    expect(adapter.count('/users/me/plan/current'), greaterThan(0));
    expect(find.byKey(const Key('not-feasible')), findsNothing);
    expect(find.textContaining('¿Recuerdas qué ejercicio te dolió'), findsNothing);
    await capture(tester, 'D1-demo-inicio');

    // 2. Rutinas: the five workouts of the current week.
    await tester.tap(find.text('Rutinas'));
    await tester.pumpAndSettle();
    for (final name in ['Empuje', 'Traccion', 'Piernas', 'Tren superior', 'Tren inferior']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    await capture(tester, 'D2-demo-rutinas');

    // 3. Progreso: weekly adherence and the adaptations (substitution for pain, progression).
    await tester.tap(find.text('Progreso'));
    await tester.pumpAndSettle();
    expect(adapter.count('/users/me/metrics/weekly'), greaterThan(0));
    expect(adapter.count('/users/me/plan/adaptations'), greaterThan(0));
    expect(find.text('Semana del 16/11/2026'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Sin ajustes registrados'), findsOneWidget, reason: 'the plan of 16/11 came from SIN_ADAPTACION');
    await capture(tester, 'D3-demo-progreso-16nov');
    Future<void> week(String label) async {
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }
    await week('Semana del 09/11/2026');
    expect(find.text('Plan adaptado a ti'), findsOneWidget, reason: 'the plan of 09/11 came from the substitution for pain');
    await capture(tester, 'D3-demo-progreso-09nov-sustitucion');
    await week('Semana del 02/11/2026');
    expect(find.text('67.8%'), findsOneWidget, reason: 'adherence of the first week: 67,81 %');
    expect(find.textContaining('3 / 5', findRichText: true), findsOneWidget, reason: '3 completed of 5');
    await capture(tester, 'D3-demo-progreso-02nov');

    // 4. Perfil → Historial de planes: the four weeks.
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Historial de planes'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Historial de planes'));
    await tester.pumpAndSettle();
    expect(adapter.count('/users/me/plans'), greaterThan(0));
    for (final week in ['23/11/2026', '16/11/2026', '09/11/2026', '02/11/2026']) {
      expect(find.textContaining('Semana del $week'), findsOneWidget, reason: week);
    }
    await capture(tester, 'D4-demo-historial');
    // The first week: 3 completed, 1 partial and 1 skipped session, as the backend recorded them.
    await tester.tap(find.textContaining('Semana del 02/11/2026'));
    await tester.pumpAndSettle();
    expect(adapter.count('/users/me/plan/910000000'), greaterThan(0));
    expect(find.textContaining('· Completado'), findsNWidgets(4), reason: 'the plan (Versión 1 · Completado) and its 3 completed sessions');
    expect(find.textContaining('· Parcial'), findsOneWidget);
    expect(find.textContaining('· Omitido'), findsOneWidget);
    await capture(tester, 'D4-demo-semana-02nov-sesiones');
    Navigator.of(tester.element(find.textContaining('· Parcial'))).pop();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Perfil → Cuenta: the complete profile of the dataset (read only during the study).
    await tester.scrollUntilVisible(find.text('Cuenta'), -200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    expect(adapter.count('/users/me/profile'), greaterThan(0));
    expect(find.textContaining('Ganar masa muscular'), findsOneWidget);
    expect(find.textContaining('Estatura: 176 cm'), findsOneWidget);
    expect(find.textContaining('Peso: 74 kg'), findsOneWidget);
    expect(find.textContaining('5 días · 60 min'), findsOneWidget);
    await capture(tester, 'D6-demo-perfil');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 5. Perfil → Ejercicios excluidos por dolor: 1025, confirmed, with its plain explanation.
    await tester.scrollUntilVisible(find.text('Ejercicios excluidos por dolor'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Ejercicios excluidos por dolor'));
    await tester.pumpAndSettle();
    expect(find.text('Aperturas de pecho sentado con palanca'), findsOneWidget);
    expect(find.textContaining('Lo marcaste con dolor.'), findsOneWidget);
    await capture(tester, 'D5-demo-exclusion-1025');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 6. Back from the background: the plan and the exclusions are read again.
    final plans = adapter.count('/users/me/plan/current'), effective = adapter.count('/users/me/pain-exclusions/effective');
    for (final state in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused,
                         AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(adapter.count('/users/me/plan/current'), greaterThan(plans));
    expect(adapter.count('/users/me/pain-exclusions/effective'), greaterThanOrEqualTo(effective));

    expect(adapter.requests.where((r) => !r.startsWith('GET ')), isEmpty, reason: 'only reads');
    // ignore: avoid_print
    print('O20 DEMO app: ${adapter.requests.toSet().length} lecturas distintas; sin grabar: ${adapter.missing}');
  });
}
