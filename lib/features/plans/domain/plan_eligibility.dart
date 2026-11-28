import '../../authentication/domain/entities/user.dart';

/// Why the backend will not prepare a plan for this account, or null when it
/// can. Mirrors `User.isEligibleForPlanGeneration()` of the backend with the
/// study policy A (`fitsense.study.plans-require-participation=true`, the
/// decided one): participant and not withdrawn. The app never sends a person
/// through the profile and the generation screen towards a refusal that cannot
/// change; the backend stays the authority.
enum PlanIneligibility { notParticipant, withdrawn }

PlanIneligibility? planIneligibility(User? user) {
  if (user == null) return null;
  if (!user.studyParticipant) return PlanIneligibility.notParticipant;
  if (user.withdrawnAt != null) return PlanIneligibility.withdrawn;
  return null;
}
