import 'api_models.dart';

class FlowAttendanceEvent {
  final String id;
  final String eventType;
  final DateTime occurredAt;
  final DateTime deviceCapturedAt;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String capturedAddress;
  final String workLocationName;
  final String workLocationAddress;
  final double workLocationLatitude;
  final double workLocationLongitude;
  final double distanceMeters;
  final String qrCodeId;
  final String devicePlatform;
  final String appVersion;
  final String validationMethod;

  const FlowAttendanceEvent({
    required this.id,
    required this.eventType,
    required this.occurredAt,
    required this.deviceCapturedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAddress,
    required this.workLocationName,
    required this.workLocationAddress,
    required this.workLocationLatitude,
    required this.workLocationLongitude,
    required this.distanceMeters,
    required this.qrCodeId,
    required this.devicePlatform,
    required this.appVersion,
    required this.validationMethod,
  });

  factory FlowAttendanceEvent.fromJson(Map<String, dynamic> json) {
    return FlowAttendanceEvent(
      id: json['id'] as String,
      eventType: json['eventType'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      deviceCapturedAt: DateTime.parse(json['deviceCapturedAt'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
      capturedAddress: json['capturedAddress'] as String,
      workLocationName: json['workLocationName'] as String,
      workLocationAddress: json['workLocationAddress'] as String,
      workLocationLatitude: (json['workLocationLatitude'] as num).toDouble(),
      workLocationLongitude: (json['workLocationLongitude'] as num).toDouble(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      qrCodeId: json['qrCodeId'] as String,
      devicePlatform: json['devicePlatform'] as String,
      appVersion: json['appVersion'] as String,
      validationMethod: json['validationMethod'] as String,
    );
  }
}

class FlowAttendanceToday {
  final DateTime date;
  final String status;
  final FlowAttendanceEvent? clockIn;
  final FlowAttendanceEvent? clockOut;
  final int totalWorkingMinutes;

  const FlowAttendanceToday({
    required this.date,
    required this.status,
    required this.clockIn,
    required this.clockOut,
    required this.totalWorkingMinutes,
  });

  factory FlowAttendanceToday.fromJson(Map<String, dynamic> json) {
    final clockInJson = json['clockIn'];
    final clockOutJson = json['clockOut'];
    return FlowAttendanceToday(
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      clockIn: clockInJson is Map<String, dynamic>
          ? FlowAttendanceEvent.fromJson(clockInJson)
          : null,
      clockOut: clockOutJson is Map<String, dynamic>
          ? FlowAttendanceEvent.fromJson(clockOutJson)
          : null,
      totalWorkingMinutes: (json['totalWorkingMinutes'] as num).toInt(),
    );
  }

  bool get hasClockedIn => clockIn != null;
  bool get hasClockedOut => clockOut != null;
}

enum AttendanceAuditPeriod {
  day('DAY', 'Daily'),
  week('WEEK', 'Weekly'),
  month('MONTH', 'Monthly'),
  year('YEAR', 'Yearly');

  final String apiValue;
  final String label;

  const AttendanceAuditPeriod(this.apiValue, this.label);
}

class FlowAttendanceAuditSummary {
  final int people;
  final int peopleWithAttendance;
  final int presentDays;
  final int completedDays;
  final int missingCheckOutDays;
  final double completionPercent;

  const FlowAttendanceAuditSummary({
    required this.people,
    required this.peopleWithAttendance,
    required this.presentDays,
    required this.completedDays,
    required this.missingCheckOutDays,
    required this.completionPercent,
  });

  factory FlowAttendanceAuditSummary.fromJson(Map<String, dynamic> json) {
    return FlowAttendanceAuditSummary(
      people: (json['people'] as num).toInt(),
      peopleWithAttendance: (json['peopleWithAttendance'] as num).toInt(),
      presentDays: (json['presentDays'] as num).toInt(),
      completedDays: (json['completedDays'] as num).toInt(),
      missingCheckOutDays: (json['missingCheckOutDays'] as num).toInt(),
      completionPercent: (json['completionPercent'] as num).toDouble(),
    );
  }
}

class FlowAttendanceUserAudit {
  final String userId;
  final String employeeId;
  final String fullName;
  final String roleName;
  final bool active;
  final String status;
  final int presentDays;
  final int completedDays;
  final int missingCheckOutDays;
  final int validEvents;
  final DateTime? firstClockInAt;
  final DateTime? lastClockOutAt;
  final String? averageClockInTime;
  final int totalWorkingMinutes;
  final int? averageWorkingMinutes;
  final double completionPercent;

  const FlowAttendanceUserAudit({
    required this.userId,
    required this.employeeId,
    required this.fullName,
    required this.roleName,
    required this.active,
    required this.status,
    required this.presentDays,
    required this.completedDays,
    required this.missingCheckOutDays,
    required this.validEvents,
    required this.firstClockInAt,
    required this.lastClockOutAt,
    required this.averageClockInTime,
    required this.totalWorkingMinutes,
    required this.averageWorkingMinutes,
    required this.completionPercent,
  });

  factory FlowAttendanceUserAudit.fromJson(Map<String, dynamic> json) {
    return FlowAttendanceUserAudit(
      userId: json['userId'] as String,
      employeeId: json['employeeId'] as String,
      fullName: json['fullName'] as String,
      roleName: json['roleName'] as String,
      active: json['active'] as bool,
      status: json['status'] as String,
      presentDays: (json['presentDays'] as num).toInt(),
      completedDays: (json['completedDays'] as num).toInt(),
      missingCheckOutDays: (json['missingCheckOutDays'] as num).toInt(),
      validEvents: (json['validEvents'] as num).toInt(),
      firstClockInAt: _parseInstant(json['firstClockInAt']),
      lastClockOutAt: _parseInstant(json['lastClockOutAt']),
      averageClockInTime: json['averageClockInTime'] as String?,
      totalWorkingMinutes: (json['totalWorkingMinutes'] as num).toInt(),
      averageWorkingMinutes: (json['averageWorkingMinutes'] as num?)?.toInt(),
      completionPercent: (json['completionPercent'] as num).toDouble(),
    );
  }

  static DateTime? _parseInstant(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String).toLocal();
  }
}

class FlowAttendanceAudit {
  final AttendanceAuditPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final String label;
  final FlowAttendanceAuditSummary summary;
  final List<FlowAttendanceUserAudit> users;

  const FlowAttendanceAudit({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.label,
    required this.summary,
    required this.users,
  });

  factory FlowAttendanceAudit.fromJson(Map<String, dynamic> json) {
    final periodValue = json['period'] as String;
    final period = AttendanceAuditPeriod.values.firstWhere(
      (item) => item.apiValue == periodValue,
    );
    return FlowAttendanceAudit(
      period: period,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      label: json['label'] as String,
      summary: FlowAttendanceAuditSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      users: (json['users'] as List<dynamic>)
          .map((item) => FlowAttendanceUserAudit.fromJson(
                item as Map<String, dynamic>,
              ))
          .toList(growable: false),
    );
  }
}

String formatIsoDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}


class FlowAttendanceDay {
  final DateTime date;
  final String status;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final int workingMinutes;
  final List<FlowAttendanceEvent> events;

  const FlowAttendanceDay({
    required this.date,
    required this.status,
    required this.checkInAt,
    required this.checkOutAt,
    required this.workingMinutes,
    required this.events,
  });

  factory FlowAttendanceDay.fromJson(Map<String, dynamic> json) {
    return FlowAttendanceDay(
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      checkInAt: json['checkInAt'] == null
          ? null
          : DateTime.parse(json['checkInAt'] as String).toLocal(),
      checkOutAt: json['checkOutAt'] == null
          ? null
          : DateTime.parse(json['checkOutAt'] as String).toLocal(),
      workingMinutes: (json['workingMinutes'] as num).toInt(),
      events: (json['events'] as List<dynamic>? ?? const [])
          .map((item) => FlowAttendanceEvent.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  bool get completed => status == 'COMPLETED';
}

class FlowAttendanceMonthSummary {
  final int month;
  final String label;
  final int presentDays;
  final int completedDays;
  final int missingCheckOutDays;
  final int totalWorkingMinutes;
  final int? averageWorkingMinutes;
  final double completionPercent;

  const FlowAttendanceMonthSummary({
    required this.month,
    required this.label,
    required this.presentDays,
    required this.completedDays,
    required this.missingCheckOutDays,
    required this.totalWorkingMinutes,
    required this.averageWorkingMinutes,
    required this.completionPercent,
  });

  factory FlowAttendanceMonthSummary.fromJson(Map<String, dynamic> json) {
    return FlowAttendanceMonthSummary(
      month: (json['month'] as num).toInt(),
      label: json['label'] as String,
      presentDays: (json['presentDays'] as num).toInt(),
      completedDays: (json['completedDays'] as num).toInt(),
      missingCheckOutDays: (json['missingCheckOutDays'] as num).toInt(),
      totalWorkingMinutes: (json['totalWorkingMinutes'] as num).toInt(),
      averageWorkingMinutes: (json['averageWorkingMinutes'] as num?)?.toInt(),
      completionPercent: (json['completionPercent'] as num).toDouble(),
    );
  }
}

class FlowAttendanceUserDetail {
  final AttendanceAuditPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final String label;
  final FlowAttendanceUserAudit summary;
  final List<FlowAttendanceDay> days;
  final List<FlowAttendanceMonthSummary> months;
  final FlowPage<FlowAttendanceEvent> events;

  const FlowAttendanceUserDetail({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.label,
    required this.summary,
    required this.days,
    required this.months,
    required this.events,
  });

  factory FlowAttendanceUserDetail.fromJson(Map<String, dynamic> json) {
    final periodValue = json['period'] as String;
    return FlowAttendanceUserDetail(
      period: AttendanceAuditPeriod.values.firstWhere(
        (item) => item.apiValue == periodValue,
      ),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      label: json['label'] as String,
      summary: FlowAttendanceUserAudit.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      days: (json['days'] as List<dynamic>? ?? const [])
          .map((item) => FlowAttendanceDay.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      months: (json['months'] as List<dynamic>? ?? const [])
          .map((item) => FlowAttendanceMonthSummary.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      events: FlowPage.fromJson(
        json['events'] as Map<String, dynamic>,
        FlowAttendanceEvent.fromJson,
      ),
    );
  }
}

class FlowAttendanceQrCode {
  final String id;
  final String eventType;
  final DateTime expiresAt;
  final String qrPayload;

  const FlowAttendanceQrCode({
    required this.id,
    required this.eventType,
    required this.expiresAt,
    required this.qrPayload,
  });

  factory FlowAttendanceQrCode.fromJson(Map<String, dynamic> json) {
    return FlowAttendanceQrCode(
      id: json['id'] as String,
      eventType: json['eventType'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      qrPayload: json['qrPayload'] as String,
    );
  }

  bool get isCheckIn => eventType == 'CLOCK_IN';
  String get actionLabel => isCheckIn ? 'Check In' : 'Check Out';
}

