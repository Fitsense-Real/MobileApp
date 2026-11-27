// P1 · pending results kept in the phone's secure storage (simulated with FlutterSecureStorage's in-memory
// mock, which survives a new ProviderScope as a closed and reopened app does). Nothing is ever sent from
// storage: every result goes through the routine check, the exercise check and the session lookup again.
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/core/storage/secure_storage.dart';
import 'package:fitsense_mobile/features/account/data/local_account_data.dart';
import 'package:fitsense_mobile/features/authentication/domain/entities/user.dart';
import 'package:fitsense_mobile/features/authentication/presentation/providers/auth_provider.dart';
import 'package:fitsense_mobile/features/authentication/presentation/state/auth_state.dart';
import 'package:fitsense_mobile/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:fitsense_mobile/features/pain/data/pain_exclusion_repository.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/features/workouts/data/pending_results_store.dart';
import 'package:fitsense_mobile/features/workouts/data/workout_repository.dart';
import 'package:fitsense_mobile/features/workouts/presentation/planned_workout_page.dart';
import 'o20_rutina_desactualizada_test.dart' show ControlledPlans, LossyWorkouts, offline;
import 'pain_o20_test.dart' show FakePain, FakeWorkouts, exercise, workoutWith, tap;

class SignedAs extends AuthViewModel {
  SignedAs(this.id);
  final int id;
  @override
  AuthState build() {
    super.build();
    return AuthState(isAuthenticated: true, user: User(id: id, firstName: 'Ana', lastName: 'Demo', email: 'ana$id@example.com', timezone: 'America/Lima'));
  }
}

/// A store whose storage cannot be read or written.
class BrokenStorage extends FlutterSecureStorage {
  const BrokenStorage();
  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions,
      WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => throw Exception('keystore no disponible');
  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions, AndroidOptions? aOptions,
      LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => throw Exception('keystore no disponible');
}

Future<Map<String, String>> stored() async => appSecureStorage.readAll();

void main() {
  final allowed = exercise(42, 578, 'Sentadilla', order: 2);
  final blocked = exercise(42, 578, 'Sentadilla', order: 2, block: 'dolor_registrado');
  final other = exercise(41, 120, 'Plancha');
  Json planWith(List<Json> exercises, {int id = 9123}) => {'planId': 1, 'workouts': [workoutWith(exercises, id: id)]};
  late ControlledPlans plans;
  late FakeWorkouts workouts;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    plans = ControlledPlans(planWith([other, allowed]));
    workouts = FakeWorkouts(session: {'sessionId': 77, 'plannedWorkoutId': 9123, 'startedAt': DateTime.now().toIso8601String(), 'exercises': <Json>[]});
  });

  /// Opens Kora on the routine as [user]: a new ProviderScope each time, like a closed and reopened app.
  Future<void> openApp(WidgetTester tester, {int user = 7, PendingResultsStore? store}) async {
    tester.view.physicalSize = const Size(600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SizedBox()); // the previous app is gone
    await tester.pumpWidget(ProviderScope(key: UniqueKey(), overrides: <Override>[
      painExclusionRepositoryProvider.overrideWithValue(FakePain()),
      planRepositoryProvider.overrideWithValue(plans),
      workoutRepositoryProvider.overrideWithValue(workouts),
      authViewModelProvider.overrideWith(() => SignedAs(user)),
      if (store != null) pendingResultsStoreProvider.overrideWithValue(store),
    ], child: MaterialApp(home: PlannedWorkoutPage(workout: workoutWith([other, allowed])))));
    await tester.pumpAndSettle();
  }

  Future<void> completeSquat(WidgetTester tester) async {
    await tap(tester, find.text('Registrar ejercicio').at(1));
    await tap(tester, find.text('Lo completé'));
    await tap(tester, find.text('Guardar'));
  }

  Future<void> partialSquat(WidgetTester tester) async {
    await tap(tester, find.text('Registrar ejercicio').at(1));
    await tap(tester, find.text('Lo hice parcialmente'));
    // Totals typed directly (M-10 also offers series by series): same body.
    await tap(tester, find.text('Escribir los totales'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Repeticiones totales (todas las series)'), '12');
    await tester.enterText(find.widgetWithText(TextFormField, 'Series realizadas'), '1');
    await tap(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text('Fatiga').last);
    await tester.pumpAndSettle();
    await tap(tester, find.text('Guardar'));
  }

  group('the store', () {
    test('one key per account, separate from the session token; no JWT nor email in what is kept', () async {
      FlutterSecureStorage.setMockInitialValues({'access_token': 'jwt-secreto'});
      const store = PendingResultsStore();
      final entry = PendingResult(userId: 7, sessionId: 77, plannedWorkoutId: 9123, plannedExerciseId: 42,
          body: {'actualSets': 3, 'actualRepsTotal': 30, 'actualDurationSeconds': 0, 'actualLoadKg': null, 'skipReason': null},
          state: PendingState.pending, savedAt: DateTime.now());
      await store.save(7, [entry]);
      final all = await stored();
      expect(all.keys, containsAll(['access_token', 'kora_pending_results_7']));
      expect(all['kora_pending_results_7'], isNot(contains('jwt-secreto')));
      expect(all['kora_pending_results_7'], isNot(contains('@')));
      expect((await store.load(7)).entries.single.body['actualRepsTotal'], 30);
      expect((await store.load(8)).entries, isEmpty, reason: 'another account sees nothing');
      expect(LocalAccountData.keysOf(7), contains('kora_pending_results_7'), reason: 'removed when the account is deleted');
    });

    test('expiry: older than 48 h is dropped when read', () async {
      final store = PendingResultsStore(appSecureStorage, () => DateTime.utc(2026, 11, 28, 12));
      await store.save(7, [
        PendingResult(userId: 7, sessionId: 77, plannedWorkoutId: 1, plannedExerciseId: 1, body: const {'actualSets': 0, 'skipReason': 'FATIGUE'},
            state: PendingState.pending, savedAt: DateTime.utc(2026, 11, 26, 11)),
        PendingResult(userId: 7, sessionId: 77, plannedWorkoutId: 1, plannedExerciseId: 2, body: const {'actualSets': 1},
            state: PendingState.held, savedAt: DateTime.utc(2026, 11, 28, 10)),
      ]);
      final load = await store.load(7);
      expect(load.expired, 1);
      expect(load.entries.single.plannedExerciseId, 2);
    });

    test('damaged or incomplete entries are dropped and reported, never returned', () async {
      const store = PendingResultsStore();
      FlutterSecureStorage.setMockInitialValues({'kora_pending_results_7': '{no es json'});
      var load = await store.load(7);
      expect(load.damaged, isTrue);
      expect(load.entries, isEmpty);
      expect((await stored()).containsKey('kora_pending_results_7'), isFalse, reason: 'rewritten without the damaged data');
      final ok = {'v': 1, 'userId': 7, 'sessionId': 77, 'plannedWorkoutId': 1, 'plannedExerciseId': 1, 'body': {'actualSets': 1}, 'state': 'pending',
        'savedAt': DateTime.now().toUtc().toIso8601String()};
      FlutterSecureStorage.setMockInitialValues({'kora_pending_results_7': jsonEncode([
        ok,
        {...ok, 'userId': 8}, // another account's entry
        {...ok, 'body': {'actualSets': -3}}, // impossible amount
        {...ok, 'body': {'actualSets': 1, 'token': 'x'}}, // unexpected field
        {...ok, 'state': 'enviado'}, // unknown state
        {...ok, 'plannedExerciseId': null}, // incomplete
      ])});
      load = await store.load(7);
      expect(load.damaged, isTrue);
      expect(load.entries, hasLength(1));
    });

    test('a storage that cannot be read or written reports it', () async {
      const store = PendingResultsStore(BrokenStorage());
      expect(() => store.load(7), throwsA(isA<PendingStoreException>()));
      final entry = PendingResult(userId: 7, sessionId: 77, plannedWorkoutId: 1, plannedExerciseId: 1, body: const {'actualSets': 1},
          state: PendingState.pending, savedAt: DateTime.now());
      expect(() => store.save(7, [entry]), throwsA(isA<PendingStoreException>()));
    });
  });

  group('closing and reopening Kora', () {
    testWidgets('A · the app is closed with a pending result: it comes back for that account, and only a validated retry sends it', (tester) async {
      await openApp(tester);
      plans.error = offline();
      await completeSquat(tester);
      expect(find.text('Pendiente de enviar'), findsOneWidget);
      expect((await stored()).keys, contains('kora_pending_results_7'));
      plans.error = null; // the connection is back...
      await openApp(tester); // ...and the app was closed completely and opened again
      expect(find.text('Pendiente de enviar'), findsOneWidget, reason: 'it came back');
      expect(find.byKey(const Key('pending-results')), findsOneWidget);
      expect(workouts.recorded, isEmpty, reason: 'never sent automatically, even with the network back');
      final reads = plans.reads;
      await tap(tester, find.text('Reintentar envío'));
      expect(plans.reads, greaterThan(reads), reason: 'the routine is confirmed again first');
      expect(workouts.recorded.single['actualRepsTotal'], 30);
      expect((await stored()).containsKey('kora_pending_results_7'), isFalse, reason: 'sent: nothing left on the phone');
    });

    testWidgets('B · the exercise was blocked while the app was closed: held, not sent', (tester) async {
      await openApp(tester);
      plans.error = offline();
      await completeSquat(tester);
      plans.error = null;
      plans.plan = planWith([other, blocked]);
      await openApp(tester);
      expect(workouts.recorded, isEmpty);
      expect(find.byKey(const Key('held-results')), findsOneWidget);
      expect(find.text('Retenido: no se enviará'), findsOneWidget);
      expect(find.byKey(const Key('blocked-42')), findsOneWidget);
      expect(jsonDecode((await stored())['kora_pending_results_7']!)[0]['state'], 'held');
      await tap(tester, find.byKey(const Key('discard-42')));
      expect((await stored()).containsKey('kora_pending_results_7'), isFalse, reason: 'discarded from the phone too');
    });

    testWidgets('C · the backend had received it (answer lost): after reopening, the session is checked and nothing is repeated', (tester) async {
      final lossy = LossyWorkouts(session: workouts.session);
      workouts = lossy;
      await openApp(tester);
      await completeSquat(tester);
      expect(lossy.puts, 1);
      expect(jsonDecode((await stored())['kora_pending_results_7']!)[0]['state'], 'maybeSent');
      await openApp(tester);
      await tap(tester, find.text('Reintentar envío'));
      expect(lossy.puts, 1, reason: 'already in the session: not sent again');
      expect(lossy.recorded, hasLength(1));
      expect((await stored()).containsKey('kora_pending_results_7'), isFalse);
    });

    testWidgets('D · another account on the same phone never sees them', (tester) async {
      await openApp(tester, user: 7);
      plans.error = offline();
      await completeSquat(tester);
      await openApp(tester, user: 8);
      expect(find.text('Pendiente de enviar'), findsNothing);
      expect(find.byKey(const Key('pending-results')), findsNothing);
      expect(find.byKey(const Key('held-results')), findsNothing);
      expect((await stored()).keys, contains('kora_pending_results_7'), reason: 'kept for its own account');
      await openApp(tester, user: 7);
      expect(find.text('Pendiente de enviar'), findsOneWidget);
    });

    testWidgets('E · the original plan is no longer current: nothing incompatible is sent', (tester) async {
      await openApp(tester);
      plans.error = offline();
      await completeSquat(tester);
      plans.error = null;
      plans.plan = {'planId': 2, 'workouts': [workoutWith([other], id: 9999)]}; // a new plan version
      await openApp(tester);
      expect(workouts.recorded, isEmpty);
      expect(find.byKey(const Key('held-results')), findsOneWidget);
      expect(find.text('Registrar ejercicio'), findsNothing, reason: 'the old routine cannot be recorded');
    });

    testWidgets('the session was closed while the app was closed: held, not sent', (tester) async {
      await openApp(tester);
      plans.error = offline();
      await completeSquat(tester);
      workouts.session = {'sessionId': 78, 'plannedWorkoutId': 9123, 'startedAt': DateTime.now().toIso8601String(), 'exercises': <Json>[]};
      plans.error = null;
      await openApp(tester);
      expect(find.byKey(const Key('held-results')), findsOneWidget);
      expect(find.byKey(const Key('pending-results')), findsNothing);
      expect(workouts.recorded, isEmpty);
    });

    testWidgets('F · damaged data on the phone: reported, nothing sent', (tester) async {
      FlutterSecureStorage.setMockInitialValues({'kora_pending_results_7': '[{"v":1,"userId":7,"body":"roto"}]'});
      await openApp(tester);
      expect(find.byKey(const Key('store-notice')), findsOneWidget);
      expect(find.textContaining('estaban dañados y se descartaron. No se ha enviado nada'), findsOneWidget);
      expect(find.byKey(const Key('pending-results')), findsNothing);
      expect(workouts.recorded, isEmpty);
    });

    testWidgets('F · the phone storage fails: reported, the result stays on screen, never sent unvalidated', (tester) async {
      await openApp(tester, store: const PendingResultsStore(BrokenStorage()));
      expect(find.textContaining('No se pudieron leer los resultados guardados en este teléfono. No se ha enviado nada.'), findsOneWidget);
      plans.error = offline();
      await completeSquat(tester);
      expect(find.textContaining('se perderá si cierras la app'), findsOneWidget);
      expect(find.text('Pendiente de enviar'), findsOneWidget);
      expect(workouts.recorded, isEmpty);
    });

    testWidgets('G · a partial result keeps its real amounts and D-M1 still applies when sent', (tester) async {
      await openApp(tester);
      plans.error = offline();
      await partialSquat(tester);
      final kept = jsonDecode((await stored())['kora_pending_results_7']!)[0]['body'] as Map;
      expect(kept, {'actualSets': 1, 'actualRepsTotal': 12, 'actualDurationSeconds': 0, 'actualLoadKg': null, 'skipReason': 'FATIGUE'});
      await openApp(tester);
      plans.error = null;
      await tap(tester, find.text('Reintentar envío'));
      expect(workouts.recorded.single, {'plannedExerciseId': 42, 'actualSets': 1, 'actualRepsTotal': 12, 'actualDurationSeconds': 0, 'actualLoadKg': null, 'skipReason': 'FATIGUE'});
    });

    testWidgets('without a signed-in account nothing is kept on the phone', (tester) async {
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(overrides: <Override>[
        painExclusionRepositoryProvider.overrideWithValue(FakePain()),
        planRepositoryProvider.overrideWithValue(plans),
        workoutRepositoryProvider.overrideWithValue(workouts),
      ], child: MaterialApp(home: PlannedWorkoutPage(workout: workoutWith([other, allowed])))));
      await tester.pumpAndSettle();
      plans.error = offline();
      await completeSquat(tester);
      expect(find.text('Pendiente de enviar'), findsOneWidget);
      expect((await stored()).keys.where((k) => k.startsWith('kora_pending_results_')), isEmpty);
    });
  });
}
