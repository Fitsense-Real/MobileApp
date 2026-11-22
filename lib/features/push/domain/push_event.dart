/// Push notification events sent by the backend through Firebase Cloud
/// Messaging (contract proposed in docs/push/CONTRATO_PUSH_BACKEND.md; the
/// backend does not send them yet).
enum PushEventType {
  /// The first plan (or a regenerated one) is ready.
  planGenerated,

  /// The weekly cycle adjusted the plan.
  planAdapted,

  /// The plan of the new week is available.
  weeklyPlanReady,

  /// A notice about the account (consents, deletion, study).
  accountNotice,

  /// Any other value: shown as sent, opens Inicio.
  unknown;

  static PushEventType parse(Object? value) => switch ('$value'.trim().toUpperCase()) {
    'PLAN_GENERATED' => planGenerated,
    'PLAN_ADAPTED' => planAdapted,
    'WEEKLY_PLAN_READY' => weeklyPlanReady,
    'ACCOUNT_NOTICE' => accountNotice,
    _ => unknown,
  };
}

/// A push message as the app understands it: the `data` part of the FCM
/// message plus the title and body of its `notification` part, if any.
class PushEvent {
  const PushEvent({required this.type, this.planId, this.title, this.body});

  factory PushEvent.fromMessage(Map<String, dynamic> data, {String? title, String? body}) => PushEvent(
    type: PushEventType.parse(data['type'] ?? data['event']),
    planId: int.tryParse('${data['planId'] ?? ''}'),
    title: title ?? data['title'] as String?,
    body: body ?? data['body'] as String?,
  );

  final PushEventType type;
  final int? planId;
  final String? title;
  final String? body;

  /// The plan on the device is out of date: reload it.
  bool get changesPlan => const {PushEventType.planGenerated, PushEventType.planAdapted, PushEventType.weeklyPlanReady}.contains(type);

  /// Where a tap on the notification takes the user.
  String get route => switch (type) {
    // Account setup decides between the first-plan result, the tour and Inicio.
    PushEventType.planGenerated => '/account-setup',
    // Progreso explains the adjustments of the week.
    PushEventType.planAdapted => '/dashboard?tab=2',
    PushEventType.weeklyPlanReady => '/dashboard?tab=0',
    PushEventType.accountNotice => '/dashboard?tab=3',
    PushEventType.unknown => '/dashboard',
  };

  /// Payload of the local notification shown while the app is open.
  String get payload => 'route:$route';
}
