enum DailyTaskStatus {
  pending('PENDING'),
  submitted('SUBMITTED'),
  done('DONE');

  final String apiValue;

  const DailyTaskStatus(this.apiValue);

  static DailyTaskStatus fromApi(Object? value) {
    return DailyTaskStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => DailyTaskStatus.pending,
    );
  }
}

class DailyTaskOverview {
  final int total;
  final int pending;
  final int submitted;
  final int done;

  const DailyTaskOverview({
    required this.total,
    required this.pending,
    required this.submitted,
    required this.done,
  });

  static const empty = DailyTaskOverview(
    total: 0,
    pending: 0,
    submitted: 0,
    done: 0,
  );

  double get completionRate => total == 0 ? 0.0 : done / total;

  factory DailyTaskOverview.fromJson(Map<String, dynamic> json) {
    return DailyTaskOverview(
      total: (json['total'] as num? ?? 0).toInt(),
      pending: (json['pending'] as num? ?? 0).toInt(),
      submitted: (json['submitted'] as num? ?? 0).toInt(),
      done: (json['done'] as num? ?? 0).toInt(),
    );
  }
}

class DailyTaskPerson {
  final String userId;
  final String fullName;
  final String employeeId;
  final String role;

  const DailyTaskPerson({
    required this.userId,
    required this.fullName,
    required this.employeeId,
    required this.role,
  });

  factory DailyTaskPerson.fromJson(Map<String, dynamic> json) {
    return DailyTaskPerson(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      employeeId: json['employeeId'] as String,
      role: json['role'] as String,
    );
  }
}

class DailyTaskTemplate {
  final String id;
  final String tagId;
  final String tagName;
  final String title;
  final String instruction;
  final int requiredPhotoCount;
  final List<String> checklistItems;
  final bool active;
  final DailyTaskPerson createdBy;
  final DailyTaskPerson updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DailyTaskAuditEntry> activity;

  const DailyTaskTemplate({
    required this.id,
    required this.tagId,
    required this.tagName,
    required this.title,
    required this.instruction,
    required this.requiredPhotoCount,
    required this.checklistItems,
    required this.active,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.activity,
  });

  factory DailyTaskTemplate.fromJson(Map<String, dynamic> json) {
    return DailyTaskTemplate(
      id: json['id'] as String,
      tagId: json['tagId'] as String,
      tagName: json['tagName'] as String,
      title: json['title'] as String,
      instruction: json['instruction'] as String? ?? '',
      requiredPhotoCount: (json['requiredPhotoCount'] as num).toInt(),
      checklistItems: (json['checklistItems'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
      active: json['active'] as bool,
      createdBy: DailyTaskPerson.fromJson(
        json['createdBy'] as Map<String, dynamic>,
      ),
      updatedBy: DailyTaskPerson.fromJson(
        json['updatedBy'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      activity: (json['activity'] as List<dynamic>? ?? const [])
          .map(
            (item) => DailyTaskAuditEntry.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class DailyTaskChecklistItem {
  final String id;
  final int position;
  final String description;
  final bool completed;
  final DailyTaskPerson? completedBy;
  final DateTime? completedAt;

  const DailyTaskChecklistItem({
    required this.id,
    required this.position,
    required this.description,
    required this.completed,
    required this.completedBy,
    required this.completedAt,
  });

  factory DailyTaskChecklistItem.fromJson(Map<String, dynamic> json) {
    return DailyTaskChecklistItem(
      id: json['id'] as String,
      position: (json['position'] as num).toInt(),
      description: json['description'] as String,
      completed: json['completed'] as bool,
      completedBy: _person(json['completedBy']),
      completedAt: _dateTime(json['completedAt']),
    );
  }
}

class DailyTaskPhoto {
  final String id;
  final String photoStorageKey;
  final DailyTaskPerson submittedBy;
  final DateTime submittedAt;

  const DailyTaskPhoto({
    required this.id,
    required this.photoStorageKey,
    required this.submittedBy,
    required this.submittedAt,
  });

  factory DailyTaskPhoto.fromJson(Map<String, dynamic> json) {
    return DailyTaskPhoto(
      id: json['id'] as String,
      photoStorageKey: json['photoStorageKey'] as String,
      submittedBy: DailyTaskPerson.fromJson(
        json['submittedBy'] as Map<String, dynamic>,
      ),
      submittedAt: DateTime.parse(json['submittedAt'] as String),
    );
  }
}

class DailyTaskAuditEntry {
  final String id;
  final String action;
  final String details;
  final DailyTaskPerson actor;
  final DateTime occurredAt;

  const DailyTaskAuditEntry({
    required this.id,
    required this.action,
    required this.details,
    required this.actor,
    required this.occurredAt,
  });

  factory DailyTaskAuditEntry.fromJson(Map<String, dynamic> json) {
    return DailyTaskAuditEntry(
      id: json['id'] as String,
      action: json['action'] as String,
      details: json['details'] as String? ?? '',
      actor: DailyTaskPerson.fromJson(
        json['actor'] as Map<String, dynamic>,
      ),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
    );
  }
}

class DailyTaskRecord {
  final String id;
  final String templateId;
  final String tagId;
  final String tagName;
  final DateTime taskDate;
  final String title;
  final String instruction;
  final int requiredPhotoCount;
  final int photoCount;
  final DailyTaskStatus status;
  final List<DailyTaskChecklistItem> checklistItems;
  final List<DailyTaskPhoto> photos;
  final bool requirementsMet;
  final DailyTaskPerson? submittedBy;
  final DateTime? submittedAt;
  final int? rating;
  final String? ratingComment;
  final DailyTaskPerson? ratedBy;
  final DateTime? ratedAt;
  final bool canContribute;
  final bool canSubmit;
  final bool canRate;
  final List<DailyTaskAuditEntry> activity;

  const DailyTaskRecord({
    required this.id,
    required this.templateId,
    required this.tagId,
    required this.tagName,
    required this.taskDate,
    required this.title,
    required this.instruction,
    required this.requiredPhotoCount,
    required this.photoCount,
    required this.status,
    required this.checklistItems,
    required this.photos,
    required this.requirementsMet,
    required this.submittedBy,
    required this.submittedAt,
    required this.rating,
    required this.ratingComment,
    required this.ratedBy,
    required this.ratedAt,
    required this.canContribute,
    required this.canSubmit,
    required this.canRate,
    required this.activity,
  });

  factory DailyTaskRecord.fromJson(Map<String, dynamic> json) {
    return DailyTaskRecord(
      id: json['id'] as String,
      templateId: json['templateId'] as String,
      tagId: json['tagId'] as String,
      tagName: json['tagName'] as String,
      taskDate: DateTime.parse(json['taskDate'] as String),
      title: json['title'] as String,
      instruction: json['instruction'] as String? ?? '',
      requiredPhotoCount: (json['requiredPhotoCount'] as num).toInt(),
      photoCount: (json['photoCount'] as num).toInt(),
      status: DailyTaskStatus.fromApi(json['status']),
      checklistItems:
          (json['checklistItems'] as List<dynamic>? ?? const [])
              .map(
                (item) => DailyTaskChecklistItem.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map(
            (item) => DailyTaskPhoto.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      requirementsMet: json['requirementsMet'] as bool,
      submittedBy: _person(json['submittedBy']),
      submittedAt: _dateTime(json['submittedAt']),
      rating: (json['rating'] as num?)?.toInt(),
      ratingComment: json['ratingComment'] as String?,
      ratedBy: _person(json['ratedBy']),
      ratedAt: _dateTime(json['ratedAt']),
      canContribute: json['canContribute'] as bool,
      canSubmit: json['canSubmit'] as bool,
      canRate: json['canRate'] as bool,
      activity: (json['activity'] as List<dynamic>? ?? const [])
          .map(
            (item) => DailyTaskAuditEntry.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class DailyTaskList {
  final DateTime taskDate;
  final DateTime dateFrom;
  final DateTime dateTo;
  final DailyTaskOverview overview;
  final List<DailyTaskRecord> records;

  const DailyTaskList({
    required this.taskDate,
    required this.dateFrom,
    required this.dateTo,
    required this.overview,
    required this.records,
  });

  factory DailyTaskList.fromJson(Map<String, dynamic> json) {
    final fallbackDate = json['taskDate'] as String;
    return DailyTaskList(
      taskDate: DateTime.parse(fallbackDate),
      dateFrom: DateTime.parse(json['dateFrom'] as String? ?? fallbackDate),
      dateTo: DateTime.parse(json['dateTo'] as String? ?? fallbackDate),
      overview: DailyTaskOverview.fromJson(
        json['overview'] as Map<String, dynamic>,
      ),
      records: (json['records'] as List<dynamic>? ?? const [])
          .map(
            (item) => DailyTaskRecord.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

DailyTaskPerson? _person(Object? value) {
  return value is Map<String, dynamic>
      ? DailyTaskPerson.fromJson(value)
      : null;
}

DateTime? _dateTime(Object? value) {
  return value is String ? DateTime.parse(value) : null;
}
