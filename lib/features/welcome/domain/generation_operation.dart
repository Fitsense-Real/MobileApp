import '../../../core/api/json.dart';

/// `PlanGenerationOperationResource` of the backend (V58).
enum GenerationStatus { pending, processing, completed, failed, noFactible, unknown }

GenerationStatus generationStatusOf(Object? value) => switch ('$value') {
  'PENDING' => GenerationStatus.pending,
  'PROCESSING' => GenerationStatus.processing,
  'COMPLETED' => GenerationStatus.completed,
  'FAILED' => GenerationStatus.failed,
  'NO_FACTIBLE' => GenerationStatus.noFactible,
  _ => GenerationStatus.unknown,
};

class GenerationOperation {
  const GenerationOperation({
    required this.id,
    required this.status,
    this.planId,
    this.weekStartDate,
    this.reasonCode,
    this.message,
    this.retryable = false,
    this.pollAfterSeconds,
  });

  factory GenerationOperation.fromJson(Json json) => GenerationOperation(
    id: '${json['operationId']}',
    status: generationStatusOf(json['status']),
    planId: (json['planId'] as num?)?.toInt(),
    weekStartDate: json['weekStartDate'] as String?,
    reasonCode: json['reasonCode'] as String?,
    message: json['message'] as String?,
    retryable: json['retryable'] == true,
    pollAfterSeconds: (json['pollAfterSeconds'] as num?)?.toInt(),
  );

  final String id;
  final GenerationStatus status;
  final int? planId;
  final String? weekStartDate;
  final String? reasonCode;
  final String? message;
  final bool retryable;
  final int? pollAfterSeconds;

  bool get isTerminal =>
      status == GenerationStatus.completed || status == GenerationStatus.failed || status == GenerationStatus.noFactible;

  @override
  String toString() => 'GenerationOperation($id, $status, plan: $planId)';
}
