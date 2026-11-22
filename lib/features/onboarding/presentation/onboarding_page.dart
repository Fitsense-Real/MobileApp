import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/api/api_error.dart';
import '../../../shared/widgets/kora_ui.dart';
import '../../welcome/presentation/first_plan_generation_controller.dart';
import '../../welcome/presentation/welcome_routes.dart';
import '../../welcome/domain/generation_operation.dart';
import '../data/profile_repository.dart';
import '../domain/minimum_age.dart';
import 'equipment_picker.dart';
import 'generating_plan.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> with SingleTickerProviderStateMixin {
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
  bool loading = true, busy = false, exists = false, loadFailed = false, profileSaved = false;
  /// The 30 s generation screen: visual clock (never the backend's progress)
  /// and the timer that ends it. `preserve` keeps the bar on real time with
  /// reduced motion too.
  late final AnimationController generationClock = AnimationController(vsync: this, duration: generationScreenDuration, animationBehavior: AnimationBehavior.preserve);
  Timer? generationTimer;
  /// The 30 s are over / the save + request finished / the result is late.
  bool screenTimeOver = false, requestFinished = false, resultPending = false;
  /// Error of the save or of the request, shown only when the 30 s are over.
  String? requestError;
  /// The generation ended in FAILED or NO_FACTIBLE (shown after the 30 s).
  GenerationOperation? failedOperation;
  String? error, equipmentError, sex;
  String level = 'BEGINNER', goal = 'GENERAL_FITNESS', location = 'HOME';
  final days = <int>{1, 3, 5};
  int get maxWeeklySessions => level == 'BEGINNER' ? 4 : 6;
  String? get daysError => days.isEmpty ? 'Elige al menos un día para entrenar.' : days.length > maxWeeklySessions ? 'Para ${levels[level]} puedes elegir como máximo $maxWeeklySessions días. Desmarca ${days.length - maxWeeklySessions} para continuar.' : null;
  final selectedEquipment = <String>{};
  /// `blockedExerciseIds`: the onboarding no longer offers the exercise list,
  /// so a new profile sends `[]`; an existing profile keeps what it had.
  final blockedExerciseIds = <int>[];
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
  void dispose() { generationTimer?.cancel(); generationClock.dispose(); for (final c in [birth, height, weight, target, goalText, minutes, notes]) { c.dispose(); } scroll.dispose(); super.dispose(); }

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
        // Saved choices are kept exactly as they are (bodyweight is not added).
        selectedEquipment..clear()..addAll((data['equipmentCodes'] as List? ?? []).cast<String>());
        blockedExerciseIds..clear()..addAll([for (final id in (data['blockedExerciseIds'] as List? ?? [])) (id as num).toInt()]);
        for (final key in permissions.keys.toList()) { permissions[key] = data[key] as bool? ?? true; }
      } else {
        // First equipment setup: «Peso corporal» starts selected, whatever the
        // location. It is a default, not a rule: the user can untick it, and
        // nothing adds it back (switching location included).
        selectedEquipment.add(bodyWeightCode);
      }
      await loadEquipment();
    } catch (e) { if (mounted) setState(() { error = apiError(e); loadFailed = true; }); }
    finally { if (mounted) setState(() => loading = false); }
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
    if (date == null || date.toIso8601String().substring(0, 10) != value || !date.isBefore(DateTime(now.year, now.month, now.day))) return 'Elige una fecha anterior a hoy';
    return ageOn(date, now) < minimumAge ? minimumAgeMessage : null;
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
      'equipmentCodes': selectedEquipment.toList()..sort(), 'blockedExerciseIds': blockedExerciseIds.toList()..sort(),
      'healthNotes': notes.text.trim().isEmpty ? null : notes.text.trim(), ...permissions,
    };
  }
  Future<void> submit() async {
    if (!profileSaved && daysError != null) { setState(() { step = 2; error = daysError; }); return; }
    if (busy || (!profileSaved && !form.currentState!.validate())) return;
    FocusScope.of(context).unfocus();
    final generation = ref.read(firstPlanGenerationProvider.notifier);
    final previous = failedOperation;
    // The generation screen stays exactly 30 s from this tap, whatever the
    // backend does: the result is only looked at when the time is over.
    generationTimer?.cancel();
    setState(() {
      busy = true; error = null; failedOperation = null;
      screenTimeOver = false; requestFinished = false; resultPending = false; requestError = null;
    });
    generationClock.forward(from: 0);
    generationTimer = Timer(generationScreenDuration, () { screenTimeOver = true; settleGeneration(); });
    try {
      if (!profileSaved) {
        await ref.read(profileRepositoryProvider).save(profileBody(), exists: exists);
        if (!mounted) return;
        exists = true; profileSaved = true;
      }
      // One request per tap; the backend is idempotent, so a retry never starts
      // a second generation. After a retryable failure the backend opens a new
      // operation only because the previous one is closed.
      if (previous != null && previous.retryable) {
        await generation.retry();
      } else {
        await generation.start();
      }
      if (!mounted) return;
      final refused = ref.read(firstPlanGenerationProvider).error;
      if (refused != null) throw Exception(refused);
    } catch (e) {
      requestError = '${profileSaved ? 'Tu perfil está guardado. ' : ''}${apiError(e)}';
    }
    if (!mounted) return;
    requestFinished = true;
    settleGeneration();
  }

  /// Decides what follows the generation screen. Does nothing until the 30 s
  /// are over; then continues if the plan is ready, shows the error, or shows
  /// the pending state (never a plan that does not exist). Called again on
  /// every change of the generation while the pending state is shown.
  void settleGeneration() {
    if (!mounted || !busy || !screenTimeOver) return;
    if (!requestFinished) { if (!resultPending) setState(() => resultPending = true); return; }
    if (requestError != null) {
      setState(() { busy = false; resultPending = false; error = requestError; });
      return;
    }
    final state = ref.read(firstPlanGenerationProvider);
    final operation = state.operation;
    if (state.error != null) {
      setState(() { busy = false; resultPending = false; error = 'Tu perfil está guardado. ${state.error}'; });
    } else if (operation?.status == GenerationStatus.completed) {
      generationTimer?.cancel();
      context.go(welcomeTourRoute);
    } else if (operation != null && operation.isTerminal) {
      setState(() {
        busy = false; resultPending = false; failedOperation = operation;
        error = 'Tu perfil está guardado. ${operation.message ?? (operation.status == GenerationStatus.noFactible ? 'No encontramos una rutina compatible con tu perfil.' : 'No pudimos preparar tu rutina.')}';
      });
    } else if (!resultPending) {
      setState(() => resultPending = true);
    }
  }

  /// Pending state: the user goes on to Kora; the generation keeps running and
  /// its real result is shown after the welcome tour.
  void continueWhilePending() {
    generationTimer?.cancel();
    context.go(welcomeTourRoute);
  }

  Widget field(String label, TextEditingController controller, {String? Function(String?)? validator, TextInputType? keyboard, int? maxLength, int lines = 1}) => Padding(key: ValueKey(label), padding: const EdgeInsets.only(bottom: 20), child: TextFormField(controller: controller, maxLength: maxLength, maxLines: lines, style: const TextStyle(fontSize: 16), keyboardType: keyboard, decoration: InputDecoration(labelText: label, alignLabelWithHint: true), validator: validator));
  Widget choices(String label, Map<String, String> options, String selected, ValueChanged<String> choose) => Padding(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: [for (final item in options.entries) ChoiceChip(label: Text(item.value), selected: selected == item.key, selectedColor: Kora.lime, onSelected: (_) => setState(() { choose(item.key); profileSaved = false; }))])]));
  Future<void> pickEquipment() async {
    final result = await showModalBottomSheet<Set<String>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => FractionallySizedBox(heightFactor: .88, child: EquipmentPicker(items: equipment, selected: selectedEquipment, home: location == 'HOME')));
    if (result != null && mounted) setState(() { selectedEquipment..clear()..addAll(result); profileSaved = false; });
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
    if (busy) {
      // Every change of the generation is looked at, but acted on only after the 30 s.
      ref.listen(firstPlanGenerationProvider, (_, __) => settleGeneration());
      final problem = resultPending ? switch (ref.watch(firstPlanGenerationProvider).problem) {
        CheckProblem.connection => 'No hay conexión para consultar el resultado. Lo seguimos intentando; puedes continuar mientras tanto.',
        CheckProblem.server => 'El servidor no responde por ahora. Tu perfil no se pierde; lo seguimos intentando.',
        CheckProblem.none => null,
      } : null;
      return GeneratingPlan(progress: generationClock, pending: resultPending, problem: problem, onContinue: requestFinished ? continueWhilePending : null);
    }
    if (profileSaved) {
      final failed = failedOperation;
      return KoraPage(child: ListView(padding: const EdgeInsets.all(24), children: [
      const KoraLogo(), const SizedBox(height: 24),
      Text(error ?? 'Tu perfil está guardado.'), const SizedBox(height: 24),
      // A failure the backend does not let us retry: its options (contact the
      // study team) are on the result screen after the welcome tour.
      if (failed != null && !failed.retryable) KoraButton(label: 'Continuar', onPressed: continueWhilePending)
      else KoraButton(label: 'Reintentar generación', onPressed: submit),
    ]));
    }
    if (loadFailed) return KoraPage(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(error!), const SizedBox(height: 20), KoraButton(label: 'Reintentar', onPressed: load), TextButton(onPressed: () => context.go(AppRoutes.login), child: const Text('Iniciar sesión'))])));
    const titles = [('¿Cuál es tu', 'objetivo?'), ('Perfil', 'físico.'), ('Tu ritmo', 'semanal.'), ('¿Qué equipo', 'tienes?'), ('Tu movimiento,', 'tu bienestar.')];
    return KoraPage(maxWidth: 560, child: ListView(controller: scroll, padding: const EdgeInsets.all(24), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: () { if (step > 0) { setState(() { step--; error = null; }); scroll.jumpTo(0); } else { context.go(AppRoutes.dashboard); } }, icon: const Icon(Icons.arrow_back), tooltip: 'Volver'), Expanded(child: Text('Paso ${step + 1} de 5', textAlign: TextAlign.center, style: const TextStyle(color: Kora.muted))), const KoraLogo(width: 70)]),
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
          DropdownButtonFormField<String>(isExpanded: true, initialValue: sex, decoration: const InputDecoration(labelText: 'Sexo biológico (opcional)'), items: const [DropdownMenuItem(value: null, child: Text('Prefiero no indicarlo')), DropdownMenuItem(value: 'MALE', child: Text('Masculino')), DropdownMenuItem(value: 'FEMALE', child: Text('Femenino')), DropdownMenuItem(value: 'OTHER', child: Text('Otro'))], onChanged: (v) => setState(() => sex = v)), const SizedBox(height: 20),
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
          KoraCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(selectedEquipment.isEmpty ? 'Sin equipo seleccionado' : '${selectedEquipment.length} ${selectedEquipment.length == 1 ? 'equipo seleccionado' : 'equipos seleccionados'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), const SizedBox(height: 4),
            const Text('Peso corporal viene marcado. Puedes quitarlo o agregar el equipo que tengas.', style: TextStyle(color: Kora.muted)), const SizedBox(height: 12),
            if (equipmentError != null) ...[Text(equipmentError!), TextButton(onPressed: loadEquipment, child: const Text('Reintentar catálogo'))]
            else OutlinedButton.icon(onPressed: pickEquipment, icon: const Icon(Icons.tune), label: const Text('Elegir equipamiento')),
            if (selectedEquipment.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: [for (final code in selectedEquipment) InputChip(label: Text(equipment.where((e) => e.code == code).firstOrNull?.name ?? (code == bodyWeightCode ? 'Peso corporal' : code)), onDeleted: () => setState(() { selectedEquipment.remove(code); profileSaved = false; }))]),
          ])),
        ],
        if (step == 4) ...[
          const Text('Desactiva los movimientos que prefieres evitar.', style: TextStyle(fontSize: 16, color: Kora.muted)), const SizedBox(height: 16),
          KoraCard(padding: const EdgeInsets.symmetric(horizontal: 8), child: Material(type: MaterialType.transparency, borderRadius: BorderRadius.circular(16), clipBehavior: Clip.antiAlias, child: Column(children: [for (final entry in permissionLabels.entries) SwitchListTile(title: Text(entry.value, style: const TextStyle(fontSize: 16)), value: permissions[entry.key]!, onChanged: (v) => setState(() { permissions[entry.key] = v; profileSaved = false; }))]))),
          const SizedBox(height: 12),
          const Text('Tu perfil no se podrá cambiar durante el estudio.', style: TextStyle(fontSize: 14, color: Kora.muted)),
          const SizedBox(height: 24), field('Notas de salud (opcional)', notes, maxLength: 500, lines: 3, validator: (v) => (v ?? '').length > 500 ? 'Máximo 500 caracteres' : null),
          const Text('Las notas son informativas. Usa los interruptores para excluir movimientos.', style: TextStyle(fontSize: 14,color: Kora.muted)),
        ],
      ])),
      if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical:16), child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 15))),
      const SizedBox(height: 24), KoraButton(label: step < 4 ? 'Continuar' : profileSaved ? 'Reintentar generación' : 'Generar mi plan', onPressed: step < 4 ? advance : submit), const SizedBox(height: 24),
    ]));
  }
}
