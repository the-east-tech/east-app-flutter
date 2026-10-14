import 'api_models.dart';

class FlowActivityEvent {
  final String id;
  final String actorUserId;
  final String actorName;
  final String actorEmployeeId;
  final String actorRole;
  final String module;
  final String action;
  final String entityType;
  final String subject;
  final String detail;
  final String? targetId;
  final String summary;
  final DateTime occurredAt;

  const FlowActivityEvent({
    required this.id,
    required this.actorUserId,
    required this.actorName,
    required this.actorEmployeeId,
    required this.actorRole,
    required this.module,
    required this.action,
    required this.entityType,
    required this.subject,
    required this.detail,
    required this.targetId,
    required this.summary,
    required this.occurredAt,
  });

  factory FlowActivityEvent.fromJson(Map<String, dynamic> json) {
    return FlowActivityEvent(
      id: json['eventId'] as String,
      actorUserId: json['actorUserId'] as String,
      actorName: json['actorName'] as String,
      actorEmployeeId: json['actorEmployeeId'] as String,
      actorRole: json['actorRole'] as String,
      module: json['module'] as String,
      action: json['action'] as String,
      entityType: json['entityType'] as String,
      subject: json['subject'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      targetId: json['targetId'] as String?,
      summary: json['summary'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String).toLocal(),
    );
  }
}

class FlowNotification {
  final String id;
  final FlowActivityEvent event;
  final DateTime? readAt;
  final DateTime createdAt;

  const FlowNotification({
    required this.id,
    required this.event,
    required this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory FlowNotification.fromJson(Map<String, dynamic> json) {
    return FlowNotification(
      id: json['notificationId'] as String,
      event: FlowActivityEvent.fromJson(
        json['event'] as Map<String, dynamic>,
      ),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String).toLocal(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}

FlowPage<FlowActivityEvent> activityEventPageFromJson(
  Map<String, dynamic> json,
) => FlowPage.fromJson(json, FlowActivityEvent.fromJson);

FlowPage<FlowNotification> notificationPageFromJson(
  Map<String, dynamic> json,
) => FlowPage.fromJson(json, FlowNotification.fromJson);
