import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/workouts/presentation/exercise_media.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';

/// The exercise GIF only illustrates what the card already says in text, so
/// screen readers must not announce the card as an image. Name, sets, reps or
/// time, rest and the controls stay readable.
void main() {
  const exercise = <String, dynamic>{
    'plannedExerciseId': 31, 'exerciseId': 5, 'exerciseName': 'Sentadilla de baño',
    'plannedSets': 3, 'plannedReps': 6, 'restSeconds': 150, 'gifPath': 'videos/0001-abc.gif',
  };
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(const ProviderScope(child: MaterialApp(home: PlannedWorkoutPage(workout: {
    'plannedWorkoutId': 21, 'workoutName': 'Cuerpo completo', 'status': 'SCHEDULED',
    'scheduledDate': '2030-01-07', 'expiresAt': '2030-01-07T23:59:00-05:00', 'exercises': [exercise],
  }))));

  testWidgets('the GIF is excluded from semantics (decorative: the text says the same)', (tester) async {
    await pump(tester);
    final image = tester.widget<Image>(find.descendant(of: find.byType(ExerciseMedia), matching: find.byType(Image)));
    expect(image.excludeFromSemantics, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('the card is not announced as an image and keeps name, prescription, rest and controls', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await tester.pump(const Duration(seconds: 1));
    final card = tester.getSemantics(find.text('Sentadilla de baño'));
    expect(card.flagsCollection.isImage, isFalse);
    expect(card.label, contains('Sentadilla de baño'));
    expect(card.label, contains('3 series · 6 repeticiones por serie'));
    expect(card.label, contains('Descanso entre series: 2 min 30 s'));
    expect(find.bySemanticsLabel('Ver instrucciones'), findsOneWidget);
    // Nothing anywhere on the page is an image node coming from the GIF.
    final images = <SemanticsNode>[];
    void walk(SemanticsNode n) { if (n.flagsCollection.isImage) images.add(n); n.visitChildren((c) { walk(c); return true; }); }
    walk(tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!);
    expect(images, isEmpty);
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });
}
