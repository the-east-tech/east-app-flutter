import 'api_models.dart';

class EastAppActivityEvent {
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

  const EastAppActivityEvent({
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

  factory EastAppActivityEvent.fromJson(Map<String, dynamic> json) {
    return EastAppActivityEvent(
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

class EastAppNotification {
  final String id;
  final EastAppActivityEvent event;
  final DateTime? readAt;
  final DateTime createdAt;

  const EastAppNotification({
    required this.id,
    required this.event,
    required this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  factory EastAppNotification.fromJson(Map<String, dynamic> json) {
    return EastAppNotification(
      id: json['notificationId'] as String,
      event: EastAppActivityEvent.fromJson(
        json['event'] as Map<String, dynamic>,
      ),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String).toLocal(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }
}

EastAppPage<EastAppActivityEvent> activityEventPageFromJson(
  Map<String, dynamic> json,
) => EastAppPage.fromJson(json, EastAppActivityEvent.fromJson);

EastAppPage<EastAppNotification> notificationPageFromJson(
  Map<String, dynamic> json,
) => EastAppPage.fromJson(json, EastAppNotification.fromJson);
