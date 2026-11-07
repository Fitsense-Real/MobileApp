import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_constants.dart';
import '../../../core/api/json.dart';
import '../../../core/providers/dio_provider.dart';
import '../../authentication/presentation/providers/auth_provider.dart';

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
}

final painExclusionRepositoryProvider = Provider((ref) => PainExclusionRepository(ref.watch(dioProvider)));

final painExclusionsProvider = FutureProvider.autoDispose<List<Json>>((ref) {
  ref.watch(authViewModelProvider.select((s) => s.user?.id));
  return ref.watch(painExclusionRepositoryProvider).list();
});
