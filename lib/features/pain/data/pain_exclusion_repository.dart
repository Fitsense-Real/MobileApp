import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../domain/pain_safety.dart';

const painExclusionStatusLabels = {'ACTIVA': 'Excluido', 'REACTIVADA': 'Reactivado'};
const painExclusionReasonLabels = {
  'DOLOR_IDENTIFICADO': 'Dolor en este ejercicio',
  'DOLOR_SESION_SIN_IDENTIFICAR': 'Dolor en la sesión',
};

/// Exercises excluded for pain (PainExclusionController, V43).
class PainExclusionRepository {
  PainExclusionRepository(this.dio);
  final Dio dio;

  /// `PainExclusionResource` list, active and reactivated.
  Future<List<Json>> list() async => jsonRows((await dio.get(ApiConstants.painExclusions)).data);

  /// Asks to consider the exercise again. It does not add it back: it becomes
  /// a candidate subject to every rule, and the backend refuses it (422) when
  /// it conflicts with a current safety restriction. Returns
  /// `{exerciseId, exclusionesReactivadas, reactivadaEn, candidatoHoy, nota}`.
  Future<Json> reactivate(Object exerciseId, {String? comment}) async => jsonMap((await dio.post(
    ApiConstants.reactivatePainExclusion(exerciseId),
    data: {'confirmNoPain': true, if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim()},
  )).data);

  /// O20: what is not prescribed today because of pain, one entry per
  /// exercise, with its origin (`GET …/pain-exclusions/effective`).
  Future<List<EffectiveExclusion>> effective() async =>
      [for (final row in jsonRows((await dio.get(ApiConstants.effectivePainExclusions)).data)) EffectiveExclusion.fromJson(row)];

  /// O20: sessions with unidentified pain waiting for an answer.
  Future<List<PainConfirmationRequest>> confirmationRequests() async =>
      [for (final row in jsonRows((await dio.get(ApiConstants.painConfirmationRequests)).data)) PainConfirmationRequest.fromJson(row)];

  /// O20: [exerciseId] was the one that hurt in [plannedWorkoutId]; the
  /// [unrelated] ones of that session had nothing to do with it. Only those
  /// are lifted, each with the backend's safety check; the rest stay
  /// excluded. 422 when one is not of that session or is [exerciseId].
  Future<IdentificationResult> identify(int exerciseId, {int? plannedWorkoutId, Set<int> unrelated = const {}}) async =>
      IdentificationResult.fromJson(jsonMap((await dio.post(ApiConstants.identifyPainExclusion(exerciseId), data: {
        'confirmPain': true,
        'plannedWorkoutId': ?plannedWorkoutId,
        if (unrelated.isNotEmpty) 'unrelatedExerciseIds': (unrelated.toList()..sort()),
      })).data));
}

final painExclusionRepositoryProvider = Provider((ref) => PainExclusionRepository(ref.watch(dioProvider)));

final painExclusionsProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(painExclusionRepositoryProvider).list();
});

final effectivePainExclusionsProvider = FutureProvider.autoDispose<List<EffectiveExclusion>>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(painExclusionRepositoryProvider).effective();
});

final painConfirmationRequestsProvider = FutureProvider.autoDispose<List<PainConfirmationRequest>>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(painExclusionRepositoryProvider).confirmationRequests();
});
