import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/onboarding/presentation/generating_plan.dart';
import 'package:fitsense_mobile/features/onboarding/presentation/kapi_fun_messages.dart';
import 'package:fitsense_mobile/features/onboarding/presentation/onboarding_page.dart';
import 'package:fitsense_mobile/features/welcome/data/plan_generation_repository.dart';
import 'package:fitsense_mobile/features/welcome/domain/generation_operation.dart';
import 'package:fitsense_mobile/features/welcome/presentation/welcome_routes.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';
import 'package:fitsense_mobile/shared/widgets/mascot/kora_mascot.dart';
import 'support/welcome_fakes.dart';

// Everything here is simulated: no backend, no Replicate, no network.

class _Profile extends ProfileRepository {
  _Profile({this.existing, this.saveError}) : super(Dio());
  final Map<String, dynamic>? existing;
  final Object? saveError;
  int saves = 0;
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>?> fetch() async => existing;
  @override
  Future<List<Equipment>> equipment() async => const [
    Equipment(bodyWeightCode, 'Peso corporal', false),
    Equipment('band', 'Banda', false),
    Equipment('dumbbell', 'Mancuerna', false),
    Equipment('machine', 'Máquina', true),
  ];
  @override
  Future<Map<String, dynamic>?> save(Map<String, dynamic> body, {required bool exists}) async {
    saves++;
    if (saveError != null) throw saveError!;
    saved = body;
    return body;
  }
}

/// The backend answers the generation request after [delay] (simulated time).
class _TimedGeneration extends FakeGeneration {
  _TimedGeneration(this.delay, GenerationOperation answer) : super(starts: [answer]);
  final Duration delay;
  @override
  Future<GenerationOperation> start() async {
    await Future<void>.delayed(delay);
    return super.start();
  }
}

GoRouter _router() => GoRouter(initialLocation: '/onboarding', routes: [
  GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingPage()),
  GoRoute(path: welcomeTourRoute, builder: (_, __) => const Scaffold(body: Text('Recorrido del usuario'))),
  GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Inicio de sesión'))),
  GoRoute(path: '/account-setup', builder: (_, __) => const Scaffold(body: Text('Revisando tu cuenta'))),
]);

Future<GoRouter> _pumpOnboarding(WidgetTester tester, _Profile profile, PlanGenerationRepository generation, {Size size = const Size(420, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({});
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith(SignedIn.new),
      profileRepositoryProvider.overrideWithValue(profile),
      planGenerationRepositoryProvider.overrideWithValue(generation),
    ],
    child: MaterialApp.router(routerConfig: router, theme: AppTheme.light, locale: const Locale('es'),
        supportedLocales: const [Locale('es')], localizationsDelegates: GlobalMaterialLocalizations.delegates),
  ));
  await tester.pumpAndSettle();
  return router;
}

Finder _list() => find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text).hitTestable(), 200, scrollable: _list());
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Steps 1–4 with valid data; ends on step 5 («Tu movimiento»).
Future<void> _fillUntilLastStep(WidgetTester tester, {String location = 'Casa'}) async {
  tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text = 'Moverme más';
  await _tapText(tester, 'Continuar');
  tester.widget<TextFormField>(find.descendant(of: find.byKey(const ValueKey('Estatura (cm)')), matching: find.byType(TextFormField))).controller!.text = '170';
  tester.widget<TextFormField>(find.descendant(of: find.byKey(const ValueKey('Peso actual (kg)')), matching: find.byType(TextFormField))).controller!.text = '70';
  tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('birthday')), matching: find.byType(EditableText))).controller.text = '1995-05-20';
  await _tapText(tester, 'Continuar');
  await _tapText(tester, 'Continuar');
  await tester.tap(find.widgetWithText(ChoiceChip, location));
  await tester.pumpAndSettle();
  await _tapText(tester, 'Continuar');
}

/// Taps «Generar mi plan» and lets the request leave (t ≈ 0 s).
Future<void> _generate(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Generar mi plan').hitTestable(), 200, scrollable: _list());
  await tester.tap(find.text('Generar mi plan'));
  await tester.pump();
}

/// Advances the simulated clock to [seconds] since the tap, given [now].
Future<void> _until(WidgetTester tester, int now, int seconds) async {
  await tester.pump(Duration(seconds: seconds - now));
  await tester.pump();
}

const _forbidden = [
  'generand', 'generar', 'genera', 'prepar', 'proces', 'sincroniz', 'plan', 'rutina', 'backend', 'servidor',
  'inteligencia', 'algoritm', 'modelo', 'esper', 'segundo', 'minuto', 'tiempo', 'carg', 'listo', 'casi', 'pronto',
];

void main() {
  group('Generation screen: exactly 30 s from the tap', () {
    for (final answerAt in [5, 20]) {
      testWidgets('backend done at $answerAt s: the screen stays until 30 s, the result is kept', (tester) async {
        final profile = _Profile();
        final generation = _TimedGeneration(Duration(seconds: answerAt), operation('COMPLETED', planId: 41));
        await _pumpOnboarding(tester, profile, generation);
        await _fillUntilLastStep(tester);
        await _generate(tester);
        expect(find.text('Generando...'), findsOneWidget);
        expect(find.text('Sincronizando...'), findsNothing);
        await _until(tester, 0, answerAt + 1);
        expect(generation.startCalls, 1, reason: 'the backend already answered');
        await _until(tester, answerAt + 1, 29);
        expect(find.text('Generando...'), findsOneWidget, reason: 'never shortened by an early answer');
        expect(find.text('Recorrido del usuario'), findsNothing);
        await _until(tester, 29, 30);
        expect(find.text('Recorrido del usuario'), findsOneWidget);
        expect(generation.startCalls, 1);
        expect(generation.findCalls, 0, reason: 'a COMPLETED answer is kept, not asked again');
        expect(profile.saves, 1);
      });
    }

    testWidgets('backend done at exactly 30 s: continues', (tester) async {
      final generation = _TimedGeneration(const Duration(seconds: 30), operation('COMPLETED', planId: 41));
      await _pumpOnboarding(tester, _Profile(), generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      await _until(tester, 0, 29);
      expect(find.text('Generando...'), findsOneWidget);
      await _until(tester, 29, 30);
      await tester.pump(const Duration(milliseconds: 500)); // page transition
      expect(find.text('Recorrido del usuario'), findsOneWidget);
      expect(find.text('Generando...'), findsNothing);
      expect(find.text('Tu plan sigue en camino'), findsNothing);
      expect(generation.startCalls, 1);
    });

    testWidgets('backend still working after 30 s: pending state, no invented plan, continues when it is done', (tester) async {
      final generation = FakeGeneration(starts: [operation('PENDING')], finds: [operation('PROCESSING')]);
      await _pumpOnboarding(tester, _Profile(), generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      await _until(tester, 0, 29);
      expect(find.text('Generando...'), findsOneWidget);
      // Polling while the screen runs only reads the status: no new generation.
      expect(generation.findCalls, greaterThan(0));
      await _until(tester, 29, 30);
      expect(find.text('Generando...'), findsNothing);
      expect(find.text('Tu plan sigue en camino'), findsOneWidget);
      expect(find.byKey(const ValueKey('generation-progress')), findsNothing, reason: 'the 30 s bar is over');
      expect(find.textContaining('lista'), findsNothing, reason: 'never says the plan is ready');
      expect(find.text('Recorrido del usuario'), findsNothing);
      expect(find.text('Continuar'), findsOneWidget);
      // The real result arrives later: the screen continues by itself.
      generation.finds.add(operation('COMPLETED', planId: 41));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.text('Recorrido del usuario'), findsOneWidget);
      expect(generation.startCalls, 1);
    });

    testWidgets('pending state: «Continuar» goes on to Kora while the backend keeps working', (tester) async {
      final generation = FakeGeneration(starts: [operation('PENDING')], finds: [operation('PROCESSING')]);
      await _pumpOnboarding(tester, _Profile(), generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      await _until(tester, 0, 30);
      await tester.tap(find.text('Continuar'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Recorrido del usuario'), findsOneWidget);
      expect(generation.startCalls, 1);
    });

    testWidgets('request still unanswered after 30 s: pending state without «Continuar» until it is accepted', (tester) async {
      final generation = _TimedGeneration(const Duration(seconds: 45), operation('PENDING'));
      await _pumpOnboarding(tester, _Profile(), generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      await _until(tester, 0, 31);
      expect(find.text('Tu plan sigue en camino'), findsOneWidget);
      expect(find.text('Continuar'), findsNothing);
      await _until(tester, 31, 46);
      expect(find.text('Continuar'), findsOneWidget);
    });

    testWidgets('request refused: the error is shown only after the 30 s', (tester) async {
      final generation = FakeGeneration(starts: [httpError(422, 'Perfil incompleto'), operation('PENDING')]);
      await _pumpOnboarding(tester, _Profile(), generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      await _until(tester, 0, 29);
      expect(find.text('Generando...'), findsOneWidget);
      expect(find.textContaining('Perfil incompleto'), findsNothing);
      await _until(tester, 29, 30);
      expect(find.textContaining('Tu perfil está guardado.'), findsOneWidget);
      expect(find.textContaining('Perfil incompleto'), findsOneWidget);
      expect(find.text('Reintentar generación'), findsOneWidget);
    });

    testWidgets('profile not saved: back to the form with the error after the 30 s, nothing requested', (tester) async {
      final profile = _Profile(saveError: httpError(400, 'Datos no válidos'));
      final generation = FakeGeneration();
      await _pumpOnboarding(tester, profile, generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      await _until(tester, 0, 29);
      expect(find.text('Generando...'), findsOneWidget);
      await _until(tester, 29, 30);
      expect(find.text('Generando...'), findsNothing);
      expect(find.text('Paso 5 de 5'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Generar mi plan').hitTestable(), 200, scrollable: _list());
      expect(find.textContaining('Datos no válidos'), findsOneWidget);
      expect(find.textContaining('Tu perfil está guardado.'), findsNothing);
      expect(generation.startCalls, 0);
    });

    testWidgets('retryable FAILED during the 30 s: error after them, the retry starts a new 30 s screen', (tester) async {
      final generation = FakeGeneration(
        starts: [operation('PENDING'), operation('PENDING', id: 'op-2')],
        finds: [operation('FAILED', message: 'No se pudo completar.', retryable: true)],
      );
      await _pumpOnboarding(tester, _Profile(), generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      await _until(tester, 0, 10);
      expect(find.text('Generando...'), findsOneWidget, reason: 'the failure waits for the 30 s');
      await _until(tester, 10, 30);
      expect(find.textContaining('No se pudo completar.'), findsOneWidget);
      await tester.tap(find.text('Reintentar generación'));
      await tester.pump();
      expect(find.text('Generando...'), findsOneWidget);
      expect(generation.startCalls, 2, reason: 'one new request for one tap');
    });

    testWidgets('NO_FACTIBLE: shown after the 30 s; continues to Kora where the result explains it', (tester) async {
      final generation = FakeGeneration(starts: [operation('NO_FACTIBLE', message: 'Sin semana válida.')]);
      await _pumpOnboarding(tester, _Profile(), generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      await _until(tester, 0, 29);
      expect(find.textContaining('Sin semana válida.'), findsNothing);
      await _until(tester, 29, 30);
      expect(find.textContaining('Sin semana válida.'), findsOneWidget);
      expect(find.text('Reintentar generación'), findsNothing, reason: 'the backend does not allow a retry');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Recorrido del usuario'), findsOneWidget);
      expect(generation.startCalls, 1);
    });

    testWidgets('no duplicate requests: one save and one request per tap, Kapi taps request nothing', (tester) async {
      final profile = _Profile();
      final generation = FakeGeneration(starts: [operation('PENDING')], finds: [operation('PROCESSING')]);
      await _pumpOnboarding(tester, profile, generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      expect(find.text('Generar mi plan'), findsNothing, reason: 'the button is gone while generating');
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(KoraMascot));
        await tester.pump(const Duration(seconds: 1));
      }
      await _until(tester, 5, 30);
      expect(profile.saves, 1);
      expect(generation.startCalls, 1);
    });

    testWidgets('leaving the screen (logout) cancels its timers and subscriptions', (tester) async {
      final generation = FakeGeneration(starts: [operation('PENDING')], finds: [operation('PROCESSING')]);
      final router = await _pumpOnboarding(tester, _Profile(), generation);
      await _fillUntilLastStep(tester);
      await _generate(tester);
      await _until(tester, 0, 10);
      router.go('/login');
      await tester.pumpAndSettle();
      expect(find.text('Inicio de sesión'), findsOneWidget);
      // The 30 s timer and Kapi's rotation are gone: nothing navigates or rebuilds the old screen.
      await tester.pump(const Duration(seconds: 40));
      expect(find.text('Inicio de sesión'), findsOneWidget);
      expect(find.text('Recorrido del usuario'), findsNothing);
      expect(tester.takeException(), isNull);
      // Disposing the app cancels the status polling too; flutter_test fails
      // the test if any timer were still pending.
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Kapi on the generation screen', () {
    test('never mentions generating, preparing, syncing, the plan, the backend, AI, algorithms or waiting', () {
      for (final (_, message) in kapiFunMessages) {
        final text = message.toLowerCase();
        for (final word in _forbidden) {
          // Word starts only: «despertar» is fine, «esperar» is not.
          expect(RegExp('(^|[^a-záéíóúñü])$word').hasMatch(text), isFalse, reason: '«$message» contains «$word»');
        }
        expect(RegExp(r'\bia\b').hasMatch(text), isFalse, reason: '«$message» mentions IA');
      }
      expect(kapiFunMessages.map((m) => m.$2).toSet().length, kapiFunMessages.length, reason: 'no duplicated messages');
    });

    test('the deck shows every message before repeating and never repeats one in a row', () {
      final deck = KapiMessageDeck(Random(3));
      final seen = <String>[];
      for (var i = 0; i < kapiFunMessages.length * 4; i++) {
        seen.add(deck.next().$2);
      }
      for (var round = 0; round < 4; round++) {
        final slice = seen.sublist(round * kapiFunMessages.length, (round + 1) * kapiFunMessages.length);
        expect(slice.toSet().length, kapiFunMessages.length);
      }
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], isNot(seen[i - 1]));
      }
    });

    testWidgets('messages change on their own and on tap without touching the 30 s bar', (tester) async {
      final clock = AnimationController(vsync: const TestVSync(), duration: generationScreenDuration);
      addTearDown(clock.dispose);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: GeneratingPlan(progress: clock, random: Random(1))));
      clock.forward();
      await tester.pump(); // first frame: the clock starts at 0 s
      // While the bubble cross-fades, the newest message is the last one.
      String message() => tester.widgetList<Text>(find.byKey(const ValueKey('kapi-message'))).last.data!;
      double bar() => tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('generation-progress'))).value!;
      final first = message();
      await tester.pump(const Duration(seconds: 3));
      final beforeTap = bar();
      await tester.tap(find.byType(KoraMascot));
      await tester.pump();
      final tapped = message();
      expect(tapped, isNot(first));
      expect(bar(), closeTo(beforeTap, .001), reason: 'a tap never moves the bar');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 400));
      expect(message(), isNot(tapped), reason: 'rotates by itself');
      // Bar follows the clock only: 3 s + 5.4 s of 30 s.
      expect(bar(), closeTo(8.4 / 30, .01));
      await tester.pump(const Duration(seconds: 22));
      expect(bar(), 1.0);
      expect(find.text('Generando...'), findsOneWidget);
      expect(find.text('Sincronizando...'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (size, scale) in [(const Size(320, 568), 1.0), (const Size(320, 568), 1.3), (const Size(360, 640), 2.0)]) {
      testWidgets('fits a small screen ${size.width.toInt()}×${size.height.toInt()} at text ×$scale (running and pending)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final clock = AnimationController(vsync: const TestVSync(), duration: generationScreenDuration);
        addTearDown(clock.dispose);
        Widget screen({bool pending = false}) => MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: scale, maxScaleFactor: scale,
            child: GeneratingPlan(progress: clock, pending: pending, onContinue: pending ? () {} : null),
          ),
        );
        await tester.pumpWidget(screen());
        for (var i = 0; i < kapiFunMessages.length; i++) {
          await tester.pump(kapiMessageInterval);
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(screen(pending: true));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        expect(find.text('Continuar'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('Onboarding: equipment and removed exercise list', () {
    // What reaches the backend for each location when the user keeps the defaults.
    const defaults = {
      'Casa': [bodyWeightCode],
      'Gimnasio': ['band', bodyWeightCode, 'dumbbell', 'machine'],
      'Ambos': [bodyWeightCode],
    };
    for (final location in defaults.keys) {
      testWidgets('«Peso corporal» is ticked by default in $location, removable, and sent once', (tester) async {
        final profile = _Profile();
        await _pumpOnboarding(tester, profile, FakeGeneration());
        await _fillUntilLastStep(tester, location: location);
        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(InputChip, 'Peso corporal'), findsOneWidget);
        expect(tester.widget<InputChip>(find.widgetWithText(InputChip, 'Peso corporal')).onDeleted, isNotNull, reason: 'not mandatory');
        await _tapText(tester, 'Elegir equipamiento');
        final tile = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Peso corporal'));
        expect(tile.value, isTrue);
        expect(tile.onChanged, isNotNull, reason: 'can be unticked like any other equipment');
        expect(find.text('Siempre incluido'), findsNothing);
        await tester.tap(find.byTooltip('Cancelar'));
        await tester.pumpAndSettle();
        await _tapText(tester, 'Continuar');
        await _generate(tester);
        expect(profile.saved!['equipmentCodes'], defaults[location]);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('unticked «Peso corporal» is never added back (locations, steps) and is not sent', (tester) async {
      final profile = _Profile();
      await _pumpOnboarding(tester, profile, FakeGeneration());
      await _fillUntilLastStep(tester, location: 'Casa');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Elegir equipamiento');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Peso corporal'));
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Peso corporal')).value, isFalse);
      await tester.tap(find.text('LISTO · 0 SELECCIONADOS'));
      await tester.pumpAndSettle();
      expect(find.text('Sin equipo seleccionado'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Peso corporal'), findsNothing);
      // Switching location (gym adds its own equipment) never ticks it again.
      for (final location in ['Gimnasio', 'Ambos', 'Casa', 'Gimnasio']) {
        await tester.tap(find.widgetWithText(ChoiceChip, location));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(InputChip, 'Peso corporal'), findsNothing, reason: 'after $location');
      }
      // Leaving the step and coming back keeps the decision too.
      await _tapText(tester, 'Continuar');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Peso corporal'), findsNothing);
      await _tapText(tester, 'Elegir equipamiento');
      expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Peso corporal')).value, isFalse);
      await tester.tap(find.byTooltip('Cancelar'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Continuar');
      await _generate(tester);
      // Exactly the selection: gym equipment, no forced bodyweight.
      expect(profile.saved!['equipmentCodes'], ['band', 'dumbbell', 'machine']);
      expect(profile.saved!['trainingLocation'], 'GYM');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('removed with its chip and ticked again: saved normally, once', (tester) async {
      final profile = _Profile();
      await _pumpOnboarding(tester, profile, FakeGeneration());
      await _fillUntilLastStep(tester, location: 'Ambos');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.widgetWithText(InputChip, 'Peso corporal'), matching: find.byTooltip('Eliminar')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Peso corporal'), findsNothing);
      await _tapText(tester, 'Elegir equipamiento');
      expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Peso corporal')).value, isFalse);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Peso corporal'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Mancuerna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTO · 2 SELECCIONADOS'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Peso corporal'), findsOneWidget);
      await _tapText(tester, 'Continuar');
      await _generate(tester);
      expect(profile.saved!['equipmentCodes'], [bodyWeightCode, 'dumbbell']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the saved choice is kept on «Reintentar generación»: the profile is not re-sent', (tester) async {
      final profile = _Profile();
      final generation = FakeGeneration(starts: [httpError(422, 'Perfil incompleto'), operation('PENDING')]);
      await _pumpOnboarding(tester, profile, generation);
      await _fillUntilLastStep(tester, location: 'Casa');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.widgetWithText(InputChip, 'Peso corporal'), matching: find.byTooltip('Eliminar')));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Continuar');
      await _generate(tester);
      await _until(tester, 0, 30);
      await tester.tap(find.text('Reintentar generación'));
      await tester.pump();
      expect(profile.saves, 1);
      expect(profile.saved!['equipmentCodes'], isEmpty, reason: 'unticked bodyweight stays unticked');
      await _until(tester, 0, 30);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('other equipment can be added; switching location keeps the user choices', (tester) async {
      final profile = _Profile();
      await _pumpOnboarding(tester, profile, FakeGeneration());
      await _fillUntilLastStep(tester, location: 'Casa');
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Elegir equipamiento');
      expect(find.widgetWithText(CheckboxListTile, 'Máquina'), findsNothing, reason: 'gym only');
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Banda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LISTO · 2 SELECCIONADOS'));
      await tester.pumpAndSettle();
      expect(find.text('2 equipos seleccionados'), findsOneWidget);
      // Gym adds its equipment and keeps bodyweight; back home removes only gym-only items.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Gimnasio'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Peso corporal'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Máquina'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ambos'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Máquina'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Casa'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Máquina'), findsNothing);
      expect(find.widgetWithText(InputChip, 'Peso corporal'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Banda'), findsOneWidget);
      await _tapText(tester, 'Continuar');
      await _generate(tester);
      expect(profile.saved!['equipmentCodes'], ['band', bodyWeightCode, 'dumbbell']);
      expect(profile.saved!['trainingLocation'], 'HOME');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an existing profile is never overwritten: it keeps its saved choices', (tester) async {
      final profile = _Profile(existing: {
        'trainingLocation': 'GYM', 'equipmentCodes': <String>[], 'blockedExerciseIds': [12, 40],
      });
      await _pumpOnboarding(tester, profile, FakeGeneration());
      expect(find.text('Revisando tu cuenta'), findsOneWidget);
      expect(profile.saves, 0, reason: 'nothing is re-sent: equipment and blocked exercises stay as saved');
    });

    testWidgets('«Ejercicios a evitar» is gone; steps and progress still work; the profile is sent with []', (tester) async {
      final profile = _Profile();
      await _pumpOnboarding(tester, profile, FakeGeneration());
      expect(find.text('Paso 1 de 5'), findsOneWidget);
      await _fillUntilLastStep(tester);
      expect(find.text('Paso 5 de 5'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator).first).value, 1.0);
      for (final text in ['Elegir ejercicios a evitar', 'Ejercicios a evitar', 'Ejercicios restringidos', 'Sin ejercicios excluidos']) {
        expect(find.text(text), findsNothing);
      }
      expect(find.textContaining('ejercicios a evitar'), findsNothing);
      expect(find.byIcon(Icons.block), findsNothing);
      // Pain and limitation restrictions stay.
      expect(find.text('Saltos y alto impacto'), findsOneWidget);
      expect(find.text('Notas de salud (opcional)'), findsOneWidget);
      // Back and forward between steps.
      for (final expected in ['Paso 4 de 5', 'Paso 3 de 5']) {
        await tester.tap(find.byTooltip('Volver'));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
      }
      await _tapText(tester, 'Continuar');
      await _tapText(tester, 'Continuar');
      expect(find.text('Paso 5 de 5'), findsOneWidget);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Saltos y alto impacto'));
      await tester.pumpAndSettle();
      await _generate(tester);
      final body = profile.saved!;
      expect(body['blockedExerciseIds'], isEmpty);
      expect(body['allowHighImpact'], isFalse);
      expect(body.keys.where((k) => !createProfileFields.contains(k)), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
