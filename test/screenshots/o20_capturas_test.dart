// Screenshots of the O20 screens, for the PR evidence. Skipped unless
// KORA_CAPTURAS is set to an output folder:
//
//   KORA_CAPTURAS=docs/o20/capturas FLUTTER_ROOT=... flutter test test/screenshots/o20_capturas_test.dart
//
// Simulated data shaped exactly like the backend's answers (Backend PR #84),
// with names seen in the live run. Real fonts (Poppins, Material Icons).
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/pain/data/pain_exclusion_repository.dart';
import 'package:fitsense_mobile/features/pain/domain/pain_safety.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_confirmation_sheet.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_exclusions_sheet.dart';
import 'package:fitsense_mobile/features/pain/presentation/pain_safety_notices.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/presentation/exercise_result_dialog.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

final out = Platform.environment['KORA_CAPTURAS'];

Json row(int id, String name, String origin, {bool confirmed = false, bool provisional = false, bool ask = false, int? from, String? fromName, int? source, String? date}) => {
  'exerciseId': id, 'exerciseName': name, 'origin': origin, 'confirmed': confirmed, 'provisional': provisional, 'confirmationRequired': ask,
  'derivedFromExerciseId': from, 'derivedFromExerciseName': fromName, 'equivalenceLevel': null, 'equivalenceGroup': null, 'equivalenceJustification': null,
  'sourcePlannedWorkoutId': source, 'eventDate': date, 'canIdentify': origin == 'DIRECT' && !confirmed, 'canReactivate': origin == 'DIRECT',
};

final effectiveRows = [
  row(537, 'Elevación frontal con mancuerna', 'DIRECT', confirmed: true, date: '2026-11-20'),
  row(1094, 'Flexión en pared versión 2', 'DIRECT', source: 7, date: '2026-11-23'),
  row(1308, 'Puente de glúteos', 'DIRECT', source: 7, date: '2026-11-23'),
  row(538, 'Elevación frontal con mancuerna versión 2', 'EQUIVALENT', confirmed: true, from: 537, fromName: 'Elevación frontal con mancuerna'),
  row(1097, 'Flexión en pared', 'EQUIVALENT', provisional: true, from: 1094, fromName: 'Flexión en pared versión 2'),
  row(988, 'Press de pecho en máquina', 'PRECAUTION', confirmed: true, from: 537, fromName: 'Elevación frontal con mancuerna'),
];
final request = {'plannedWorkoutId': 7, 'eventDate': '2026-11-23', 'confirmationRequired': true, 'exercises': [
  {'exerciseId': 1094, 'exerciseName': 'Flexión en pared versión 2'},
  {'exerciseId': 1308, 'exerciseName': 'Puente de glúteos'},
  {'exerciseId': 878, 'exerciseName': 'Sentadilla con peso corporal'},
]};

class Pain extends PainExclusionRepository {
  Pain() : super(Dio());
  @override
  Future<List<Json>> list() async => const [];
  @override
  Future<List<EffectiveExclusion>> effective() async => [for (final r in effectiveRows) EffectiveExclusion.fromJson(r)];
  @override
  Future<List<PainConfirmationRequest>> confirmationRequests() async => [PainConfirmationRequest.fromJson(request)];
  @override
  Future<IdentificationResult> identify(int exerciseId, {int? plannedWorkoutId, Set<int> unrelated = const {}}) async => IdentificationResult.fromJson({
    'exerciseId': exerciseId, 'noRelacionadosLevantados': [878], 'otrosDeLaSesionSiguenExcluidos': [1308],
    'nota': 'Las variantes equivalentes del ejercicio identificado siguen excluidas hasta que pidas reactivarlo.',
  });
}

class Plans extends PlanRepository {
  Plans(this.plan) : super(Dio());
  final Json? plan;
  @override
  Future<Json?> current() async => plan;
  @override
  Future<List<Json>> adaptations() async => [
    {'weekStartDate': DateTime.now().toIso8601String().substring(0, 10), 'resultado': 'NO_FACTIBLE_POR_SEGURIDAD',
     'motivoTexto': 'No había una alternativa permitida para la sesión del lunes con las exclusiones vigentes.'},
  ];
}

class Workouts extends WorkoutRepository {
  Workouts(this.session) : super(Dio());
  final Json? session;
  @override
  Future<Json?> current() async => session;
}

Json exercise(int pe, int id, String name, int order, {String? block}) => {
  'plannedExerciseId': pe, 'exerciseId': id, 'exerciseName': name, 'exerciseOrder': order, 'prescriptionType': 'SETS_REPS',
  'plannedSets': 3, 'plannedReps': 10, 'restSeconds': 60, 'gifPath': null, 'safetyBlockReason': block,
};
final Json workout = {
  'plannedWorkoutId': 8, 'workoutName': 'Tren superior', 'status': 'IN_PROGRESS', 'focusCode': 'UPPER_BODY', 'expectedDurationMinutes': 45,
  'scheduledDate': DateTime.now().toIso8601String().substring(0, 10), 'expiresAt': DateTime.now().add(const Duration(hours: 8)).toIso8601String(),
  'safetyBlocked': false, 'exercises': [
    exercise(65, 1097, 'Flexión en pared', 1, block: 'dolor_registrado'),
    exercise(60, 878, 'Sentadilla con peso corporal', 2),
  ],
};

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

// The filled button's text style names no font, so a device draws it with the
// platform's (Roboto on Android) and the test engine with boxes: here only,
// draw it with Poppins.
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

Future<void> pump(WidgetTester tester, Widget child, {Json? plan, Json? session, Size size = const Size(400, 860)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final overrides = <Override>[
    painExclusionRepositoryProvider.overrideWithValue(Pain()),
    planRepositoryProvider.overrideWithValue(Plans(plan)),
    workoutRepositoryProvider.overrideWithValue(Workouts(session)),
  ];
  await tester.pumpWidget(RepaintBoundary(key: shot, child: ProviderScope(overrides: overrides,
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: theme, home: child))));
  await tester.pumpAndSettle();
}

void main() {
  final skip = out == null;
  setUpAll(() async { if (out != null) await loadFonts(); });

  testWidgets('01 rutina abierta con un ejercicio bloqueado y otro permitido', (tester) async {
    await pump(tester, PlannedWorkoutPage(workout: workout), plan: {'planId': 3, 'workouts': [workout]},
        session: {'sessionId': 90, 'plannedWorkoutId': 8, 'startedAt': DateTime.now().toIso8601String(), 'exercises': <Json>[]}, size: const Size(400, 1250));
    await capture(tester, '01-rutina-con-ejercicio-bloqueado');
  }, skip: skip);

  testWidgets('02 registrar el ejercicio bloqueado: solo como no realizado', (tester) async {
    await pump(tester, Scaffold(body: Builder(builder: (context) => Center(child: TextButton(
      onPressed: () => showDialog<Json>(context: context, builder: (_) => ExerciseResultDialog(exercise: jsonRows(workout['exercises']).first,
          blockReason: blockExplanation(jsonRows(workout['exercises']).first, effective: [for (final r in effectiveRows) EffectiveExclusion.fromJson(r)]))),
      child: const Text('abrir'))))));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dolor o molestias').last);
    await capture(tester, '02-registro-solo-como-no-realizado');
  }, skip: skip);

  testWidgets('03 Perfil: ejercicios excluidos por dolor', (tester) async {
    await pump(tester, const Scaffold(body: SafeArea(child: PainExclusionsSheet())), size: const Size(400, 1250));
    await capture(tester, '03-perfil-exclusiones-por-dolor');
  }, skip: skip);

  testWidgets('04 confirmación: qué ejercicio fue y cuáles no tuvieron que ver', (tester) async {
    await pump(tester, Scaffold(body: SafeArea(child: PainConfirmationSheet(request: PainConfirmationRequest.fromJson(request)))), size: const Size(400, 980));
    await tester.tap(find.byKey(const Key('painful-1094')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unrelated-878')));
    await capture(tester, '04-confirmacion-de-dolor');
    await tester.ensureVisible(find.text('Enviar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar'));
    await capture(tester, '05-confirmacion-resultado');
  }, skip: skip);

  testWidgets('06 Inicio: petición activa tras dos semanas y adaptación NO_FACTIBLE', (tester) async {
    await pump(tester, const Scaffold(body: SafeArea(child: Padding(padding: EdgeInsets.all(16), child: PainSafetyNotices()))), size: const Size(400, 460));
    await capture(tester, '06-inicio-avisos-o20');
  }, skip: skip);
}
