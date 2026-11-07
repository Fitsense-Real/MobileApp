import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/api/api_error.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../plans/data/plan_repository.dart';
import '../data/profile_repository.dart';
import '../../catalog/data/catalog_repository.dart';
import 'blocked_exercise_picker.dart';
import 'equipment_picker.dart';
import 'generating_plan.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final form = GlobalKey<FormState>();
  final scroll = ScrollController();
  final birth = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();
  final target = TextEditingController();
  final goalText = TextEditingController();
  final minutes = TextEditingController(text: '45');
  final notes = TextEditingController();
  int step = 0;
  bool loading = true, busy = false, savingProfile = false, exists = false, loadFailed = false, profileSaved = false;
  String? error, equipmentError, sex;
  String level = 'BEGINNER', goal = 'GENERAL_FITNESS', location = 'HOME';
  final days = <int>{1, 3, 5};
  int get maxWeeklySessions => level == 'BEGINNER' ? 4 : 6;
  String? get daysError => days.isEmpty ? 'Elige al menos un día para entrenar.' : days.length > maxWeeklySessions ? 'Para ${levels[level]} puedes elegir como máximo $maxWeeklySessions días. Desmarca ${days.length - maxWeeklySessions} para continuar.' : null;
  final selectedEquipment = <String>{};
  /// Exercise ids sent as `blockedExerciseIds`; names only for display.
  final blocked = <int, String>{};
  /// Movement permissions of `CreateUserProfileResource` (V25): true = allowed.
  final permissions = <String, bool>{'allowHighImpact': true, 'allowFloorExercises': true, 'allowKneelingExercises': true, 'allowHangingExercises': true, 'allowOverheadExercises': true};
  List<Equipment> equipment = [];
  bool selectGymOnCatalogLoad = false;
  static const levels = {'BEGINNER': 'Principiante', 'INTERMEDIATE': 'Intermedio', 'ADVANCED': 'Avanzado'};
  static const goals = {'GAIN_MUSCLE': 'Ganar masa muscular', 'LOSE_WEIGHT': 'Perder grasa', 'INCREASE_STRENGTH': 'Aumentar fuerza', 'GENERAL_FITNESS': 'Mejorar condición'};
  static const goalImages = {'GAIN_MUSCLE': 'strength', 'LOSE_WEIGHT': 'cardio', 'INCREASE_STRENGTH': 'challenge', 'GENERAL_FITNESS': 'mobility'};
  static const locations = {'HOME': 'Casa', 'GYM': 'Gimnasio', 'MIXED': 'Ambos'};
  static const permissionLabels = {'allowHighImpact': 'Saltos y alto impacto', 'allowFloorExercises': 'Ejercicios en el suelo', 'allowKneelingExercises': 'Ejercicios de rodillas', 'allowHangingExercises': 'Ejercicios colgado', 'allowOverheadExercises': 'Brazos sobre la cabeza'};

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { for (final c in [birth, height, weight, target, goalText, minutes, notes]) { c.dispose(); } scroll.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; loadFailed = false; });
    try {
      final data = await ref.read(profileRepositoryProvider).fetch();
      if (!mounted) return;
      exists = data != null;
      if (exists) {
        if (mounted) context.go(AppRoutes.accountSetup);
        return;
      }
      if (data != null) {
        birth.text = data['birthDate'] as String;
        height.text = '${data['heightCm']}'; weight.text = '${data['currentWeightKg']}';
        target.text = data['targetWeightKg']?.toString() ?? '';
        goalText.text = data['goalText'] as String; minutes.text = '${data['sessionMinutes']}';
        notes.text = data['healthNotes'] as String? ?? '';
        sex = data['biologicalSex'] as String?;
        level = data['fitnessLevel'] as String; goal = data['goalType'] as String; location = data['trainingLocation'] as String;
        days..clear()..addAll((data['availableDays'] as List).map((d) => (d as num).toInt()));
        selectedEquipment..clear()..addAll((data['equipmentCodes'] as List? ?? []).cast<String>());
        blocked..clear()..addAll({for (final id in (data['blockedExerciseIds'] as List? ?? [])) (id as num).toInt(): 'Ejercicio #$id'});
        for (final key in permissions.keys.toList()) { permissions[key] = data[key] as bool? ?? true; }
      }
      await loadEquipment();
      if (blocked.isNotEmpty) unawaited(resolveBlockedNames());
    } catch (e) { if (mounted) setState(() { error = apiError(e); loadFailed = true; }); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> resolveBlockedNames() async {
    final catalog = ref.read(catalogRepositoryProvider);
    for (final id in blocked.keys.toList()) {
      try {
        final name = (await catalog.exercise(id))['name'];
        if (mounted && name is String && blocked.containsKey(id)) setState(() => blocked[id] = name);
      } catch (_) { /* keep the placeholder name */ }
    }
  }
  Future<void> loadEquipment() async {
    try {
      final items = await ref.read(profileRepositoryProvider).equipment();
      if (mounted) { setState(() {
        equipment = items; equipmentError = null;
        if (selectGymOnCatalogLoad && location == 'GYM') {
          selectedEquipment.addAll(items.where((e) => e.selectedForGym).map((e) => e.code));
          profileSaved = false;
        }
        selectGymOnCatalogLoad = false;
      }); }
    } catch (e) { if (mounted) setState(() => equipmentError = apiError(e)); }
  }

  String? number(String? input, num min, num max, {bool optional = false, bool integer = false}) {
    if (optional && (input ?? '').trim().isEmpty) return null;
    final value = num.tryParse((input ?? '').trim().replaceAll(',', '.'));
    return value == null || !value.isFinite || value < min || value > max || (integer && value % 1 != 0) ? 'Ingresa un valor entre $min y $max${integer ? ' (entero)' : ''}' : null;
  }
  String? validBirth(String? value) {
    final date = DateTime.tryParse(value ?? '');
    final now = DateTime.now();
    return date == null || date.toIso8601String().substring(0, 10) != value || !date.isBefore(DateTime(now.year, now.month, now.day)) ? 'Elige una fecha anterior a hoy' : null;
  }
  Future<void> pickBirthday() async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    final previous = DateTime.tryParse(birth.text);
    final initial = previous != null && !previous.isAfter(yesterday) ? previous : DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: DateTime(initial.year < 1900 ? initial.year : 1900), lastDate: yesterday,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Tu fecha de nacimiento', cancelText: 'Cancelar', confirmText: 'Elegir',
      fieldLabelText: 'Fecha de nacimiento', fieldHintText: 'Día/mes/año',
    );
    if (picked != null && mounted) setState(() { birth.text = picked.toIso8601String().substring(0, 10); profileSaved = false; });
  }

  void advance() {
    if (!form.currentState!.validate()) return;
    if (step == 2 && daysError != null) { setState(() => error = daysError); return; }
    setState(() { step++; error = null; });
    scroll.jumpTo(0);
  }
  Map<String, dynamic> profileBody() {
    num parse(TextEditingController c) => num.parse(c.text.trim().replaceAll(',', '.'));
    return {
      'birthDate': birth.text, 'biologicalSex': sex, 'heightCm': parse(height), 'currentWeightKg': parse(weight),
      'targetWeightKg': target.text.trim().isEmpty ? null : parse(target),
      'fitnessLevel': level, 'goalType': goal, 'goalText': goalText.text.trim(), 'trainingLocation': location,
      'daysPerWeek': days.length, 'availableDays': days.toList()..sort(), 'sessionMinutes': int.parse(minutes.text.trim()),
      'equipmentCodes': selectedEquipment.toList()..sort(), 'blockedExerciseIds': blocked.keys.toList()..sort(),
      'healthNotes': notes.text.trim().isEmpty ? null : notes.text.trim(), ...permissions,
    };
  }
  Future<void> submit() async {
    if (!profileSaved && daysError != null) { setState(() { step = 2; error = daysError; }); return; }
    if (busy || (!profileSaved && !form.currentState!.validate())) return;
    FocusScope.of(context).unfocus();
    setState(() { busy = true; savingProfile = !profileSaved; error = null; });
    try {
      if (!profileSaved) {
        await ref.read(profileRepositoryProvider).save(profileBody(), exists: exists);
        if (!mounted) return;
        exists = true; profileSaved = true;
      }
      setState(() => savingProfile = false);
      final repository = ref.read(planRepositoryProvider);
      // Reconcile previous attempts before POST: never create duplicates on retry.
      var plan = await repository.current();
      if (plan == null) {
        try { plan = await repository.generate(); }
        on DioException catch (e) {
          if (!isPlanConflict(e)) rethrow;
          plan = await repository.current();
          if (plan == null) rethrow;
        }
      }
      if (!mounted) return;
      if (plan['planId'] == null) throw const FormatException('El servidor no devolvió un plan válido.');
      ref.read(generatedPlanProvider.notifier).setPlan(plan);
      ref.invalidate(currentPlanProvider);
      context.go(AppRoutes.dashboard);
    } catch (e) {
      if (mounted) setState(() => error = '${profileSaved ? 'Tu perfil está guardado. ' : ''}${apiError(e)}');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Widget field(String label, TextEditingController controller, {String? Function(String?)? validator, TextInputType? keyboard, int? maxLength, int lines = 1}) => Padding(key: ValueKey(label), padding: const EdgeInsets.only(bottom: 20), child: TextFormField(controller: controller, maxLength: maxLength, maxLines: lines, style: const TextStyle(fontSize: 16), keyboardType: keyboard, decoration: InputDecoration(labelText: label, alignLabelWithHint: true), validator: validator));
  Widget choices(String label, Map<String, String> options, String selected, ValueChanged<String> choose) => Padding(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: [for (final item in options.entries) ChoiceChip(label: Text(item.value), selected: selected == item.key, selectedColor: Kora.lime, onSelected: (_) => setState(() { choose(item.key); profileSaved = false; }))])]));
  Future<void> pickEquipment() async {
    final result = await showModalBottomSheet<Set<String>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => FractionallySizedBox(heightFactor: .88, child: EquipmentPicker(items: equipment, selected: selectedEquipment, home: location == 'HOME')));
    if (result != null && mounted) setState(() { selectedEquipment..clear()..addAll(result); profileSaved = false; });
  }
  Future<void> pickBlocked() async {
    final result = await showModalBottomSheet<Map<int, String>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => FractionallySizedBox(heightFactor: .88, child: BlockedExercisePicker(selected: blocked)));
    if (result != null && mounted) setState(() { blocked..clear()..addAll(result); profileSaved = false; });
  }
  Widget goalCard(MapEntry<String, String> entry) {
    final selected = goal == entry.key;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Semantics(selected: selected, child: Material(color: selected ? Kora.forest : Colors.white, borderRadius: BorderRadius.circular(24), clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => setState(() { goal = entry.key; profileSaved = false; }), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/images/kora/${goalImages[entry.key]}.jpg', width: 60, height: 64, fit: BoxFit.cover)), const SizedBox(width: 14),
      Expanded(child: Text(entry.value, style: TextStyle(color: selected ? Colors.white : Kora.forest, fontSize: 16, fontWeight: FontWeight.w700))), const SizedBox(width: 8), Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Kora.lime : Kora.sage),
    ]))))));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const KoraPage(child: Center(child: CircularProgressIndicator()));
    if (busy) return GeneratingPlan(saving: savingProfile);
    if (profileSaved) {
      return KoraPage(child: ListView(padding: const EdgeInsets.all(24), children: [
      const KoraLogo(), const SizedBox(height: 24),
      Text(error ?? 'Tu perfil está guardado.'), const SizedBox(height: 24),
      KoraButton(label: 'Reintentar generación', onPressed: submit),
    ]));
    }
    if (loadFailed) return KoraPage(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(error!), const SizedBox(height: 20), KoraButton(label: 'Reintentar', onPressed: load), TextButton(onPressed: () => context.go(AppRoutes.login), child: const Text('Iniciar sesión'))])));
    const titles = [('¿Cuál es tu', 'objetivo?'), ('Perfil', 'físico.'), ('Tu ritmo', 'semanal.'), ('¿Qué equipo', 'tienes?'), ('Tu movimiento,', 'tu bienestar.')];
    return KoraPage(maxWidth: 560, child: ListView(controller: scroll, padding: const EdgeInsets.all(24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: () { if (step > 0) { setState(() { step--; error = null; }); scroll.jumpTo(0); } else { context.go(AppRoutes.dashboard); } }, icon: const Icon(Icons.arrow_back), tooltip: 'Volver'), Text('Paso ${step + 1} de 5', style: const TextStyle(color: Kora.muted)), const KoraLogo(width: 70)]),
      const SizedBox(height: 16), LinearProgressIndicator(value: (step + 1) / 5, color: Kora.lime, backgroundColor: Colors.white), const SizedBox(height: 28),
      KoraHeading(titles[step].$1, accent: titles[step].$2), const SizedBox(height: 24),
      Form(key: form, onChanged: () => profileSaved = false, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (step == 0) ...[
          const Text('Elige la meta que te motiva. Vamos paso a paso.', style: TextStyle(fontSize: 16, color: Kora.muted)), const SizedBox(height: 20),
          for (final entry in goals.entries) goalCard(entry), const SizedBox(height: 12),
          field('Cuéntanos qué quieres lograr', goalText, maxLength: 500, lines: 2, validator: (v) => (v ?? '').trim().isEmpty ? 'Describe tu objetivo' : (v ?? '').length > 500 ? 'Máximo 500 caracteres' : null),
        ],
        if (step == 1) ...[
          Padding(padding: const EdgeInsets.only(bottom: 20), child: TextFormField(key: const ValueKey('birthday'), controller: birth, readOnly: true, onTap: pickBirthday, decoration: InputDecoration(labelText: 'Fecha de nacimiento', hintText: 'Elige tu cumpleaños', suffixIcon: IconButton(onPressed: pickBirthday, icon: const Icon(Icons.calendar_month), tooltip: 'Elegir cumpleaños')), validator: validBirth)),
          DropdownButtonFormField<String>(isExpanded: true, value: sex, decoration: const InputDecoration(labelText: 'Sexo biológico (opcional)'), items: const [DropdownMenuItem(value: null, child: Text('Prefiero no indicarlo')), DropdownMenuItem(value: 'MALE', child: Text('Masculino')), DropdownMenuItem(value: 'FEMALE', child: Text('Femenino')), DropdownMenuItem(value: 'OTHER', child: Text('Otro'))], onChanged: (v) => setState(() => sex = v)), const SizedBox(height: 20),
          field('Estatura (cm)', height, validator: (v) => number(v,120,250), keyboard: const TextInputType.numberWithOptions(decimal: true)),
          field('Peso actual (kg)', weight, validator: (v) => number(v,30,300), keyboard: const TextInputType.numberWithOptions(decimal: true)),
          field('Peso objetivo (kg, opcional)', target, validator: (v) => number(v,30,300,optional: true), keyboard: const TextInputType.numberWithOptions(decimal: true)),
          choices('Nivel de experiencia', levels, level, (v) { level = v; error = null; }),
        ],
        if (step == 2) ...[
          const Text('Marca los días en los que puedes entrenar.', style: TextStyle(fontSize: 16, color: Kora.muted)), const SizedBox(height: 20),
          Text('${levels[level]}: máximo $maxWeeklySessions días por semana.', style: const TextStyle(color: Kora.muted)), const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [for (var i=1;i<=7;i++) FilterChip(label: Text(['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'][i-1]), selected: days.contains(i), selectedColor: Kora.lime, onSelected: !days.contains(i) && days.length >= maxWeeklySessions ? null : (v) => setState(() { v ? days.add(i) : days.remove(i); profileSaved = false; error = null; }))]), const SizedBox(height: 16),
          if (days.length > maxWeeklySessions) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(daysError!, style: const TextStyle(color: Colors.red))),
          Text('${days.length} ${days.length == 1 ? 'sesión' : 'sesiones'} por semana', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 24),
          field('Minutos por sesión', minutes, validator: (v) => number(v,15,180,integer: true), keyboard: TextInputType.number),
        ],
        if (step == 3) ...[
          ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset('assets/images/kora/strength.jpg', height: 150, width: double.infinity, fit: BoxFit.cover)), const SizedBox(height: 24),
          choices('¿Dónde entrenarás?', locations, location, (v) {
            if (location == v) return;
            location = v;
            selectGymOnCatalogLoad = v == 'GYM' && equipmentError != null;
            if (v == 'GYM') { selectedEquipment.addAll(equipment.where((e) => e.selectedForGym).map((e) => e.code)); }
            if (v == 'HOME') { selectedEquipment.removeWhere((code) => equipment.any((e) => e.code == code && e.requiresGym)); }
          }),
          KoraCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(selectedEquipment.isEmpty ? 'Sin equipo · peso corporal' : '${selectedEquipment.length} equipos seleccionados', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 12),
            if (equipmentError != null) ...[Text(equipmentError!), TextButton(onPressed: loadEquipment, child: const Text('Reintentar catálogo'))]
            else OutlinedButton.icon(onPressed: pickEquipment, icon: const Icon(Icons.tune), label: const Text('Elegir equipamiento')),
            if (selectedEquipment.isNotEmpty) Wrap(spacing: 6, children: [for (final code in selectedEquipment) InputChip(label: Text(equipment.where((e) => e.code == code).firstOrNull?.name ?? code), onDeleted: () => setState(() { selectedEquipment.remove(code); profileSaved = false; }))]),
          ])),
        ],
        if (step == 4) ...[
          const Text('Desactiva los movimientos que prefieres evitar.', style: TextStyle(fontSize: 16, color: Kora.muted)), const SizedBox(height: 16),
          KoraCard(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(children: [for (final entry in permissionLabels.entries) SwitchListTile(title: Text(entry.value, style: const TextStyle(fontSize: 16)), value: permissions[entry.key]!, onChanged: (v) => setState(() { permissions[entry.key] = v; profileSaved = false; }))])),
          const SizedBox(height: 12),
          const Text('Tu perfil no se podrá cambiar durante el estudio. Si hay ejercicios concretos que no puedes o no quieres hacer, agrégalos también.', style: TextStyle(fontSize: 14, color: Kora.muted)), const SizedBox(height: 12),
          KoraCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(blocked.isEmpty ? 'Sin ejercicios excluidos' : '${blocked.length} ${blocked.length == 1 ? 'ejercicio excluido' : 'ejercicios excluidos'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: pickBlocked, icon: const Icon(Icons.block), label: const Text('Elegir ejercicios a evitar')),
            if (blocked.isNotEmpty) Wrap(spacing: 6, children: [for (final entry in blocked.entries) InputChip(label: Text(entry.value), onDeleted: () => setState(() { blocked.remove(entry.key); profileSaved = false; }))]),
          ])),
          const SizedBox(height: 24), field('Notas de salud (opcional)', notes, maxLength: 500, lines: 3, validator: (v) => (v ?? '').length > 500 ? 'Máximo 500 caracteres' : null),
          const Text('Las notas son informativas. Usa los interruptores y la lista de ejercicios a evitar para excluir movimientos.', style: TextStyle(fontSize: 14,color: Kora.muted)),
        ],
      ])),
      if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical:16), child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 15))),
      const SizedBox(height: 24), KoraButton(label: step < 4 ? 'Continuar' : profileSaved ? 'Reintentar generación' : 'Generar mi plan', onPressed: step < 4 ? advance : submit), const SizedBox(height: 24),
    ]));
  }
}
