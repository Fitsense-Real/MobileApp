// Mobile-M3: exercise view (M-06 prepared, M-07, M-08, M-09).
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/providers/dio_provider.dart';
import 'package:fitsense_mobile/features/workouts/domain/effort_guidance.dart';
import 'package:fitsense_mobile/features/workouts/domain/exercise_labels.dart';
import 'package:fitsense_mobile/features/workouts/presentation/exercise_detail_page.dart';
import 'package:fitsense_mobile/features/workouts/presentation/exercise_media.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'support/fake_backend.dart';

/// `effortGuidance` exactly as Backend generation 77b9df3 returned it for a
/// rule-engine plan (contratos-backend-local.txt §4).
const guidanceJson = {
  'repsInReserve': '3',
  'setsRepsText': 'Termina cada serie sintiendo que podrías hacer unas 3 repeticiones más, con buena técnica. No hace falta llegar al límite.',
  'durationText': 'En los ejercicios por tiempo, mantén la posición con buena técnica y termina cuando todavía podrías aguantar unos segundos más.',
  'loadText': 'El peso sugerido es solo una referencia: elige el peso con el que cumplas las repeticiones dejando ese margen.',
};

Map<String, dynamic> exercise(int id, String name, {String type = 'SETS_REPS', String equipment = 'body weight', String bodyPart = 'upper legs', int order = 1, String? notes}) => {
      'plannedExerciseId': 900 + id, 'exerciseId': id, 'exerciseName': name, 'targetMuscle': 'quads', 'bodyPart': bodyPart,
      'equipment': equipment, 'difficultyLevel': 1, 'exerciseOrder': order, 'prescriptionType': type,
      'plannedSets': 2, 'plannedReps': type == 'SETS_REPS' ? 8 : null, 'plannedDurationSeconds': type == 'DURATION' ? 90 : null,
      'targetLoadKg': null, 'restSeconds': 90, 'notes': notes, 'gifPath': 'videos/1688-K9VL0Jq.gif', 'imagePath': 'images/1688-K9VL0Jq.jpg',
      'mediaAttribution': '© Gym visual — https://gymvisual.com/', 'safetyBlockReason': null,
    };

final routine = <String, dynamic>{
  'plannedWorkoutId': 21, 'workoutName': 'Cuerpo completo', 'status': 'SCHEDULED', 'focusCode': 'FULL_BODY',
  'scheduledDate': '2030-01-07', 'expiresAt': '2030-01-07T23:59:00-05:00', 'expectedDurationMinutes': 40,
  'exercises': [
    exercise(1059, 'Zancada con giro'),
    exercise(783, 'Press en W con mancuerna', equipment: 'dumbbell', bodyPart: 'shoulders', order: 2),
    exercise(3360, 'Gateo de oso', type: 'DURATION', bodyPart: 'cardio', order: 3, notes: 'Intensidad moderada: RPE 5-6, deberias poder hablar con frases cortas.'),
  ],
};

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ScriptedBackend> open(WidgetTester tester, {Object? guidance = guidanceJson, Size size = const Size(1080, 6000), double ratio = 3}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final backend = ScriptedBackend((o) => switch (o.path) {
      '/sessions/current' => (status: 204, body: null),
      '/users/me/plan/current' => (status: 200, body: {'planId': 1, 'workouts': [routine], 'effortGuidance': guidance}),
      '/catalog/equipment-types' => (status: 200, body: [
          {'code': 'body weight', 'nameEs': 'Peso corporal', 'requiresGym': false},
          {'code': 'dumbbell', 'nameEs': 'Mancuerna', 'requiresGym': false},
        ]),
      '/catalog/exercises/1059' => (status: 200, body: {'exerciseId': 1059, 'name': 'Zancada con giro', 'targetMuscle': 'quads', 'synergistMuscle': 'abs',
          'secondaryMuscles': ['quadriceps', 'glutes', 'hamstrings', 'unknown-muscle'], 'instructions': 'Ponte de pie con los pies separados al ancho de las caderas.', 'mediaAttribution': '© Gym visual'}),
      '/catalog/exercises/783' => (status: 200, body: {'exerciseId': 783, 'name': 'Press en W con mancuerna', 'targetMuscle': 'delts', 'secondaryMuscles': ['triceps'], 'instructions': 'Sujeta una mancuerna en cada mano.'}),
      '/users/me/pain-exclusions/effective' => (status: 200, body: []),
      _ => (status: 200, body: []),
    });
    await tester.pumpWidget(ProviderScope(overrides: [dioProvider.overrideWithValue(scriptedDio(backend))],
        child: MaterialApp(theme: AppTheme.light, home: PlannedWorkoutPage(workout: routine))));
    await tester.pumpAndSettle();
    return backend;
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  }

  group('M-07 effort guidance', () {
    testWidgets('the routine shows the backend texts that apply, verbatim, once', (tester) async {
      await open(tester);
      final card = find.byKey(const Key('effort-guidance'));
      expect(card, findsOneWidget);
      for (final text in [guidanceJson['setsRepsText']!, guidanceJson['durationText']!, guidanceJson['loadText']!]) {
        expect(find.descendant(of: card, matching: find.text(text)), findsOneWidget);
      }
      await leave(tester);
    });

    testWidgets('without guidance in the plan nothing is invented', (tester) async {
      await open(tester, guidance: null);
      expect(find.byKey(const Key('effort-guidance')), findsNothing);
      expect(find.textContaining('esforzarte'), findsNothing);
      await leave(tester);
    });

    test('per exercise: its prescription type, and the load text only with external load', () {
      final g = EffortGuidance.fromJson(guidanceJson)!;
      expect(g.forExercise(exercise(1, 'a')), [guidanceJson['setsRepsText']]);
      expect(g.forExercise(exercise(2, 'b', equipment: 'dumbbell')), [guidanceJson['setsRepsText'], guidanceJson['loadText']]);
      expect(g.forExercise(exercise(3, 'c', type: 'DURATION')), [guidanceJson['durationText']]);
      expect(EffortGuidance.fromJson({'repsInReserve': '2'}), isNull, reason: 'no text to show');
    });
  });

  group('M-09 exercise screen', () {
    testWidgets('«Ver instrucciones» opens the full exercise: media, prescription, rest, equipment, zone, guidance, instructions', (tester) async {
      await open(tester);
      await tester.tap(find.text('Ver instrucciones').first);
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseDetailPage), findsOneWidget);
      expect(find.byType(ExerciseMedia), findsOneWidget, reason: 'the movement stays visible with the text');
      expect(find.text('Ejercicio 1 de 3'), findsOneWidget);
      expect(find.text('Descanso entre series: 1 min 30 s'), findsOneWidget);
      expect(find.text('Equipo: Peso corporal'), findsOneWidget);
      expect(find.text('Zona que trabaja: Piernas (muslos)'), findsOneWidget);
      expect(find.text(guidanceJson['setsRepsText']!), findsOneWidget);
      expect(find.text('Ponte de pie con los pies separados al ancho de las caderas.'), findsOneWidget);
      expect(find.text('Músculo principal: cuádriceps'), findsOneWidget);
      expect(find.text('Secundarios: abdominales, glúteos, isquiotibiales'), findsOneWidget, reason: 'translated, repeated main muscle and unknown codes dropped');
      expect(find.text('© Gym visual — https://gymvisual.com/'), findsOneWidget, reason: 'attribution kept');
      await leave(tester);
    });

    testWidgets('previous/next move through the routine and back returns to it intact', (tester) async {
      await open(tester);
      await tester.tap(find.text('Ver instrucciones').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ejercicio siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Ejercicio 2 de 3'), findsOneWidget);
      expect(find.text('Equipo: Mancuerna'), findsOneWidget);
      expect(find.text(guidanceJson['loadText']!), findsOneWidget);
      await tester.tap(find.byTooltip('Ejercicio siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Indicación del plan: Intensidad moderada: RPE 5-6, deberias poder hablar con frases cortas.'), findsOneWidget);
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right)).onPressed, isNull, reason: 'last exercise');
      await tester.tap(find.byTooltip('Volver a la rutina'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseDetailPage), findsNothing);
      expect(find.text('Cuerpo completo'), findsOneWidget);
      await leave(tester);
    });

    testWidgets('the animation can be paused and resumed (TickerMode), and enlarged', (tester) async {
      await open(tester);
      await tester.tap(find.text('Ver instrucciones').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pausar animación'));
      await tester.pump();
      expect(tester.widget<ExerciseMedia>(find.byType(ExerciseMedia)).paused, isTrue);
      expect(find.text('Reanudar animación'), findsOneWidget);
      await tester.tap(find.text('Ampliar'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      await leave(tester);
    });

    testWidgets('tapping the animation in the routine also opens the exercise', (tester) async {
      await open(tester);
      await tester.tap(find.byType(ExerciseMedia).first);
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseDetailPage), findsOneWidget);
      await leave(tester);
    });

    testWidgets('the routine card says the rest is between series and names the equipment in Spanish', (tester) async {
      await open(tester);
      expect(find.text('Descanso entre series: 1 min 30 s'), findsNWidgets(2));
      expect(find.text('Equipo: Mancuerna'), findsOneWidget);
      expect(find.textContaining('dumbbell'), findsNothing);
      await leave(tester);
    });

    testWidgets('small phone (320 × 568): the exercise screen lays out without overflow', (tester) async {
      await open(tester, size: const Size(640, 1136), ratio: 2);
      Future<void> dragUntil(Finder target) async {
        for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
          await tester.drag(find.byType(Scrollable).last, const Offset(0, -250));
          await tester.pumpAndSettle();
        }
      }
      await dragUntil(find.text('Ver instrucciones').hitTestable());
      await tester.tap(find.text('Ver instrucciones').hitTestable().first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ExerciseDetailPage), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Ejercicio \d de 3$')), findsOneWidget);
      await dragUntil(find.text('Cómo se hace').hitTestable());
      expect(find.text('Cómo se hace'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await leave(tester);
    });
  });

  group('M-06 media source (prepared, not resolved)', () {
    test('authorised https addresses from the backend are preferred', () {
      final s = ExerciseMediaSource.of({'gifUrl': 'https://medios.kora.test/a.gif', 'imageUrl': 'https://medios.kora.test/a.jpg', 'gifPath': 'videos/x.gif'});
      expect(s.gifUrl, 'https://medios.kora.test/a.gif');
      expect(s.imageUrl, 'https://medios.kora.test/a.jpg');
    });
    test('without them the current construction is kept (legacy on) or nothing is shown (legacy off)', () {
      final e = {'gifPath': 'videos/1688-K9VL0Jq.gif', 'imagePath': 'images/1688-K9VL0Jq.jpg', 'gifUrl': 'http://inseguro.test/a.gif'};
      expect(ExerciseMediaSource.of(e).gifUrl, 'https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/videos/1688-K9VL0Jq.gif');
      expect(ExerciseMediaSource.of(e).imageUrl, 'https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main/images/1688-K9VL0Jq.jpg');
      expect(ExerciseMediaSource.of(e, legacy: false).isEmpty, isTrue, reason: 'http and paths are not authorised addresses');
    });
    testWidgets('animation and still image both unavailable: a text and a retry, the card keeps working', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ExerciseMedia(source: ExerciseMediaSource.of(routine['exercises'][0] as Map<String, dynamic>)))));
      for (var i = 0; i < 6; i++) { await tester.pump(const Duration(milliseconds: 200)); }
      expect(find.text('No se pudo cargar la imagen del ejercicio. Revisa tu conexión.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('M-08 labels', () {
    test('known codes in Spanish, unknown ones omitted, rest in minutes', () {
      expect(muscleList(['pectorals', 'triceps', 'shoulders', 'pectorals', 'xyz']), ['pectorales', 'tríceps', 'hombros']);
      expect(bodyPartLabel('waist'), 'Abdomen y cintura');
      expect(bodyPartLabel('unknown'), isNull);
      expect(restLabel(45), '45 s');
      expect(restLabel(120), '2 min');
      expect(restLabel(90), '1 min 30 s');
    });
  });
}
