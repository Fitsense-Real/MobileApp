import 'package:flutter/widgets.dart';
import '../../../../shared/widgets/mascot/kora_mascot.dart';
import '../../../dashboard/presentation/dashboard_tour_targets.dart';

/// One step of the welcome tour over the real dashboard.
class TourStep {
  const TourStep({
    required this.tab,
    required this.mood,
    required this.title,
    required this.message,
    this.target,
    this.goesToTab,
    this.nextLabel,
    this.showsResultChoices = false,
    this.replayMessage,
  });

  /// Dashboard tab shown during the step.
  final int tab;

  /// Element highlighted; null for a message without highlight.
  final GlobalKey Function(DashboardTourTargets)? target;

  /// Navigation step: tapping the highlighted tab (or "Siguiente") opens it.
  final int? goesToTab;

  final MascotMood mood;
  final String title;
  final String message;

  /// Text for the replay from Perfil, when the first plan already exists and
  /// [message] would describe a false state; null when [message] fits both.
  final String? replayMessage;
  final String? nextLabel;

  /// Small demonstration of the three real result options; no workout is
  /// created or shown.
  final bool showsResultChoices;

  bool get interactive => goesToTab != null;
}

/// Ordered so a new user learns: plan → workouts → honest recording →
/// progress → reminders, and where to see this again. Texts describe only
/// features that exist; Kapi never says the plan is ready.
const welcomeTourSteps = <TourStep>[
  TourStep(
    tab: 0,
    mood: MascotMood.welcome,
    title: '¡Hola! Soy Kapi',
    message: 'Mientras Kora prepara tu primera rutina, te muestro lo esencial de la app. Son solo unos pasos.',
    replayMessage: 'Te muestro de nuevo lo esencial de Kora. Son solo unos pasos.',
    nextLabel: 'Empezar',
  ),
  TourStep(
    tab: 0,
    target: _planCard,
    mood: MascotMood.explain,
    title: 'Tu plan de la semana',
    message: 'Aquí verás tu plan semanal y los días que te quedan. Tu primera rutina aparecerá aquí cuando esté lista.',
    replayMessage: 'Aquí verás tu plan semanal y los días que te quedan.',
  ),
  TourStep(
    tab: 0,
    target: _navRoutines,
    goesToTab: 1,
    mood: MascotMood.explain,
    title: 'Tus entrenamientos',
    message: 'Toca «Rutinas» para ver dónde estarán tus entrenamientos.',
    nextLabel: 'Ir a Rutinas',
  ),
  TourStep(
    tab: 1,
    target: _routines,
    mood: MascotMood.explain,
    title: 'Rutinas',
    message: 'Cada entrenamiento muestra su día y su duración. Al abrirlo puedes empezarlo en vivo, con cronómetro y descansos, o registrarlo si ya lo hiciste.',
  ),
  TourStep(
    tab: 1,
    mood: MascotMood.motivate,
    title: 'Registra lo que realmente hiciste',
    message: 'En cada ejercicio eliges una de estas opciones. Con tus registros, Kora podrá ajustar tu plan cuando corresponda.',
    showsResultChoices: true,
  ),
  TourStep(
    tab: 1,
    target: _navProgress,
    goesToTab: 2,
    mood: MascotMood.explain,
    title: 'Tu progreso',
    message: 'Toca «Progreso».',
    nextLabel: 'Ir a Progreso',
  ),
  TourStep(
    tab: 2,
    target: _progress,
    mood: MascotMood.explain,
    title: 'Semana a semana',
    message: 'Aquí verás qué parte de tu plan cumpliste cada semana y los ajustes que haga Kora.',
  ),
  TourStep(
    tab: 2,
    target: _navProfile,
    goesToTab: 3,
    mood: MascotMood.explain,
    title: 'Tu perfil',
    message: 'Toca «Perfil».',
    nextLabel: 'Ir a Perfil',
  ),
  TourStep(
    tab: 3,
    target: _reminders,
    mood: MascotMood.explain,
    title: 'Recordatorios',
    message: 'Activa avisos para los días que tienes entrenamiento.',
  ),
  TourStep(
    tab: 3,
    target: _tourReplay,
    mood: MascotMood.motivate,
    title: '¡Ya conoces Kora!',
    message: 'Cuando quieras, desde aquí puedes volver a ver este recorrido.',
    nextLabel: 'Terminar',
  ),
];

GlobalKey _planCard(DashboardTourTargets t) => t.planCard;
GlobalKey _navRoutines(DashboardTourTargets t) => t.navRoutines;
GlobalKey _routines(DashboardTourTargets t) => t.routines;
GlobalKey _navProgress(DashboardTourTargets t) => t.navProgress;
GlobalKey _progress(DashboardTourTargets t) => t.progress;
GlobalKey _navProfile(DashboardTourTargets t) => t.navProfile;
GlobalKey _reminders(DashboardTourTargets t) => t.reminders;
GlobalKey _tourReplay(DashboardTourTargets t) => t.tourReplay;
