import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';
import 'package:fitsense_mobile/features/onboarding/presentation/onboarding_page.dart';
import 'package:fitsense_mobile/features/plans/data/plan_repository.dart';
import 'package:fitsense_mobile/shared/theme/app_theme.dart';

class ProfileFake extends ProfileRepository {
  ProfileFake() : super(Dio());
  int saves = 0;
  Map<String, dynamic>? saved;
  @override
  Future<Map<String, dynamic>?> fetch() async => null;
  @override
  Future<List<Equipment>> equipment() async => [const Equipment('machine', 'Máquina', true), const Equipment('cable', 'Polea', true), const Equipment('band', 'Banda', false)];
  @override
  Future<void> save(Map<String,dynamic> body, {required bool exists}) async { saves++; saved = body; }
}
class PlansFake extends PlanRepository {
  PlansFake() : super(Dio());
  final attempts = <Completer<Map<String,dynamic>>>[];
  @override
  Future<Map<String,dynamic>?> current() async => null;
  @override
  Future<Map<String,dynamic>> generate() {
    final completer = Completer<Map<String,dynamic>>(); attempts.add(completer); return completer.future;
  }
}
void main() {
  testWidgets('Spanish calendar, weekly selection and generation waits/retries', (tester) async {
    tester.view.physicalSize = const Size(420,900); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final profile = ProfileFake(); final plans = PlansFake();
    final router = GoRouter(initialLocation: '/onboarding', routes: [
      GoRoute(path:'/onboarding', builder: (_,__) => const OnboardingPage()),
      GoRoute(path:'/dashboard', builder: (_,__) => const Scaffold(body: Text('Inicio del usuario'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(overrides: [profileRepositoryProvider.overrideWithValue(profile), planRepositoryProvider.overrideWithValue(plans)], child: MaterialApp.router(routerConfig: router, theme: AppTheme.light, locale: const Locale('es'), supportedLocales: const [Locale('es')], localizationsDelegates: GlobalMaterialLocalizations.delegates)));
    await tester.pumpAndSettle();
    Future<void> tapButton(String text) async {
      await tester.scrollUntilVisible(find.text(text).hitTestable(),200,scrollable: find.descendant(of: find.byType(ListView).first,matching: find.byType(Scrollable)).first);
      await tester.tap(find.text(text)); await tester.pumpAndSettle();
    }
    tester.widget<TextFormField>(find.byType(TextFormField).first).controller!.text = 'Moverme más';
    await tapButton('Continuar');
    tester.widget<TextFormField>(find.descendant(of: find.byKey(const ValueKey('Estatura (cm)')), matching: find.byType(TextFormField))).controller!.text = '170';
    tester.widget<TextFormField>(find.descendant(of: find.byKey(const ValueKey('Peso actual (kg)')), matching: find.byType(TextFormField))).controller!.text = '70';
    tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('birthday')), matching: find.byType(EditableText))).controller.text = '1995-05-20';
    await tester.ensureVisible(find.byKey(const ValueKey('birthday')));
    expect(tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('birthday')), matching: find.byType(EditableText))).readOnly, true);
    await tester.tap(find.byTooltip('Elegir cumpleaños')); await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    final dialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    final now=DateTime.now();
    expect(dialog.lastDate.isBefore(DateTime(now.year,now.month,now.day)), true);
    await tester.tap(find.text('Cancelar')); await tester.pumpAndSettle();
    await tapButton('Continuar');
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'Mar')); await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Jue')).onSelected, isNull);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Lun')).onSelected, isNotNull);
    await tester.tap(find.widgetWithText(FilterChip, 'Mar')); await tester.pumpAndSettle();
    for (final level in ['Intermedio', 'Avanzado']) {
      await tester.ensureVisible(find.byTooltip('Volver'));
      await tester.tap(find.byTooltip('Volver')); await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, level));
      await tester.tap(find.widgetWithText(ChoiceChip, level)); await tester.pumpAndSettle();
      await tapButton('Continuar');
      for (final day in ['Mar', 'Jue', 'Sáb']) { await tester.tap(find.widgetWithText(FilterChip, day)); await tester.pumpAndSettle(); }
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Dom')).onSelected, isNull);
      for (final day in ['Mar', 'Jue', 'Sáb']) { await tester.tap(find.widgetWithText(FilterChip, day)); await tester.pumpAndSettle(); }
    }
    for(final d in ['Lun','Mié','Vie']) { await tester.tap(find.widgetWithText(FilterChip,d)); await tester.pumpAndSettle(); }
    await tapButton('Continuar');
    expect(find.text('Elige al menos un día para entrenar.'), findsOneWidget);
    for(final d in ['Mar','Jue']) { await tester.tap(find.widgetWithText(FilterChip,d)); await tester.pumpAndSettle(); }
    await tapButton('Continuar');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Gimnasio')); await tester.pumpAndSettle();
    await tapButton('Elegir equipamiento');
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Máquina')).value, true);
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Polea')).value, true);
    expect(tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Banda')).value, true);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Polea')); await tester.pumpAndSettle();
    await tester.tap(find.text('LISTO · 2 SELECCIONADOS')); await tester.pumpAndSettle();
    // Tapping the current location must not undo the user's deselection.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Gimnasio')); await tester.pumpAndSettle();
    await tapButton('Continuar');
    await tester.scrollUntilVisible(find.text('Generar mi plan').hitTestable(),200,scrollable: find.descendant(of:find.byType(ListView).first,matching:find.byType(Scrollable)).first);
    await tester.tap(find.text('Generar mi plan')); await tester.pump(); await tester.pump(const Duration(seconds:1));
    expect(profile.saved?['daysPerWeek'], 2); expect(profile.saved?['availableDays'], [2,4]);
    expect(profile.saved?['equipmentCodes'], ['band', 'machine']);
    expect(find.text('Sincronizando...'), findsOneWidget);
    expect(find.text('Inicio del usuario'), findsNothing);
    plans.attempts.single.completeError(Exception('Servicio temporalmente no disponible'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Tu perfil está guardado.').hitTestable(),200,scrollable:find.descendant(of:find.byType(ListView).first,matching:find.byType(Scrollable)).first);
    expect(find.textContaining('Tu perfil está guardado.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Reintentar generación').hitTestable(),200,scrollable:find.descendant(of:find.byType(ListView).first,matching:find.byType(Scrollable)).first);
    await tester.tap(find.text('Reintentar generación')); await tester.pump(); await tester.pump(const Duration(seconds:1));
    expect(profile.saves, 1);
    plans.attempts.last.complete({'planId': 42,'workouts': []});
    await tester.pumpAndSettle(); expect(find.text('Inicio del usuario'), findsOneWidget);
  });
}
