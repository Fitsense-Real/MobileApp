import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'package:fitsense_mobile/features/dashboard/data/dashboard_repository.dart';
import 'package:fitsense_mobile/features/workouts/presentation/exercise_media.dart';
import 'package:fitsense_mobile/features/workouts/presentation/exercise_result_dialog.dart';

class ReportFake extends WorkoutRepository {
  ReportFake() : super(Dio());
  Json? body;
  Object? id;
  @override
  Future<Json?> current() async => null;
  @override
  Future<Json> report(Object workoutId, Json data) async {
    id = workoutId; body = data;
    return {'sessionId': 18, 'plannedWorkoutId': workoutId, 'completionPercentage': 100, 'exercises': data['exercises']};
  }
}

void main() {
  const exercise = <String, dynamic>{'plannedExerciseId': 31, 'exerciseName': 'Sentadilla del plan', 'plannedSets': 3, 'plannedReps': 10, 'targetLoadKg': 12};
  test('GIF resolves filename, relative path and GitHub link without hardcoded exercise', () {
    const expected = 'https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/videos/0001-2gPfomN.gif';
    expect(exerciseGifUrl('0001-2gPfomN.gif'), expected);
    expect(exerciseGifUrl('videos/0001-2gPfomN.gif'), expected);
    expect(exerciseGifUrl('https://github.com/hasaneyldrm/exercises-dataset/blob/main/videos/0001-2gPfomN.gif?raw=true'), expected);
    expect(exerciseGifUrl('another.gif'), contains('/another.gif'));
    expect(exerciseGifUrl(null), isNull);
    expect(exerciseGifUrl('file:///private.gif'), isNull);
  });
  test('Unrecorded, skipped, partial and completed are distinguished', () {
    expect(resultLabel(null), 'Sin registrar');
    expect(resultLabel({'actualSets': 0}), 'Sin registrar');
    expect(resultLabel({'actualSets': 0, 'skipReason': 'FATIGUE'}), 'No realizado');
    expect(resultLabel({'actualSets': 1, 'completionPercentage': 33}), 'Parcial');
    expect(resultLabel({'actualSets': 3, 'completionPercentage': 100}), 'Completado');
  });
  test('Complete quantities follow each exercise, never a fixed 18', () {
    for (final sets in [2, 3, 4]) {
      for (final reps in [6, 10, 12]) {
        final result = prescribedResult({'plannedSets': sets, 'plannedReps': reps});
        expect(result['actualSets'], sets);
        expect(result['actualRepsTotal'], sets * reps);
      }
    }
  });
  test('Prescription shows repetitions or explicitly identifies timed exercises', () {
    expect(exercisePrescription({'plannedSets': 3, 'plannedReps': 10}), contains('10 repeticiones por serie'));
    expect(exercisePrescription({'plannedSets': 3, 'plannedDurationSeconds': 90}), contains('Por tiempo · sin repeticiones asignadas'));
    expect(exercisePrescription({'plannedSets': 3, 'plannedDurationSeconds': 90}), contains('90 s'));
  });
  Future<void> open(WidgetTester tester, void Function(Json?) done) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () async { done(await showDialog<Json>(context: context, builder: (_) => const ExerciseResultDialog(exercise: exercise))); }, child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pumpAndSettle();
  }
  testWidgets('Completed uses actual prescription only after explicit selection', (tester) async {
    Json? result;
    await open(tester, (value) => result = value);
    await tester.tap(find.text('Guardar')); await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Indica si realizaste el ejercicio.'), findsOneWidget);
    await tester.tap(find.text('Lo completé')); await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar')); await tester.pumpAndSettle();
    expect(result, {'actualSets': 3, 'actualRepsTotal': 30, 'actualDurationSeconds': 0, 'actualLoadKg': 12, 'skipReason': null});
  });
  testWidgets('Not performed requires reason and clears prescribed amounts', (tester) async {
    Json? result;
    await open(tester, (value) => result = value);
    await tester.tap(find.text('Lo completé')); await tester.pumpAndSettle();
    await tester.tap(find.text('No lo hice')); await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar')); await tester.pumpAndSettle();
    expect(find.text('Selecciona un motivo'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('Fatiga').last); await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar')); await tester.pumpAndSettle();
    expect(result, {'actualSets': 0, 'actualRepsTotal': 0, 'actualDurationSeconds': 0, 'actualLoadKg': 0, 'skipReason': 'FATIGUE'});
  });
  testWidgets('Expired workout report submits explicit results with selected date and effort', (tester) async {
    tester.view.physicalSize = const Size(600, 1100); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final repository = ReportFake();
    await tester.pumpWidget(ProviderScope(overrides: [workoutRepositoryProvider.overrideWithValue(repository)], child: const MaterialApp(home: PlannedWorkoutPage(workout: {'plannedWorkoutId': 21, 'workoutName': 'Entrenamiento anterior', 'status': 'EXPIRED', 'exercises': [exercise]}))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya lo hice · registrar entrenamiento')); await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar entrenamiento')); await tester.pumpAndSettle();
    expect(find.text('Indica el resultado de cada ejercicio antes de guardar.'), findsOneWidget);
    await tester.tap(find.text('Registrar ejercicio')); await tester.pumpAndSettle();
    await tester.tap(find.text('Lo completé')); await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Repeticiones por serie')).controller!.text, '10');
    await tester.tap(find.text('Usar resultado')); await tester.pumpAndSettle();
    expect(repository.body, isNull);
    await tester.tap(find.text('Guardar entrenamiento')); await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir fecha y hora del entrenamiento')); await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first); await tester.pumpAndSettle();
    await tester.tap(find.text('7').last); await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar')); await tester.pumpAndSettle();
    expect(repository.id, 21);
    expect(repository.body?['sessionRpe'], 7);
    expect(DateTime.tryParse(repository.body?['performedAt'] ?? ''), isNotNull);
    expect((repository.body?['exercises'] as List).single, {...prescribedResult(exercise), 'plannedExerciseId': 31});
    expect(find.text('Sesión guardada · 100% completado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
