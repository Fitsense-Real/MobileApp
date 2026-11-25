// O20 screens drawn with what a running backend answered (recorded by test/live/o20_grabar_live_test.dart,
// unchanged JSON). Skipped unless KORA_CAPTURAS (output folder) and KORA_O20_GRABADO (recorded folder) are set:
//
//   KORA_CAPTURAS=docs/o20/validacion/capturas KORA_O20_GRABADO=<folder> FLUTTER_ROOT=... \
//   flutter test test/screenshots/o20_backend_real_capturas_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/pain/data/pain_exclusion_repository.dart';
import 'package:fitsense_mobile/features/pain/domain/pain_safety.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_confirmation_sheet.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_exclusions_sheet.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_safety_notices.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

final out = Platform.environment['KORA_CAPTURAS'];
final recorded = Platform.environment['KORA_O20_GRABADO'];

/// The backend's answer saved for [account].
Object? answer(String account, String name) {
  final file = File('$recorded/$account/$name.json');
  return file.existsSync() ? jsonDecode(file.readAsStringSync()) : null;
}

class RecordedPain extends PainExclusionRepository {
  RecordedPain(this.account) : super(Dio());
  final String account;
  @override
  Future<List<Json>> list() async => jsonRows(answer(account, 'pain_exclusions') ?? []);
  @override
  Future<List<EffectiveExclusion>> effective() async =>
      [for (final r in jsonRows(answer(account, 'pain_exclusions_effective') ?? [])) EffectiveExclusion.fromJson(r)];
  @override
  Future<List<PainConfirmationRequest>> confirmationRequests() async =>
      [for (final r in jsonRows(answer(account, 'pain_exclusions_confirmation_requests') ?? [])) PainConfirmationRequest.fromJson(r)];
}

class RecordedPlans extends PlanRepository {
  RecordedPlans(this.account) : super(Dio());
  final String account;
  @override
  Future<Json?> current() async => answer(account, 'plan_current') as Json?;
  @override
  Future<List<Json>> adaptations() async => jsonRows(answer(account, 'plan_adaptations') ?? []);
}

class RecordedWorkouts extends WorkoutRepository {
  RecordedWorkouts(this.account) : super(Dio());
  final String account;
  @override
  Future<Json?> current() async => answer(account, 'session_current') as Json?;
}

Future<void> loadFonts() async {
  final poppins = FontLoader('Poppins');
  for (final w in ['Regular', 'SemiBold', 'Bold', 'ExtraBold', 'Black']) {
    poppins.addFont(Future.value(ByteData.sublistView(File('assets/fonts/Poppins-$w.ttf').readAsBytesSync())));
  }
  await poppins.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
    await icons.load();
  }
}

final shot = GlobalKey();

// The filled button's text style names no font (a device uses its own): here, Poppins.
final theme = AppTheme.light.copyWith(
  filledButtonTheme: FilledButtonThemeData(style: AppTheme.light.filledButtonTheme.style!.copyWith(
    textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
  )),
);

Future<void> capture(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png')..createSync(recursive: true)..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> pump(WidgetTester tester, String account, Widget child, {Size size = const Size(400, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(RepaintBoundary(key: shot, child: ProviderScope(overrides: [
    painExclusionRepositoryProvider.overrideWithValue(RecordedPain(account)),
    planRepositoryProvider.overrideWithValue(RecordedPlans(account)),
    workoutRepositoryProvider.overrideWithValue(RecordedWorkouts(account)),
  ], child: MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: child))));
  await tester.pumpAndSettle();
}

bool has(String account) => recorded != null && Directory('$recorded/$account').existsSync();

void main() {
  final skip = out == null || recorded == null;
  setUpAll(() async { if (!skip) await loadFonts(); });

  testWidgets('R1 Demo Kora · Perfil: la exclusión por dolor del dataset', (tester) async {
    await pump(tester, 'demo', const Scaffold(body: SafeArea(child: PainExclusionsSheet())), size: const Size(400, 700));
    expect(find.byKey(const Key('effective-1025')), findsOneWidget);
    expect(find.text('Ya no me duele'), findsOneWidget);
    await capture(tester, 'R1-demo-perfil-exclusion');
  }, skip: skip || !has('demo'));

  testWidgets('R2 sintética · rutina abierta con ejercicios bloqueados por dolor', (tester) async {
    final workout = answer('sintetica', 'workout')! as Json;
    await pump(tester, 'sintetica', PlannedWorkoutPage(workout: workout), size: const Size(400, 1250));
    final blocked = jsonRows(workout['exercises']).where((e) => e['safetyBlockReason'] != null);
    for (final e in blocked) {
      expect(find.byKey(Key('blocked-${e['plannedExerciseId']}')), findsOneWidget);
    }
    expect(find.textContaining('dolor_registrado'), findsNothing);
    await capture(tester, 'R2-sintetica-rutina-bloqueados');
  }, skip: skip || !has('sintetica'));

  testWidgets('R3 sintética · confirmación de la sesión con dolor', (tester) async {
    final request = PainConfirmationRequest.fromJson(jsonRows(answer('sintetica', 'pain_exclusions_confirmation_requests')).first);
    await pump(tester, 'sintetica', Scaffold(body: SafeArea(child: SingleChildScrollView(child: PainConfirmationSheet(request: request)))), size: const Size(400, 1300));
    await capture(tester, 'R3-sintetica-confirmacion');
  }, skip: skip || !has('sintetica'));

  testWidgets('R4 sintética · Perfil: petición y exclusiones agrupadas', (tester) async {
    await pump(tester, 'sintetica', const Scaffold(body: SafeArea(child: PainExclusionsSheet())), size: const Size(400, 2000));
    await capture(tester, 'R4-sintetica-perfil');
  }, skip: skip || !has('sintetica'));

  testWidgets('R5 S9 · Inicio tras dos semanas con plan: Kora pregunta', (tester) async {
    await pump(tester, 's9', const Scaffold(body: SafeArea(child: Padding(padding: EdgeInsets.all(16), child: PainSafetyNotices()))), size: const Size(400, 420));
    expect(find.textContaining('¿Recuerdas qué ejercicio te dolió'), findsOneWidget);
    await capture(tester, 'R5-s9-inicio-pregunta');
  }, skip: skip || !has('s9'));

  testWidgets('R6 S9 · Perfil tras dos semanas: siguen excluidos', (tester) async {
    await pump(tester, 's9', const Scaffold(body: SafeArea(child: PainExclusionsSheet())), size: const Size(400, 2200));
    await capture(tester, 'R6-s9-perfil');
  }, skip: skip || !has('s9'));

  testWidgets('R7 cuenta A · Inicio tras un cierre NO_FACTIBLE_POR_SEGURIDAD', (tester) async {
    await pump(tester, 'nofactible', const Scaffold(body: SafeArea(child: Padding(padding: EdgeInsets.all(16), child: PainSafetyNotices()))), size: const Size(400, 380));
    expect(find.byKey(const Key('not-feasible')), findsOneWidget);
    await capture(tester, 'R7-cuenta-a-inicio-no-factible');
  }, skip: skip || !has('nofactible'));
}
