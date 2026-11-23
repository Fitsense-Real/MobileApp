/// Push notification events sent by the backend through Firebase Cloud
/// Messaging. Contract: Fitsense-Real/Backend PR #82,
/// docs/FitSense/notificaciones_push/CONTRATO_PUSH_MOBILE.md (schemaVersion 1).
enum PushEventType {
  /// An asynchronous first-plan generation finished (COMPLETED).
  planGenerated,

  /// The weekly close published a plan with an adaptation applied.
  planAdapted,

  /// The weekly close published next week's plan without an adaptation.
  weeklyPlanReady,

  /// Security notice about the account (today only PASSWORD_CHANGED).
  accountNotice,

  /// Any other value: routed by [PushTarget], or to Inicio.
  unknown;

  static PushEventType parse(Object? value) => switch ('${value ?? ''}'.trim().toUpperCase()) {
    'PLAN_GENERATED' => planGenerated,
    'PLAN_ADAPTED' => planAdapted,
    'WEEKLY_PLAN_READY' => weeklyPlanReady,
    'ACCOUNT_NOTICE' => accountNotice,
    _ => unknown,
  };
}

/// `targetScreen` of the contract: the screen a tap opens.
enum PushTarget {
  weeklyPlan,
  accountSecurity,
  unknown;

  static PushTarget parse(Object? value) => switch ('${value ?? ''}'.trim().toUpperCase()) {
    'WEEKLY_PLAN' => weeklyPlan,
    'ACCOUNT_SECURITY' => accountSecurity,
    _ => unknown,
  };
}

/// A push message as the app understands it: the `data` part of the FCM
/// message (every value a string) plus the title and body of its
/// `notification` part. The message never carries plan contents or health
/// data: on a tap the app reloads what it needs from the backend with its JWT.
class PushEvent {
  const PushEvent({
    required this.type,
    this.target = PushTarget.unknown,
    this.eventId,
    this.schemaVersion,
    this.resourceType,
    this.resourceId,
    this.noticeCode,
    this.title,
    this.body,
  });

  factory PushEvent.fromMessage(Map<String, dynamic> data, {String? title, String? body}) {
    String? text(String key) {
      final value = data[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return PushEvent(
      type: PushEventType.parse(data['eventType']),
      target: PushTarget.parse(data['targetScreen']),
      eventId: text('eventId'),
      schemaVersion: text('schemaVersion'),
      resourceType: text('resourceType'),
      resourceId: int.tryParse(text('resourceId') ?? ''),
      noticeCode: text('noticeCode'),
      title: title,
      body: body,
    );
  }

  final PushEventType type;
  final PushTarget target;

  /// Unique per event (UUID): the app drops duplicates with it.
  final String? eventId;
  final String? schemaVersion;

  /// `PLAN` for plan events, with the plan id in [resourceId].
  final String? resourceType;
  final int? resourceId;

  /// ACCOUNT_NOTICE only, e.g. `PASSWORD_CHANGED`.
  final String? noticeCode;
  final String? title;
  final String? body;

  /// The plan on the device is out of date: reload it.
  bool get changesPlan => const {PushEventType.planGenerated, PushEventType.planAdapted, PushEventType.weeklyPlanReady}.contains(type);

  bool get isAccountNotice => type == PushEventType.accountNotice || (type == PushEventType.unknown && target == PushTarget.accountSecurity);

  /// Where a tap on the notification takes the user (targetScreen → route).
  String get route {
    // First plan: account setup decides between the result, Kapi's tour and
    // Inicio, so a user still onboarding lands where the flow expects.
    if (type == PushEventType.planGenerated) return '/account-setup';
    if (isAccountNotice) return '/dashboard?tab=3'; // Perfil: account and session
    if (changesPlan || target == PushTarget.weeklyPlan) return '/dashboard?tab=0'; // Inicio: the week's plan
    return '/dashboard';
  }

  /// Android channel of the contract (created by the app at start).
  String get channelId => isAccountNotice ? PushChannels.account : PushChannels.plans;

  /// Same grouping as the backend's collapseKey/tag: a newer notice replaces
  /// the previous one of its kind.
  String get tag => isAccountNotice ? 'aviso_cuenta' : 'plan_semana';

  /// Payload of the local notification shown while the app is open.
  String get payload => 'route:$route';
}

/// Notification channels named in the backend contract.
abstract final class PushChannels {
  static const plans = 'kora_planes';
  static const account = 'kora_cuenta';
}
