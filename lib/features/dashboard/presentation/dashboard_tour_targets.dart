import 'package:flutter/widgets.dart';

/// Real dashboard elements the welcome tour highlights. The dashboard
/// attaches these keys only when it runs inside the tour.
class DashboardTourTargets {
  final planCard = GlobalKey(debugLabel: 'tour-plan-card');
  final navRoutines = GlobalKey(debugLabel: 'tour-nav-routines');
  final navProgress = GlobalKey(debugLabel: 'tour-nav-progress');
  final navProfile = GlobalKey(debugLabel: 'tour-nav-profile');
  final routines = GlobalKey(debugLabel: 'tour-routines');
  final progress = GlobalKey(debugLabel: 'tour-progress');
  final reminders = GlobalKey(debugLabel: 'tour-reminders');
  final tourReplay = GlobalKey(debugLabel: 'tour-replay');
}
