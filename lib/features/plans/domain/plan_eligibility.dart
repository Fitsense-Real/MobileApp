import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/study_config.dart';
import '../../authentication/domain/entities/user.dart';

/// Why the backend will not prepare a plan for this account, or null when it
/// can. Mirrors `StudyEnrollment.isActiveParticipant()` of the backend
/// (participant and not withdrawn) so the app never sends a person through the
/// profile and the 30 s generation screen towards a refusal that cannot change.
/// The backend stays the authority: this only avoids a dead end.
enum PlanIneligibility { notParticipant, withdrawn }

PlanIneligibility? planIneligibility(User? user, {bool plansForNonParticipants = StudyConfig.plansForNonParticipants}) {
  if (user == null || plansForNonParticipants) return null;
  if (!user.studyParticipant) return PlanIneligibility.notParticipant;
  if (user.withdrawnAt != null) return PlanIneligibility.withdrawn;
  return null;
}

/// Whether the backend prepares plans for people outside the study (M-01),
/// overridable in tests.
final plansForNonParticipantsProvider = Provider<bool>((ref) => StudyConfig.plansForNonParticipants);
