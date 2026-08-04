import 'api_models.dart';

class EastAppAttendanceEvent {
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
  final bool cameraCaptureValid;
  final bool faceValid;
  final int faceCount;
  final int faceAttemptCount;
  final bool faceVerificationBypassed;
  final bool qrCheckpointValid;
  final String devicePlatform;
  final String appVersion;
  final String validationMethod;
  final bool photoStored;

  const EastAppAttendanceEvent({
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
    required this.cameraCaptureValid,
    required this.faceValid,
    required this.faceCount,
    required this.faceAttemptCount,
    required this.faceVerificationBypassed,
    required this.qrCheckpointValid,
    required this.devicePlatform,
    required this.appVersion,
    required this.validationMethod,
    required this.photoStored,
  });

  factory EastAppAttendanceEvent.fromJson(Map<String, dynamic> json) {
    return EastAppAttendanceEvent(
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
      cameraCaptureValid: json['cameraCaptureValid'] as bool,
      faceValid: json['faceValid'] as bool,
      faceCount: (json['faceCount'] as num).toInt(),
      faceAttemptCount: (json['faceAttemptCount'] as num).toInt(),
      faceVerificationBypassed: json['faceVerificationBypassed'] as bool,
      qrCheckpointValid: json['qrCheckpointValid'] as bool,
      devicePlatform: json['devicePlatform'] as String,
      appVersion: json['appVersion'] as String,
      validationMethod: json['validationMethod'] as String,
      photoStored: json['photoStored'] as bool,
    );
  }
}

class EastAppAttendanceToday {
  final DateTime date;
  final String status;
  final EastAppAttendanceEvent? clockIn;
  final EastAppAttendanceEvent? clockOut;
  final int totalWorkingMinutes;

  const EastAppAttendanceToday({
    required this.date,
    required this.status,
    required this.clockIn,
    required this.clockOut,
    required this.totalWorkingMinutes,
  });

  factory EastAppAttendanceToday.fromJson(Map<String, dynamic> json) {
    final clockInJson = json['clockIn'];
    final clockOutJson = json['clockOut'];
    return EastAppAttendanceToday(
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      clockIn: clockInJson is Map<String, dynamic>
          ? EastAppAttendanceEvent.fromJson(clockInJson)
          : null,
      clockOut: clockOutJson is Map<String, dynamic>
          ? EastAppAttendanceEvent.fromJson(clockOutJson)
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

class EastAppAttendanceAuditSummary {
  final int people;
  final int peopleWithAttendance;
  final int presentDays;
  final int completedDays;
  final int missingCheckOutDays;
  final double completionPercent;

  const EastAppAttendanceAuditSummary({
    required this.people,
    required this.peopleWithAttendance,
    required this.presentDays,
    required this.completedDays,
    required this.missingCheckOutDays,
    required this.completionPercent,
  });

  factory EastAppAttendanceAuditSummary.fromJson(Map<String, dynamic> json) {
    return EastAppAttendanceAuditSummary(
      people: (json['people'] as num).toInt(),
      peopleWithAttendance: (json['peopleWithAttendance'] as num).toInt(),
      presentDays: (json['presentDays'] as num).toInt(),
      completedDays: (json['completedDays'] as num).toInt(),
      missingCheckOutDays: (json['missingCheckOutDays'] as num).toInt(),
      completionPercent: (json['completionPercent'] as num).toDouble(),
    );
  }
}

class EastAppAttendanceUserAudit {
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
  final int? averageWorkingMinutes;
  final double completionPercent;

  const EastAppAttendanceUserAudit({
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
    required this.averageWorkingMinutes,
    required this.completionPercent,
  });

  factory EastAppAttendanceUserAudit.fromJson(Map<String, dynamic> json) {
    return EastAppAttendanceUserAudit(
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
      averageWorkingMinutes: (json['averageWorkingMinutes'] as num?)?.toInt(),
      completionPercent: (json['completionPercent'] as num).toDouble(),
    );
  }

  static DateTime? _parseInstant(Object? value) {
    if (value == null) return null;
    return DateTime.parse(value as String).toLocal();
  }
}

class EastAppAttendanceAudit {
  final AttendanceAuditPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final String label;
  final EastAppAttendanceAuditSummary summary;
  final List<EastAppAttendanceUserAudit> users;

  const EastAppAttendanceAudit({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.label,
    required this.summary,
    required this.users,
  });

  factory EastAppAttendanceAudit.fromJson(Map<String, dynamic> json) {
    final periodValue = json['period'] as String;
    final period = AttendanceAuditPeriod.values.firstWhere(
      (item) => item.apiValue == periodValue,
    );
    return EastAppAttendanceAudit(
      period: period,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      label: json['label'] as String,
      summary: EastAppAttendanceAuditSummary.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      users: (json['users'] as List<dynamic>)
          .map((item) => EastAppAttendanceUserAudit.fromJson(
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


class EastAppAttendanceUserDetail {
  final AttendanceAuditPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final String label;
  final EastAppAttendanceUserAudit summary;
  final EastAppPage<EastAppAttendanceEvent> events;

  const EastAppAttendanceUserDetail({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.label,
    required this.summary,
    required this.events,
  });

  factory EastAppAttendanceUserDetail.fromJson(Map<String, dynamic> json) {
    final periodValue = json['period'] as String;
    return EastAppAttendanceUserDetail(
      period: AttendanceAuditPeriod.values.firstWhere(
        (item) => item.apiValue == periodValue,
      ),
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      label: json['label'] as String,
      summary: EastAppAttendanceUserAudit.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
      events: EastAppPage.fromJson(
        json['events'] as Map<String, dynamic>,
        EastAppAttendanceEvent.fromJson,
      ),
    );
  }
}

class EastAppAttendanceFaceAttempt {
  final String id;
  final String intendedEventType;
  final DateTime recordedAt;
  final DateTime deviceAttemptedAt;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String capturedAddress;
  final String workLocationName;
  final String workLocationAddress;
  final double workLocationLatitude;
  final double workLocationLongitude;
  final double distanceMeters;
  final String failureReason;
  final int faceCount;
  final int faceAttemptNumber;
  final double? faceBoxWidth;
  final double? faceBoxHeight;
  final double? faceYaw;
  final double? faceRoll;
  final double? facePitch;
  final String devicePlatform;
  final String appVersion;
  final String validationMethod;
  final bool photoStored;

  const EastAppAttendanceFaceAttempt({
    required this.id,
    required this.intendedEventType,
    required this.recordedAt,
    required this.deviceAttemptedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAddress,
    required this.workLocationName,
    required this.workLocationAddress,
    required this.workLocationLatitude,
    required this.workLocationLongitude,
    required this.distanceMeters,
    required this.failureReason,
    required this.faceCount,
    required this.faceAttemptNumber,
    required this.faceBoxWidth,
    required this.faceBoxHeight,
    required this.faceYaw,
    required this.faceRoll,
    required this.facePitch,
    required this.devicePlatform,
    required this.appVersion,
    required this.validationMethod,
    required this.photoStored,
  });

  factory EastAppAttendanceFaceAttempt.fromJson(Map<String, dynamic> json) {
    double? optionalDouble(String key) => (json[key] as num?)?.toDouble();
    return EastAppAttendanceFaceAttempt(
      id: json['id'] as String,
      intendedEventType: json['intendedEventType'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String).toLocal(),
      deviceAttemptedAt: DateTime.parse(json['deviceAttemptedAt'] as String).toLocal(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyMeters: (json['accuracyMeters'] as num).toDouble(),
      capturedAddress: json['capturedAddress'] as String,
      workLocationName: json['workLocationName'] as String,
      workLocationAddress: json['workLocationAddress'] as String,
      workLocationLatitude: (json['workLocationLatitude'] as num).toDouble(),
      workLocationLongitude: (json['workLocationLongitude'] as num).toDouble(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      failureReason: json['failureReason'] as String,
      faceCount: (json['faceCount'] as num).toInt(),
      faceAttemptNumber: (json['faceAttemptNumber'] as num).toInt(),
      faceBoxWidth: optionalDouble('faceBoxWidth'),
      faceBoxHeight: optionalDouble('faceBoxHeight'),
      faceYaw: optionalDouble('faceYaw'),
      faceRoll: optionalDouble('faceRoll'),
      facePitch: optionalDouble('facePitch'),
      devicePlatform: json['devicePlatform'] as String,
      appVersion: json['appVersion'] as String,
      validationMethod: json['validationMethod'] as String,
      photoStored: json['photoStored'] as bool? ?? false,
    );
  }
}
