import 'package:flutter_test/flutter_test.dart';
import 'package:fitsense_mobile/features/onboarding/data/profile_repository.dart';

/// Components of `CreateUserProfileResource` in Fitsense-Real/Backend, copied
/// from the record at #72 (`93549d5`, same as `generation` `2578719`).
const backendCreateProfileResource = [
  'birthDate', 'biologicalSex', 'heightCm', 'currentWeightKg', 'targetWeightKg', 'fitnessLevel', 'goalType',
  'goalText', 'trainingLocation', 'daysPerWeek', 'availableDays', 'sessionMinutes', 'equipmentCodes',
  'blockedExerciseIds', 'healthNotes', 'allowHighImpact', 'allowFloorExercises', 'allowKneelingExercises',
  'allowHangingExercises', 'allowOverheadExercises',
];

void main() {
  test('the app sends every field of the current CreateUserProfileResource and nothing else', () {
    expect(createProfileFields, backendCreateProfileResource.toSet());
    expect(updateProfileFields, backendCreateProfileResource.toSet()..remove('birthDate'));
  });

  test('V55 (allow_suspended_support) is not part of the REST contract, so the app does not send it', () {
    // V55 only adds columns, read internally behind fitsense.seguridad.permiso-apoyo-suspendido=false.
    // Neither CreateUserProfileResource, UpdateUserProfileResource nor UserProfileResource expose it.
    expect(createProfileFields.where((f) => f.toLowerCase().contains('suspend')), isEmpty);
  });
}
