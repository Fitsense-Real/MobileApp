import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/domain/workout_rules.dart' show plannedTotal;
import 'package:fitsense_mobile/features/workouts/presentation/exercise_result_dialog.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';

// D-M1: a timed exercise completed in full is recorded with the seconds of ALL
// its sets (3 × 120 s = 360 s), the same denominator the backend uses
// (planning PlannedExerciseTarget.plannedDurationTotal: (plannedSets ?? 1) ×
// plannedDurationSeconds; repetitions: plannedSets × plannedReps, 0 if either
// is missing). A partial result never carries time that was not done.

const plank = <String, dynamic>{
  'plannedExerciseId': 41, 'exerciseName': 'Plancha', 'prescriptionType': 'DURATION',
  'plannedSets': 3, 'plannedReps': null, 'plannedDurationSeconds': 120, 'targetLoadKg': null,
};
const squat = <String, dynamic>{
  'plannedExerciseId': 42, 'exerciseName': 'Sentadilla', 'prescriptionType': 'SETS_REPS',
  'plannedSets': 3, 'plannedReps': 12, 'plannedDurationSeconds': null, 'targetLoadKg': 10,
};

Future<void> openDialog(WidgetTester tester, Json exercise, void Function(Json?) done, {Json? existing}) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
    onPressed: () async => done(await showDialog<Json>(context: context, builder: (_) => ExerciseResultDialog(exercise: exercise, existing: existing))),
    child: const Text('Open'),
  )))));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> chooseReason(WidgetTester tester) async {
  await tap(tester, find.byType(DropdownButtonFormField<String>));
  await tester.tap(find.text('Fatiga').last);
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(find.widgetWithText(TextFormField, label)).controller!.text;

const secondsLabel = 'Duración total realizada (segundos, todas las series)';
const repsLabel = 'Repeticiones totales (todas las series)';
const setsLabel = 'Series realizadas';

void main() {
  group('«Lo completé» records the whole prescription (backend denominator)', () {
    test('3 series × 120 s = 360 s, not the 120 s of one series', () {
      expect(prescribedResult(plank), {'actualSets': 3, 'actualRepsTotal': 0, 'actualDurationSeconds': 360, 'actualLoadKg': null, 'skipReason': null});
      expect(plannedTotal(plank), 360);
    });

    test('repetitions: 3 × 12 = 36, no seconds', () {
      expect(prescribedResult(squat), {'actualSets': 3, 'actualRepsTotal': 36, 'actualDurationSeconds': 0, 'actualLoadKg': 10, 'skipReason': null});
    });

    test('series × seconds for any amounts', () {
      for (final sets in [1, 2, 4]) {
        for (final seconds in [20, 45, 120]) {
          final ex = {...plank, 'plannedSets': sets, 'plannedDurationSeconds': seconds};
          expect(prescribedResult(ex)['actualDurationSeconds'], sets * seconds);
          expect(prescribedResult(ex)['actualSets'], sets);
        }
      }
    });

    test('timed exercise without an explicit number of series: one series, as the backend (plannedSets ?? 1)', () {
      final ex = {...plank, 'plannedSets': null, 'plannedDurationSeconds': 45};
      expect(prescribedResult(ex), {'actualSets': 1, 'actualRepsTotal': 0, 'actualDurationSeconds': 45, 'actualLoadKg': null, 'skipReason': null});
      expect(plannedTotal(ex), 45);
    });

    test('missing amounts: 0 like the backend (no duration; repetitions without series)', () {
      expect(plannedTotal({...plank, 'plannedDurationSeconds': null}), 0);
      expect(plannedTotal({...squat, 'plannedSets': null}), 0);
    });
  });

  group('dialog', () {
    testWidgets('«Lo completé» on 3 × 120 s shows and saves 360 s', (tester) async {
      Json? result;
      await openDialog(tester, plank, (v) => result = v);
      expect(find.text('3 series · 120 s por serie'), findsOneWidget);
      await tap(tester, find.text('Lo completé'));
      expect(fieldText(tester, secondsLabel), '360');
      await tap(tester, find.text('Guardar'));
      expect(result?['actualDurationSeconds'], 360);
      expect(result?['actualSets'], 3);
    });

    testWidgets('«Lo completé» then «Lo hice parcialmente»: the plan amounts are cleared, only what was done is saved', (tester) async {
      Json? result;
      await openDialog(tester, plank, (v) => result = v);
      await tap(tester, find.text('Lo completé'));
      await tap(tester, find.text('Lo hice parcialmente'));
      expect(fieldText(tester, secondsLabel), isEmpty, reason: 'never 360 s that were not done');
      expect(fieldText(tester, setsLabel), isEmpty);
      await chooseReason(tester);
      await tap(tester, find.text('Guardar'));
      expect(result, isNull, reason: 'nothing done was entered');
      expect(find.text('Registra al menos una serie, repetición o segundo realizado.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, setsLabel), '2');
      await tap(tester, find.text('Guardar'));
      expect(result, isNull, reason: 'series without seconds would be stored as not done');
      expect(find.textContaining('cuántos segundos hiciste en total'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, secondsLabel), '150');
      await tap(tester, find.text('Guardar'));
      expect(result, {'actualSets': 2, 'actualRepsTotal': 0, 'actualDurationSeconds': 150, 'actualLoadKg': null, 'skipReason': 'FATIGUE'});
    });

    testWidgets('«No lo hice» then «Lo hice parcialmente»: no zeros left to save', (tester) async {
      Json? result;
      await openDialog(tester, plank, (v) => result = v);
      await tap(tester, find.text('No lo hice'));
      await tap(tester, find.text('Lo hice parcialmente'));
      expect(fieldText(tester, secondsLabel), isEmpty);
      await tester.enterText(find.widgetWithText(TextFormField, secondsLabel), '100');
      await chooseReason(tester);
      await tap(tester, find.text('Guardar'));
      expect(result?['actualDurationSeconds'], 100);
    });

    testWidgets('a partial with the whole prescription asks for «Lo completé» (timed)', (tester) async {
      Json? result;
      await openDialog(tester, plank, (v) => result = v);
      await tap(tester, find.text('Lo hice parcialmente'));
      await tester.enterText(find.widgetWithText(TextFormField, secondsLabel), '360');
      await chooseReason(tester);
      await tap(tester, find.text('Guardar'));
      expect(result, isNull);
      expect(find.textContaining('360 s en total'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, secondsLabel), '359');
      await tap(tester, find.text('Guardar'));
      expect(result?['actualDurationSeconds'], 359);
    });

    testWidgets('repetitions: partial below the prescription is saved; the whole prescription asks for «Lo completé»', (tester) async {
      Json? result;
      await openDialog(tester, squat, (v) => result = v);
      await tap(tester, find.text('Lo hice parcialmente'));
      await tester.enterText(find.widgetWithText(TextFormField, repsLabel), '36');
      await chooseReason(tester);
      await tap(tester, find.text('Guardar'));
      expect(result, isNull);
      expect(find.textContaining('36 repeticiones en total'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, repsLabel), '20');
      await tap(tester, find.text('Guardar'));
      expect(result?['actualRepsTotal'], 20);
      expect(result?['actualDurationSeconds'], 0);
    });

    testWidgets('editing a saved partial keeps its real amounts', (tester) async {
      Json? result;
      await openDialog(tester, plank, (v) => result = v,
          existing: {'actualSets': 2, 'actualRepsTotal': 0, 'actualDurationSeconds': 150, 'skipReason': 'FATIGUE'});
      await tap(tester, find.text('Lo hice parcialmente'));
      expect(fieldText(tester, secondsLabel), '150');
      await tap(tester, find.text('Guardar'));
      expect(result?['actualDurationSeconds'], 150);
    });
  });

  group('whole workout report (complete and partial sessions)', () {
    Future<ReportFake> report(WidgetTester tester, List<Future<void> Function()> perExercise) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = ReportFake();
      await tester.pumpWidget(ProviderScope(
        overrides: [workoutRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PlannedWorkoutPage(workout: {
          'plannedWorkoutId': 21, 'workoutName': 'Fuerza y core', 'status': 'SKIPPED', 'expiresAt': '2026-01-01T23:59:00-05:00',
          'exercises': [squat, plank],
        })),
      ));
      await tester.pumpAndSettle();
      await tap(tester, find.text('Ya lo hice · registrar entrenamiento'));
      for (var i = 0; i < perExercise.length; i++) {
        await tap(tester, find.text('Registrar ejercicio').at(i));
        await perExercise[i]();
        await tap(tester, find.text('Usar resultado'));
      }
      await tap(tester, find.text('Guardar entrenamiento'));
      await tap(tester, find.text('Elegir fecha y hora del entrenamiento'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tap(tester, find.byType(DropdownButtonFormField<int>).first);
      await tester.tap(find.text('6').last);
      await tester.pumpAndSettle();
      await tap(tester, find.text('Finalizar'));
      return repository;
    }

    testWidgets('complete session: 36 repetitions and 360 s are sent', (tester) async {
      final repository = await report(tester, [
        () => tap(tester, find.text('Lo completé')),
        () => tap(tester, find.text('Lo completé')),
      ]);
      final sent = (repository.body!['exercises'] as List).cast<Json>();
      expect(sent.firstWhere((e) => e['plannedExerciseId'] == 42)['actualRepsTotal'], 36);
      expect(sent.firstWhere((e) => e['plannedExerciseId'] == 41)['actualDurationSeconds'], 360);
    });

    testWidgets('partial session: the timed exercise sends only the 150 s done', (tester) async {
      final repository = await report(tester, [
        () => tap(tester, find.text('Lo completé')),
        () async {
          await tap(tester, find.text('Lo completé'));
          await tap(tester, find.text('Lo hice parcialmente'));
          await tester.enterText(find.widgetWithText(TextFormField, setsLabel), '2');
          await tester.enterText(find.widgetWithText(TextFormField, secondsLabel), '150');
          await chooseReason(tester);
        },
      ]);
      final sent = (repository.body!['exercises'] as List).cast<Json>();
      expect(sent.firstWhere((e) => e['plannedExerciseId'] == 42)['actualRepsTotal'], 36);
      final timed = sent.firstWhere((e) => e['plannedExerciseId'] == 41);
      expect(timed['actualDurationSeconds'], 150);
      expect(timed['actualSets'], 2);
      expect(timed['skipReason'], 'FATIGUE');
    });
  });
}

class ReportFake extends WorkoutRepository {
  ReportFake() : super(Dio());
  Json? body;
  @override
  Future<Json?> current() async => null;
  @override
  Future<Json> report(Object workoutId, Json data) async {
    body = data;
    return {'sessionId': 18, 'plannedWorkoutId': workoutId, 'completionPercentage': 100, 'exercises': data['exercises']};
  }
}
