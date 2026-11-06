import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/core/api/json.dart';
import 'package:fitsense_mobile/features/catalog/data/catalog_repository.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/onboarding/presentation/onboarding_page.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

/// `UserProfileResource` as returned by GET /users/me/profile.
const storedProfile = {
  'userId': 7, 'birthDate': '1990-05-04', 'age': 36, 'biologicalSex': 'FEMALE', 'heightCm': 165.0,
  'currentWeightKg': 62.5, 'targetWeightKg': null, 'fitnessLevel': 'INTERMEDIATE', 'goalType': 'INCREASE_STRENGTH',
  'goalText': 'Subir escaleras sin cansarme', 'trainingLocation': 'HOME', 'daysPerWeek': 3, 'availableDays': [1, 3, 5],
  'sessionMinutes': 40, 'equipmentCodes': ['band'], 'blockedExerciseIds': [76], 'healthNotes': 'Rodilla operada',
};

class StoredProfile extends ProfileRepository {
  StoredProfile() : super(Dio());
  final saves = <(Json, bool)>[];
  @override
  Future<Json?> fetch() async => Json.from(storedProfile);
  @override
  Future<List<Equipment>> equipment() async => [const Equipment('band', 'Banda', false)];
  @override
  Future<Json?> save(Json body, {required bool exists}) async { saves.add((body, exists)); return body; }
}

class NoGeneration extends PlanRepository {
  NoGeneration() : super(Dio());
  int calls = 0;
  @override
  Future<Json?> current() async { calls++; return null; }
  @override
  Future<Json> generate() async { calls++; throw StateError('Editing must not generate a plan'); }
}

class Catalog extends CatalogRepository {
  Catalog() : super(Dio());
  @override
  Future<Json> exercise(Object id) async => {'exerciseId': id, 'name': 'Sentadilla con salto'};
  @override
  Future<List<Json>> exercises({String? search, String? bodyPart, String? equipment, int? maxDifficulty, int limit = 30}) async =>
      [{'exerciseId': 76, 'name': 'Sentadilla con salto'}, {'exerciseId': 90, 'name': 'Burpee', 'targetMuscle': 'cardio'}];
}

void main() {
  testWidgets('Edit mode prefills the profile, PUTs it and never generates a plan', (tester) async {
    tester.view.physicalSize = const Size(420, 900); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final profile = StoredProfile(); final plans = NoGeneration();
    final router = GoRouter(initialLocation: '/dashboard', routes: [
      GoRoute(path: '/dashboard', builder: (context, _) => Scaffold(body: TextButton(onPressed: () => context.push('/onboarding?edit=1'), child: const Text('Editar')))),
      GoRoute(path: '/onboarding', builder: (_, state) => OnboardingPage(edit: state.uri.queryParameters['edit'] == '1')),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [
      profileRepositoryProvider.overrideWithValue(profile),
      planRepositoryProvider.overrideWithValue(plans),
      catalogRepositoryProvider.overrideWithValue(Catalog()),
    ], child: MaterialApp.router(routerConfig: router, theme: AppTheme.light, locale: const Locale('es'), supportedLocales: const [Locale('es')], localizationsDelegates: GlobalMaterialLocalizations.delegates)));
    await tester.tap(find.text('Editar')); await tester.pumpAndSettle();

    Future<void> tapButton(String text) async {
      await tester.scrollUntilVisible(find.text(text).hitTestable(), 200, scrollable: find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first);
      await tester.tap(find.text(text)); await tester.pumpAndSettle();
    }
    expect(find.text('Subir escaleras sin cansarme'), findsOneWidget);
    await tapButton('Continuar');
    final birthday = tester.widget<TextFormField>(find.byKey(const ValueKey('birthday')));
    expect(birthday.controller!.text, '1990-05-04');
    expect(birthday.enabled, isFalse, reason: 'UpdateUserProfileResource has no birthDate');
    await tapButton('Continuar');
    expect(find.text('3 sesiones por semana'), findsOneWidget);
    await tapButton('Continuar');
    await tapButton('Continuar');
    expect(find.text('Sentadilla con salto'), findsOneWidget, reason: 'blocked id resolved through the catalog');
    expect(find.textContaining('Saltos y alto impacto'), findsNothing);
    await tapButton('Elegir ejercicios a evitar');
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Burpee')); await tester.pumpAndSettle();
    await tester.tap(find.text('LISTO · 2 EXCLUIDOS')); await tester.pumpAndSettle();
    await tapButton('Guardar cambios');

    expect(profile.saves, hasLength(1));
    final (body, exists) = profile.saves.single;
    expect(exists, isTrue);
    expect(body['blockedExerciseIds'], [76, 90]);
    expect(body['availableDays'], [1, 3, 5]);
    expect(body['fitnessLevel'], 'INTERMEDIATE');
    expect(body['sessionMinutes'], 40);
    expect(body['healthNotes'], 'Rodilla operada');
    expect(plans.calls, 0);
    expect(find.text('Editar'), findsOneWidget, reason: 'returns to the previous screen');
    expect(find.textContaining('lunes siguiente'), findsOneWidget);
  });
}
