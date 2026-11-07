import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/kora_ui.dart';
import '../../../../core/api/api_error.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../plans/data/plan_repository.dart';
import '../../../workouts/domain/workout_rules.dart';
import '../../../workouts/presentation/planned_workout_page.dart';
import '../../../pain/presentation/pain_exclusions_sheet.dart';
import '../widgets/plan_history_sheet.dart';
import '../../data/dashboard_repository.dart';

/// Dates (yyyy-MM-dd) are shown as sent; timestamps with an offset are shown
/// in local time so a 23:59-05:00 value never moves to the next day in UTC.
DateTime? parseDate(dynamic value) {
  final date = DateTime.tryParse('$value');
  return date != null && date.isUtc ? date.toLocal() : date;
}

String displayDate(dynamic value) {
  final date = parseDate(value);
  return date == null
      ? 'Sin fecha'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String trainingDay(dynamic value) {
  final date = parseDate(value);
  if (date == null) return 'Sin fecha';
  const days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  return '${days[date.weekday - 1]} · ${displayDate(value)}';
}

String metricValue(dynamic value, {String suffix = ''}) => value is num
    ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$suffix'
    : '—';
String workoutStatus(dynamic status) => workoutStatusLabel(status);

const movementLabels = {
  'allowHighImpact': 'saltos y alto impacto',
  'allowFloorExercises': 'ejercicios en el suelo',
  'allowKneelingExercises': 'ejercicios de rodillas',
  'allowHangingExercises': 'ejercicios colgado',
  'allowOverheadExercises': 'brazos sobre la cabeza',
};

/// Movements the profile excludes (`allow* = false`, V25), as a profile line.
String avoidedMovements(Json profile) {
  final avoided = [for (final e in movementLabels.entries) if (profile[e.key] == false) e.value];
  return avoided.isEmpty ? '' : '\nEvitas: ${avoided.join(', ')}';
}

const riskLevelLabels = {'LOW': 'Bajo', 'MODERATE': 'Moderado', 'HIGH': 'Alto', 'CRITICAL': 'Crítico'};

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  late int tab = widget.initialTab.clamp(0, 3);
  bool searching = false, favoritesOnly = false;
  String category = 'Todos', query = '';
  String? selectedWeek;
  final favorites = <String>{};
  int? favoritesUser;
  bool favoritesLoaded = false;
  Future<void> loadFavorites(int? userId) async {
    if (favoritesLoaded && favoritesUser == userId) return;
    favoritesLoaded = true;
    favoritesUser = userId;
    favorites.clear();
    if (userId == null) return;
    try {
      final stored = await const FlutterSecureStorage().read(
        key: 'kora_favorites_$userId',
      );
      if (mounted && favoritesUser == userId && stored != null) {
        setState(
          () => favorites.addAll((jsonDecode(stored) as List).cast<String>()),
        );
      }
    } catch (_) {
      if (mounted) favoritesLoaded = false;
    }
  }

  Future<void> toggleFavorite(Json workout) async {
    final id = '${workout['plannedWorkoutId']}';
    final userId = ref.read(authViewModelProvider).user?.id;
    if (userId == null) return;
    final next = {...favorites};
    next.contains(id) ? next.remove(id) : next.add(id);
    try {
      await const FlutterSecureStorage().write(
        key: 'kora_favorites_$userId',
        value: jsonEncode(next.toList()),
      );
      if (mounted && ref.read(authViewModelProvider).user?.id == userId) {
        setState(() {
          favorites.clear();
          favorites.addAll(next);
        });
      }
    } catch (e) {
      if (mounted) {
        showInfo(
          'Favoritos',
          'No se pudo guardar el favorito. Inténtalo nuevamente.',
        );
      }
    }
  }

  Future<void> refresh() async {
    ref.invalidate(currentPlanProvider);
    ref.invalidate(weeklyMetricsProvider);
    ref.invalidate(interventionsProvider);
    ref.invalidate(dashboardProfileProvider);
    ref.invalidate(planAdaptationsProvider);
    ref.invalidate(planLimitationsProvider);
    // Each section renders its own error instead of hiding successful sections.
    await Future.wait<void>([
      ref
          .read(currentPlanProvider.future)
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      ref
          .read(weeklyMetricsProvider.future)
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      ref
          .read(interventionsProvider.future)
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
      ref
          .read(dashboardProfileProvider.future)
          .then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    ]);
  }

  Widget section<T>(
    AsyncValue<T> value,
    Widget Function(T) body,
    VoidCallback retry,
  ) => value.when(
    loading: () => const Padding(
      padding: EdgeInsets.all(20),
      child: LinearProgressIndicator(),
    ),
    error: (e, _) => KoraCard(
      child: Column(
        children: [
          Text(apiError(e)),
          TextButton(onPressed: retry, child: const Text('Reintentar')),
        ],
      ),
    ),
    data: body,
  );
  void showInfo(String title, String message) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
  Widget heading(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w800,
      letterSpacing: -.8,
    ),
  );
  Widget label(String text, {Color color = Kora.sage}) => Text(
    text.toUpperCase(),
    style: TextStyle(
      color: color,
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.7,
    ),
  );
  Widget surface(
    Widget child, {
    Color color = Colors.white,
    EdgeInsets padding = const EdgeInsets.all(22),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: const Color(0x0D0F2E25)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x050F2E25),
          offset: Offset(0, 2),
          blurRadius: 2,
        ),
      ],
    ),
    child: child,
  );
  Widget tool(IconData icon, String tooltip, VoidCallback action) => IconButton(
    tooltip: tooltip,
    onPressed: action,
    icon: Icon(icon, size: 19),
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Kora.sage,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  );
  /// Category chip from planning `WorkoutFocus`; unknown focus is General.
  String categoryOf(Json workout) => workoutFocusLabels['${workout['focusCode']}'] ?? 'General';

  String photo(Json workout) => switch ('${workout['focusCode']}') {
    'FULL_BODY' => 'full_body',
    'UPPER_BODY' || 'PUSH' || 'PULL' => 'strength',
    'LOWER_BODY' || 'LEGS' => 'home_body',
    'CORE' => 'mobility',
    _ => 'full_body',
  };
  List<Json> workoutsOf(Json? plan) => jsonRows(
    plan?['workouts'] ?? [],
  )..sort((a, b) => '${a['scheduledDate']}'.compareTo('${b['scheduledDate']}'));
  Future<void> openWorkout(Json workout) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlannedWorkoutPage(workout: workout),
      ),
    );
    if (mounted) await refresh();
  }

  Widget routineCard(Json workout, {bool large = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openWorkout(workout),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (large)
              Stack(
                children: [
                  Image.asset(
                    'assets/images/kora/${photo(workout)}.jpg',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                  Positioned(
                    left: 18,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Kora.lime,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        categoryOf(workout).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (!large) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/images/kora/${photo(workout)}.jpg',
                        width: 78,
                        height: 86,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Kora.forest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            metricValue(
                              workout['expectedDurationMinutes'],
                              suffix: ' MIN',
                            ),
                            style: const TextStyle(
                              color: Kora.lime,
                              fontWeight: FontWeight.w800,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${workout['workoutName'] ?? 'Entrenamiento'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          workoutStatus(workout['status']),
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: .6,
                            color: Kora.sage,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de rutina',
                    icon: const Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: Kora.sage,
                    ),
                    onSelected: (_) => toggleFavorite(workout),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'favorite',
                        child: Text(
                          favorites.contains('${workout['plannedWorkoutId']}')
                              ? 'Quitar de favoritos'
                              : 'Guardar en favoritos',
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Kora.sage),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget emptyPlan() => surface(
    Column(
      children: [
        const Text('No tienes un plan disponible.'),
        TextButton(
          onPressed: () => context.go('/account-setup'),
          child: const Text('Preparar mi plan'),
        ),
      ],
    ),
  );
  Widget heroPlan(Json? plan) {
    if (plan == null) return emptyPlan();
    final end = DateTime.tryParse('${plan['weekEndDate']}');
    final now = DateTime.now();
    final remaining = end == null
        ? null
        : end.difference(DateTime(now.year, now.month, now.day)).inDays + 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: ColoredBox(
        color: Kora.forest,
        child: CustomPaint(
          painter: const KoraPattern(color: Color(0x183E6A33)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Kora.lime,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const KoraLogo(width: 48),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: label(
                        (plan['planVersion'] as num? ?? 1) > 1
                            ? 'Tu plan de la semana · v${plan['planVersion']}'
                            : 'Tu plan de la semana',
                        color: Kora.lime,
                      ),
                    ),
                    if (remaining != null && remaining > 0)
                      Text(
                        '$remaining DÍAS',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text.rich(
                            TextSpan(
                              text: 'Muévete\n',
                              children: [
                                TextSpan(
                                  text: 'a tu ritmo',
                                  style: TextStyle(color: Kora.lime),
                                ),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: 27,
                              height: 1.1,
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.8,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(() {
                              tab = 1;
                              favoritesOnly = false;
                            }),
                            style: FilledButton.styleFrom(
                              backgroundColor: Kora.lime,
                              foregroundColor: Kora.forest,
                              visualDensity: VisualDensity.compact,
                              minimumSize: const Size(0, 34),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'VER PLAN  ›',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/kora/challenge.jpg',
                        width: 110,
                        height: 120,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget compactProgress(List<Json> rows) {
    final metric = rows.firstOrNull;
    final percent = metric?['weightedAdherencePct'] as num?;
    return InkWell(
      onTap: () => setState(() => tab = 2),
      borderRadius: BorderRadius.circular(30),
      child: surface(
        Row(
          children: [
            SizedBox(
              width: 49,
              height: 49,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: percent == null
                          ? 0
                          : (percent / 100).clamp(0, 1).toDouble(),
                      color: Kora.lime,
                      backgroundColor: Kora.ivory,
                      strokeWidth: 4,
                    ),
                  ),
                  Text(
                    metricValue(percent, suffix: '%'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu progreso',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Text(
                    metric == null
                        ? 'Sin métricas calculadas'
                        : '${metricValue(metric['completedWorkouts'])}/${metricValue(metric['scheduledWorkouts'])} entrenamientos',
                    style: const TextStyle(fontSize: 10, color: Kora.sage),
                  ),
                  if (metric != null)
                    Text(
                      'Semana del ${displayDate(metric['weekStartDate'])}',
                      style: const TextStyle(fontSize: 9, color: Kora.sage),
                    ),
                ],
              ),
            ),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Kora.ivory,
              child: Icon(Icons.arrow_forward, size: 16, color: Kora.forest),
            ),
          ],
        ),
      ),
    );
  }

  Widget todayRoutines(Json? plan) {
    if (plan == null) return const SizedBox.shrink();
    final all = workoutsOf(plan);
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayRows = all.where((w) => w['scheduledDate'] == today).toList();
    final future = all
        .where((w) => '${w['scheduledDate']}'.compareTo(today) > 0)
        .toList();
    final rows = todayRows.isNotEmpty ? todayRows : future;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                todayRows.isNotEmpty ? 'Rutinas para hoy' : 'Próximas rutinas',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                tab = 1;
                favoritesOnly = false;
              }),
              child: label('Explorar todas'),
            ),
          ],
        ),
        if (rows.isEmpty)
          surface(
            const Text(
              'No tienes entrenamientos programados para hoy o los próximos días.',
            ),
          ),
        for (final workout in rows.take(2)) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              trainingDay(workout['scheduledDate']),
              style: const TextStyle(color: Kora.sage, fontSize: 11),
            ),
          ),
          routineCard(workout, large: true),
        ],
      ],
    );
  }

  Widget routines(Json? plan) {
    if (plan == null) return emptyPlan();
    final all = workoutsOf(plan);
    final categories = [
      'Todos',
      ...all.map(categoryOf).toSet(),
    ];
    final activeCategory = categories.contains(category) ? category : 'Todos';
    final rows = all
        .where(
          (w) =>
              (activeCategory == 'Todos' || categoryOf(w) == activeCategory) &&
              '${w['workoutName']}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (!favoritesOnly ||
                  favorites.contains('${w['plannedWorkoutId']}')),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (searching)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                hintText: 'Buscar en mi plan',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text(
                      value.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    selected: activeCategory == value,
                    onSelected: (_) => setState(() => category = value),
                    selectedColor: Kora.lime,
                    backgroundColor: Colors.white,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final day in rows.map((w) => w['scheduledDate']).toSet()) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              trainingDay(day),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Kora.sage,
              ),
            ),
          ),
          for (final workout in rows.where((w) => w['scheduledDate'] == day))
            routineCard(workout),
        ],
        if (rows.isEmpty)
          surface(
            Text(
              favoritesOnly
                  ? 'No tienes rutinas favoritas en este plan y filtro.'
                  : 'No hay rutinas para este filtro.',
            ),
          ),
      ],
    );
  }

  Widget progress(List<Json> rows, List<Json> interventions, [List<Json>? adaptations]) {
    if (rows.isEmpty) {
      return surface(
        const Text('Todavía no hay métricas semanales calculadas.'),
      );
    }
    final metric =
        rows.where((r) => r['weekStartDate'] == selectedWeek).firstOrNull ??
        rows.first;
    final index = rows.indexOf(metric);
    final previous = index + 1 < rows.length
        ? rows[index + 1]['weightedAdherencePct'] as num?
        : null;
    final pct = metric['weightedAdherencePct'] as num?;
    final change = pct == null || previous == null ? null : pct - previous;
    final chart = rows.take(7).toList().reversed.toList();
    // generation: GET /users/me/plan/adaptations says whether the plan that
    // came out of an adaptation really changed (`resultado`). Without that
    // record, fall back to interventions: the backend stores one every week,
    // NONE included, so only a real adjustment counts.
    final adaptation = metric['planId'] == null
        ? null
        : adaptations?.where((a) => a['resultingPlanId'] == metric['planId']).firstOrNull;
    final adjusted = adaptation != null
        ? appliedAdaptationResults.contains(adaptation['resultado'])
        : metric['planId'] != null &&
            interventions.any(
              (r) =>
                  r['resultingPlanId'] == metric['planId'] &&
                  ((r['adjustmentTypes'] as List?) ?? const [])
                      .any((t) => t != 'NONE'),
            );
    final coverage = metric['registrationCoveragePct'] as num?;
    final observed = metric['observedAdherencePct'] as num?;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: DropdownButton<String>(
            value: '${metric['weekStartDate']}',
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            items: [
              for (final r in rows)
                DropdownMenuItem(
                  value: '${r['weekStartDate']}',
                  child: Text(
                    'Semana del ${displayDate(r['weekStartDate'])}',
                    style: const TextStyle(fontSize: 11, color: Kora.sage),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => selectedWeek = v),
          ),
        ),
        surface(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: label('Adherencia semanal')),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Kora.lime,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.bar_chart, size: 21),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    metricValue(pct, suffix: '%'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 30,
                    ),
                  ),
                  if (change != null)
                    Text(
                      '${change >= 0 ? '+' : ''}${metricValue(change)} pp',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Kora.sage,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 160,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final r in chart)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Semantics(
                                label:
                                    'Semana del ${displayDate(r['weekStartDate'])}: ${metricValue(r['weightedAdherencePct'], suffix: '%')}',
                                child: Container(
                                  height: r['weightedAdherencePct'] is num
                                      ? ((r['weightedAdherencePct'] as num)
                                                    .clamp(0, 100) /
                                                100 *
                                                125)
                                            .toDouble()
                                      : 0,
                                  constraints: const BoxConstraints(
                                    maxWidth: 36,
                                  ),
                                  decoration: BoxDecoration(
                                    color: r == metric
                                        ? Kora.lime
                                        : Kora.forest,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                displayDate(r['weekStartDate']).substring(0, 5),
                                style: const TextStyle(
                                  color: Kora.sage,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              label('Por semana · últimos ${chart.length} registros'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: surface(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label('Sesiones'),
                      const SizedBox(height: 18),
                      Text.rich(
                        TextSpan(
                          text: metricValue(metric['completedWorkouts']),
                          style: const TextStyle(
                            fontSize: 32,
                            color: Kora.lime,
                            fontWeight: FontWeight.w900,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  ' / ${metricValue(metric['scheduledWorkouts'])}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${metricValue(metric['totalTrainingMinutes'])} min entrenados',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  color: Kora.forest,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: surface(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label('Adaptación'),
                      const SizedBox(height: 18),
                      Text(
                        adjusted
                            ? 'Plan adaptado a ti'
                            : 'Sin ajustes registrados',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Icon(Icons.auto_awesome, size: 20),
                    ],
                  ),
                  color: Kora.lime,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          [
            'Calculado: ${displayDate(metric['calculatedAt'])}',
            if (riskLevelLabels[metric['riskLevel']] != null)
              'Riesgo de abandono: ${riskLevelLabels[metric['riskLevel']]}',
          ].join(' · '),
          style: const TextStyle(color: Kora.sage, fontSize: 10),
        ),
        // V30: how much of the week has a record. A low value means missing
        // data, not 0 % adherence, so the observed value is shown apart.
        if (coverage != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                'Registraste ${metricValue(metric['recordedWorkouts'])} de ${metricValue(metric['scheduledWorkouts'])} entrenamientos (${metricValue(coverage, suffix: '%')})',
                if (coverage < 100 && observed != null)
                  'Cumplimiento en lo registrado: ${metricValue(observed, suffix: '%')}',
              ].join(' · '),
              style: const TextStyle(color: Kora.sage, fontSize: 10),
            ),
          ),
        if (adaptation?['motivoTexto'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${adaptation!['motivoTexto']}', style: const TextStyle(color: Kora.sage, fontSize: 10)),
          ),
      ],
    );
  }

  Widget adjustments(List<Json> rows) => surface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label('♧  Resumen de ajustes'),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const Text(
            'Tu plan aún no tiene ajustes registrados.',
            style: TextStyle(fontSize: 12, color: Kora.sage),
          ),
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Kora.ivory,
                child: Icon(Icons.trending_up, color: Kora.sage, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajuste del ${displayDate(row['appliedAt'])}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${row['messageShown'] ?? 'Ajuste aplicado al plan.'}',
                      style: const TextStyle(
                        color: Kora.sage,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
  void notifications() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => Consumer(
      builder: (context, ref, _) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('Novedades de tu plan'),
                const SizedBox(height: 20),
                section(
                  ref.watch(interventionsProvider),
                  adjustments,
                  () => ref.invalidate(interventionsProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget avatar(String name, {bool large = false}) => Container(
    width: large ? 104 : 38,
    height: large ? 104 : 38,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(large ? 30 : 14),
      border: Border.all(color: Kora.lime, width: 2),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE4EBD6),
        borderRadius: BorderRadius.circular(large ? 24 : 10),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? 'K' : name[0].toUpperCase(),
        style: TextStyle(
          fontSize: large ? 44 : 18,
          fontWeight: FontWeight.w800,
          color: Kora.forest,
        ),
      ),
    ),
  );
  Widget menuRow(
    IconData icon,
    String text,
    VoidCallback action, {
    bool danger = false,
  }) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
    leading: Icon(icon, color: danger ? Colors.redAccent : Kora.sage, size: 20),
    title: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: danger ? Colors.redAccent : Kora.forest,
      ),
    ),
    trailing: danger ? null : const Icon(Icons.chevron_right, size: 16),
    onTap: action,
  );
  /// GET /users/me/plan/limitations. Informative: hidden while loading or on
  /// error so it never blocks the routines below.
  Widget planLimitations() {
    final items = jsonRows(ref.watch(planLimitationsProvider).asData?.value['limitations']);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Lo que tu plan no puede cubrir'),
            for (final item in items) ...[
              const SizedBox(height: 12),
              Text('${item['title'] ?? item['code']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              if (item['message'] != null)
                Text('${item['message']}', style: const TextStyle(color: Kora.sage, fontSize: 11, height: 1.5)),
            ],
          ],
        ),
        color: Kora.ivory,
      ),
    );
  }

  void painExclusions() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: const PainExclusionsSheet(),
      ),
    ),
  );

  void planHistory() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: const PlanHistorySheet(),
      ),
    ),
  );

  Widget studyStatus() => Consumer(builder: (context, ref, _) {
    final user = ref.watch(authViewModelProvider).user;
    if (user == null) return const SizedBox.shrink();
    if (!user.studyParticipant) {
      return const Text('No participas en el estudio.', style: TextStyle(color: Kora.sage));
    }
    if (user.withdrawnAt != null) {
      return Text('Te retiraste del estudio el ${displayDate(user.withdrawnAt!.toIso8601String())}.', style: const TextStyle(color: Kora.sage));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Participas en el estudio${user.participantCode == null ? '' : ' · código ${user.participantCode}'}.'),
      TextButton(
        onPressed: () => withdraw(context),
        style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: EdgeInsets.zero),
        child: const Text('Retirarme del estudio'),
      ),
    ]);
  });

  Future<void> withdraw(BuildContext sheetContext) async {
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (context) => AlertDialog(
        title: const Text('Retirarme del estudio'),
        content: const Text('Dejarás de participar en el estudio. Los datos ya recolectados no se borran y puedes seguir usando la app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Retirarme')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authViewModelProvider.notifier).withdrawFromStudy();
    } catch (e) {
      if (mounted) showInfo('Retirarme del estudio', apiError(e));
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(authViewModelProvider.notifier).logout();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) showInfo('Cerrar sesión', apiError(e));
    }
  }

  Widget profileBody(
    String name,
    String email,
    AsyncValue<Json?> profile,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 22),
      Center(child: avatar(name, large: true)),
      const SizedBox(height: 18),
      Center(
        child: Text(
          name,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 7),
      Center(
        child: Text(
          email,
          style: const TextStyle(fontSize: 11, color: Kora.sage),
        ),
      ),
      const SizedBox(height: 34),
      label('Actividad'),
      const SizedBox(height: 16),
      surface(
        Column(
          children: [
            menuRow(
              Icons.favorite_border,
              'Mis favoritos',
              () => setState(() {
                tab = 1;
                favoritesOnly = true;
                category = 'Todos';
                query = '';
              }),
            ),
            const Divider(height: 1),
            menuRow(Icons.notifications_none, 'Notificaciones', notifications),
            const Divider(height: 1),
            menuRow(Icons.history, 'Historial de planes', planHistory),
            const Divider(height: 1),
            menuRow(Icons.healing_outlined, 'Ejercicios excluidos por dolor', painExclusions),
          ],
        ),
        padding: EdgeInsets.zero,
      ),
      const SizedBox(height: 30),
      label('Configuración'),
      const SizedBox(height: 16),
      surface(
        Column(
          children: [
            menuRow(
              Icons.person_outline,
              'Cuenta',
              () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        heading('Mi cuenta'),
                        Text(email),
                        const SizedBox(height: 20),
                        section(
                          profile,
                          (data) => Text(
                            data == null
                                ? 'No hay perfil registrado.'
                                : '${data['goalText'] ?? ''}\nCumpleaños: ${displayDate(data['birthDate'])}\nEstatura: ${metricValue(data['heightCm'], suffix: ' cm')}\nPeso: ${metricValue(data['currentWeightKg'], suffix: ' kg')}\n${metricValue(data['daysPerWeek'])} días · ${metricValue(data['sessionMinutes'], suffix: ' min')}${avoidedMovements(data)}',
                          ),
                          () => ref.invalidate(dashboardProfileProvider),
                        ),
                        const SizedBox(height: 20),
                        const Text('Perfil de solo lectura: se mantiene durante todo el estudio.', style: TextStyle(color: Kora.sage)),
                        const SizedBox(height: 20),
                        studyStatus(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            menuRow(
              Icons.help_outline,
              'Ayuda y soporte',
              () => showInfo(
                'Tu entrenamiento',
                'Abre una rutina de tu plan para ver los GIF y registrar cada ejercicio. Puedes indicar que lo completaste, lo realizaste parcialmente o no lo hiciste. Desliza hacia abajo para actualizar tus datos.',
              ),
            ),
            const Divider(height: 1),
            menuRow(Icons.logout, 'Cerrar sesión', logout, danger: true),
          ],
        ),
        padding: EdgeInsets.zero,
      ),
      const SizedBox(height: 28),
      surface(
        const Row(
          children: [
            Expanded(
              child: Text(
                'Tu rutina también cuenta.\nSigue adelante.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.eco_outlined, color: Kora.lime),
          ],
        ),
        color: Kora.ivory,
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authViewModelProvider).user;
    if (!favoritesLoaded || favoritesUser != user?.id) {
      Future.microtask(() => loadFavorites(user?.id));
    }
    final plan = ref.watch(currentPlanProvider);
    final metrics = ref.watch(weeklyMetricsProvider);
    final interventions = ref.watch(interventionsProvider);
    final profile = ref.watch(dashboardProfileProvider);
    return KoraPage(
      patternColor: const Color(0x0AD9FF59),
      maxWidth: 600,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 76,
          backgroundColor: Colors.white,
          indicatorColor: Kora.lime,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
              color: states.contains(WidgetState.selected)
                  ? Kora.forest
                  : Kora.sage.withValues(alpha: .55),
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? Kora.forest
                  : Kora.sage.withValues(alpha: .45),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() {
            tab = value;
            favoritesOnly = false;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.fitness_center),
              label: 'Rutinas',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart),
              label: 'Progreso',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          key: ValueKey(tab),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: tab == 0
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: KoraLogo(width: 56),
                        )
                      : heading(
                          tab == 1
                              ? (favoritesOnly ? 'Mis favoritos' : 'Rutinas')
                              : tab == 2
                              ? 'Tu Evolución'
                              : 'Perfil',
                        ),
                ),
                if (tab == 0) ...[
                  tool(
                    Icons.notifications_none,
                    'Notificaciones',
                    notifications,
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() => tab = 3),
                    child: avatar(user?.firstName ?? ''),
                  ),
                ],
                if (tab == 1)
                  tool(
                    Icons.search,
                    'Buscar rutinas',
                    () => setState(() {
                      searching = !searching;
                      if (!searching) query = '';
                    }),
                  ),
                if (tab == 2) tool(Icons.refresh, 'Actualizar datos', refresh),

              ],
            ),
            const SizedBox(height: 26),
            if (tab == 0) ...[
              heading(user == null ? 'Hola' : 'Hola, ${user.firstName}'),
              const SizedBox(height: 4),
              const Text(
                'Hoy también cuentas.',
                style: TextStyle(color: Kora.sage, fontSize: 12),
              ),
              const SizedBox(height: 26),
              section(
                plan,
                heroPlan,
                () => ref.invalidate(currentPlanProvider),
              ),
              const SizedBox(height: 26),
              section(
                metrics,
                compactProgress,
                () => ref.invalidate(weeklyMetricsProvider),
              ),
              const SizedBox(height: 22),
              if (plan.hasValue) todayRoutines(plan.value),
            ],
            if (tab == 1) ...[
              planLimitations(),
              section(
                plan,
                routines,
                () => ref.invalidate(currentPlanProvider),
              ),
            ],
            if (tab == 2) ...[
              section(
                metrics,
                (rows) => progress(rows, interventions.asData?.value ?? [], ref.watch(planAdaptationsProvider).asData?.value),
                () => ref.invalidate(weeklyMetricsProvider),
              ),
              const SizedBox(height: 24),
              section(
                interventions,
                adjustments,
                () => ref.invalidate(interventionsProvider),
              ),
              const SizedBox(height: 24),

            ],
            if (tab == 3)
              profileBody(
                user?.fullName ?? 'Mi cuenta',
                user?.email ?? '',
                profile,
              ),
          ],
        ),
      ),
    );
  }
}
