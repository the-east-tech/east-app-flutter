enum TaskStatus {
  pending('PENDING'),
  submitted('SUBMITTED'),
  done('DONE');

  final String apiValue;

  const TaskStatus(this.apiValue);

  static TaskStatus fromApi(Object? value) {
    return TaskStatus.values.firstWhere(
      (status) => status.apiValue == value,
      orElse: () => TaskStatus.pending,
    );
  }
}

enum TaskScheduleType {
  adHoc('AD_HOC', 'Ad hoc'),
  daily('DAILY', 'Daily'),
  weekly('WEEKLY', 'Weekly'),
  biweekly('BIWEEKLY', 'Biweekly'),
  monthly('MONTHLY', 'Monthly');

  final String apiValue;
  final String label;

  const TaskScheduleType(this.apiValue, this.label);

  static TaskScheduleType fromApi(Object? value) {
    return TaskScheduleType.values.firstWhere(
      (type) => type.apiValue == value,
      orElse: () => TaskScheduleType.daily,
    );
  }
}

class TaskOverview {
  final int total;
  final int pending;
  final int submitted;
  final int done;

  const TaskOverview({
    required this.total,
    required this.pending,
    required this.submitted,
    required this.done,
  });

  static const empty = TaskOverview(
    total: 0,
    pending: 0,
    submitted: 0,
    done: 0,
  );

  double get completionRate => total == 0 ? 0.0 : done / total;

  factory TaskOverview.fromJson(Map<String, dynamic> json) {
    return TaskOverview(
      total: (json['total'] as num? ?? 0).toInt(),
      pending: (json['pending'] as num? ?? 0).toInt(),
      submitted: (json['submitted'] as num? ?? 0).toInt(),
      done: (json['done'] as num? ?? 0).toInt(),
    );
  }
}

class TaskPerson {
  final String userId;
  final String fullName;
  final String employeeId;
  final String role;

  const TaskPerson({
    required this.userId,
    required this.fullName,
    required this.employeeId,
    required this.role,
  });

  factory TaskPerson.fromJson(Map<String, dynamic> json) {
    return TaskPerson(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      employeeId: json['employeeId'] as String,
      role: json['role'] as String,
    );
  }
}

class TaskTemplate {
  final String id;
  final String tagId;
  final String tagName;
  final String title;
  final String instruction;
  final int requiredPhotoCount;
  final TaskScheduleType scheduleType;
  final DateTime firstTaskDate;
  final DateTime? endDate;
  final List<String> checklistItems;
  final bool active;
  final TaskPerson createdBy;
  final TaskPerson updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TaskAuditEntry> activity;

  const TaskTemplate({
    required this.id,
    required this.tagId,
    required this.tagName,
    required this.title,
    required this.instruction,
    required this.requiredPhotoCount,
    required this.scheduleType,
    required this.firstTaskDate,
    required this.endDate,
    required this.checklistItems,
    required this.active,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.activity,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'] as String,
      tagId: json['tagId'] as String,
      tagName: json['tagName'] as String,
      title: json['title'] as String,
      instruction: json['instruction'] as String? ?? '',
      requiredPhotoCount: (json['requiredPhotoCount'] as num).toInt(),
      scheduleType: TaskScheduleType.fromApi(json['scheduleType']),
      firstTaskDate: DateTime.parse(json['firstTaskDate'] as String),
      endDate: _dateTime(json['endDate']),
      checklistItems: (json['checklistItems'] as List<dynamic>? ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
      active: json['active'] as bool,
      createdBy: TaskPerson.fromJson(
        json['createdBy'] as Map<String, dynamic>,
      ),
      updatedBy: TaskPerson.fromJson(
        json['updatedBy'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      activity: (json['activity'] as List<dynamic>? ?? const [])
          .map(
            (item) => TaskAuditEntry.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class TaskChecklistItem {
  final String id;
  final int position;
  final String description;
  final bool completed;
  final TaskPerson? completedBy;
  final DateTime? completedAt;

  const TaskChecklistItem({
    required this.id,
    required this.position,
    required this.description,
    required this.completed,
    required this.completedBy,
    required this.completedAt,
  });

  factory TaskChecklistItem.fromJson(Map<String, dynamic> json) {
    return TaskChecklistItem(
      id: json['id'] as String,
      position: (json['position'] as num).toInt(),
      description: json['description'] as String,
      completed: json['completed'] as bool,
      completedBy: _person(json['completedBy']),
      completedAt: _dateTime(json['completedAt']),
    );
  }
}

class TaskPhoto {
  final String id;
  final String photoStorageKey;
  final TaskPerson submittedBy;
  final DateTime submittedAt;

  const TaskPhoto({
    required this.id,
    required this.photoStorageKey,
    required this.submittedBy,
    required this.submittedAt,
  });

  factory TaskPhoto.fromJson(Map<String, dynamic> json) {
    return TaskPhoto(
      id: json['id'] as String,
      photoStorageKey: json['photoStorageKey'] as String,
      submittedBy: TaskPerson.fromJson(
        json['submittedBy'] as Map<String, dynamic>,
      ),
      submittedAt: DateTime.parse(json['submittedAt'] as String),
    );
  }
}

class TaskAuditEntry {
  final String id;
  final String action;
  final String details;
  final TaskPerson actor;
  final DateTime occurredAt;

  const TaskAuditEntry({
    required this.id,
    required this.action,
    required this.details,
    required this.actor,
    required this.occurredAt,
  });

  factory TaskAuditEntry.fromJson(Map<String, dynamic> json) {
    return TaskAuditEntry(
      id: json['id'] as String,
      action: json['action'] as String,
      details: json['details'] as String? ?? '',
      actor: TaskPerson.fromJson(
        json['actor'] as Map<String, dynamic>,
      ),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
    );
  }
}

class TaskRecord {
  final String id;
  final String templateId;
  final String tagId;
  final String tagName;
  final DateTime taskDate;
  final String title;
  final String instruction;
  final int requiredPhotoCount;
  final TaskScheduleType scheduleType;
  final int photoCount;
  final TaskStatus status;
  final List<TaskChecklistItem> checklistItems;
  final List<TaskPhoto> photos;
  final bool requirementsMet;
  final TaskPerson? submittedBy;
  final DateTime? submittedAt;
  final int? rating;
  final String? ratingComment;
  final TaskPerson? ratedBy;
  final DateTime? ratedAt;
  final bool canContribute;
  final bool canSubmit;
  final bool canRate;
  final List<TaskAuditEntry> activity;

  const TaskRecord({
    required this.id,
    required this.templateId,
    required this.tagId,
    required this.tagName,
    required this.taskDate,
    required this.title,
    required this.instruction,
    required this.requiredPhotoCount,
    required this.scheduleType,
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

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    return TaskRecord(
      id: json['id'] as String,
      templateId: json['templateId'] as String,
      tagId: json['tagId'] as String,
      tagName: json['tagName'] as String,
      taskDate: DateTime.parse(json['taskDate'] as String),
      title: json['title'] as String,
      instruction: json['instruction'] as String? ?? '',
      requiredPhotoCount: (json['requiredPhotoCount'] as num).toInt(),
      scheduleType: TaskScheduleType.fromApi(json['scheduleType']),
      photoCount: (json['photoCount'] as num).toInt(),
      status: TaskStatus.fromApi(json['status']),
      checklistItems:
          (json['checklistItems'] as List<dynamic>? ?? const [])
              .map(
                (item) => TaskChecklistItem.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map(
            (item) => TaskPhoto.fromJson(item as Map<String, dynamic>),
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
            (item) => TaskAuditEntry.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class TaskList {
  final DateTime taskDate;
  final DateTime dateFrom;
  final DateTime dateTo;
  final TaskOverview overview;
  final List<TaskRecord> records;

  const TaskList({
    required this.taskDate,
    required this.dateFrom,
    required this.dateTo,
    required this.overview,
    required this.records,
  });

  factory TaskList.fromJson(Map<String, dynamic> json) {
    final fallbackDate = json['taskDate'] as String;
    return TaskList(
      taskDate: DateTime.parse(fallbackDate),
      dateFrom: DateTime.parse(json['dateFrom'] as String? ?? fallbackDate),
      dateTo: DateTime.parse(json['dateTo'] as String? ?? fallbackDate),
      overview: TaskOverview.fromJson(
        json['overview'] as Map<String, dynamic>,
      ),
      records: (json['records'] as List<dynamic>? ?? const [])
          .map(
            (item) => TaskRecord.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}

TaskPerson? _person(Object? value) {
  return value is Map<String, dynamic>
      ? TaskPerson.fromJson(value)
      : null;
}

DateTime? _dateTime(Object? value) {
  return value is String ? DateTime.parse(value) : null;
}
