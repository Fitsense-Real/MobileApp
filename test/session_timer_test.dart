import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'package:fitsense_mobile/features/workouts/presentation/session_timer.dart';

final start = DateTime.utc(2026, 11, 9, 23, 0);

Future<void> pumpFor(WidgetTester tester, Duration d) async {
  // The session clock ticks every second, so pumpAndSettle would never end.
  for (var i = 0; i < d.inMilliseconds ~/ 250; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  group('SessionClock', () {
    test('counts from startedAt and excludes pauses', () {
      final clock = SessionClock(start);
      expect(clock.active(start.add(const Duration(minutes: 5))), const Duration(minutes: 5));
      clock.pause(start.add(const Duration(minutes: 5)));
      expect(clock.isPaused, isTrue);
      expect(clock.active(start.add(const Duration(minutes: 9))), const Duration(minutes: 5), reason: 'frozen while paused');
      clock.resume(start.add(const Duration(minutes: 9)));
      expect(clock.active(start.add(const Duration(minutes: 12))), const Duration(minutes: 8));
      expect(clock.suggestedActiveMinutes(start.add(const Duration(minutes: 12, seconds: 31))), 9);
    });

    test('never negative and at least one suggested minute', () {
      final clock = SessionClock(start);
      expect(clock.active(start.subtract(const Duration(seconds: 30))), Duration.zero, reason: 'device clock behind the server');
      expect(clock.suggestedActiveMinutes(start.add(const Duration(seconds: 10))), 1);
    });

    test('clocks survive leaving the routine until the session ends', () {
      final a = SessionClocks.of(8, start)..pause(start);
      expect(identical(SessionClocks.of(8, start), a), isTrue);
      SessionClocks.clear(8);
      expect(identical(SessionClocks.of(8, start), a), isFalse);
      SessionClocks.clear(8);
    });

    test('format', () {
      expect(formatClock(const Duration(seconds: 65)), '01:05');
      expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });
  });

  testWidgets('the bar ticks and pauses', (tester) async {
    var now = start.add(const Duration(minutes: 3));
    final clock = SessionClock(start);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SessionTimerBar(clock: clock, now: () => now))));
    expect(find.text('03:00'), findsOneWidget);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('03:02'), findsOneWidget);
    await tester.tap(find.text('Pausar')); await tester.pump();
    expect(find.text('En pausa'), findsOneWidget);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('03:02'), findsOneWidget);
    await tester.tap(find.text('Reanudar')); await tester.pump();
    now = now.add(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('03:07'), findsOneWidget);
  });

  testWidgets('countdown ends with "¡Listo!", can add 15 s or be skipped', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) =>
        TextButton(onPressed: () => showCountdown(context, seconds: 30, title: 'Descanso'), child: const Text('Open'))))));
    await tester.tap(find.text('Open')); await tester.pump();
    expect(find.text('00:30'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('00:20'), findsOneWidget);
    await tester.tap(find.text('+15 s')); await tester.pump();
    expect(find.text('00:35'), findsOneWidget);
    await pumpFor(tester, const Duration(seconds: 36));
    expect(find.text('¡Listo!'), findsOneWidget);
    expect(find.text('+15 s'), findsNothing);
    await tester.tap(find.text('Continuar')); await tester.pumpAndSettle();
    expect(find.byType(CountdownDialog), findsNothing);

    await tester.tap(find.text('Open')); await tester.pump();
    await tester.tap(find.text('Saltar')); await tester.pumpAndSettle();
    expect(find.byType(CountdownDialog), findsNothing);
  });

  group('live session', () {
    const squat = {'plannedExerciseId': 500, 'exerciseId': 76, 'exerciseName': 'Sentadilla', 'exerciseOrder': 1, 'prescriptionType': 'SETS_REPS', 'plannedSets': 3, 'plannedReps': 12, 'restSeconds': 60};
    const plank = {'plannedExerciseId': 501, 'exerciseId': 77, 'exerciseName': 'Plancha', 'exerciseOrder': 2, 'prescriptionType': 'DURATION', 'plannedSets': 3, 'plannedDurationSeconds': 30, 'restSeconds': 45};

    testWidgets('shows the clock, rest and timed-set buttons, and suggests active minutes on finish', (tester) async {
      tester.view.physicalSize = const Size(500, 1800); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final startedAt = DateTime.now().subtract(const Duration(minutes: 10));
      final repository = LiveSession(startedAt);
      await tester.pumpWidget(ProviderScope(overrides: [workoutRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: PlannedWorkoutPage(workout: {'plannedWorkoutId': 21, 'workoutName': 'Piernas', 'status': 'IN_PROGRESS', 'exercises': [squat, plank]}))));
      await pumpFor(tester, const Duration(seconds: 1));
      expect(find.text('Tiempo activo'), findsOneWidget);
      expect(find.textContaining('10:0'), findsOneWidget);
      expect(find.text('Descanso 60 s'), findsOneWidget);
      expect(find.text('Descanso 45 s'), findsOneWidget);
      expect(find.text('Serie de 30 s'), findsOneWidget, reason: 'only the timed exercise');

      await tester.tap(find.text('Serie de 30 s')); await tester.pump();
      expect(find.text('00:30'), findsOneWidget);
      await tester.tap(find.text('Saltar')); await pumpFor(tester, const Duration(seconds: 1));

      await tester.ensureVisible(find.text('Finalizar sesión'));
      await tester.tap(find.text('Finalizar sesión')); await pumpFor(tester, const Duration(seconds: 1));
      final minutes = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Minutos activos (opcional)'));
      expect(minutes.controller!.text, '10');
      expect(find.text('Según el cronómetro, sin pausas'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>).first); await pumpFor(tester, const Duration(seconds: 1));
      await tester.tap(find.text('7').last); await pumpFor(tester, const Duration(seconds: 1));
      await tester.tap(find.text('Finalizar')); await pumpFor(tester, const Duration(seconds: 1));
      expect(repository.finished, {'sessionRpe': 7, 'activeMinutes': 10});
      expect(find.text('Tiempo activo'), findsNothing, reason: 'the clock stops with the session');
    });
  });
}

class LiveSession extends WorkoutRepository {
  LiveSession(this.startedAt) : super(Dio());
  final DateTime startedAt;
  Json? finished;
  Json get session => {
    'sessionId': 8, 'plannedWorkoutId': 21, 'status': 'IN_PROGRESS', 'startedAt': startedAt.toUtc().toIso8601String(),
    'exercises': [
      {'plannedExerciseId': 500, 'actualSets': 3, 'actualRepsTotal': 36, 'status': 'COMPLETED', 'completionPercentage': 100},
      {'plannedExerciseId': 501, 'actualSets': 3, 'actualDurationSeconds': 90, 'status': 'COMPLETED', 'completionPercentage': 100},
    ],
  };
  @override
  Future<Json?> current() async => session;
  @override
  Future<Json> finish(Object sessionId, Json body) async {
    finished = body;
    return {...session, 'status': 'COMPLETED', 'completionPercentage': 100};
  }
}
