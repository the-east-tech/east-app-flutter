import 'people_models.dart';

class EmployeeSopPlayback {
  final String sopId;
  final String linkGroupId;
  final String title;
  final String language;
  final int totalPlayedSeconds;
  final DateTime? lastWatchedAt;

  const EmployeeSopPlayback({
    required this.sopId,
    required this.linkGroupId,
    required this.title,
    required this.language,
    required this.totalPlayedSeconds,
    required this.lastWatchedAt,
  });

  factory EmployeeSopPlayback.fromJson(Map<String, dynamic> json) {
    return EmployeeSopPlayback(
      sopId: json['sopId'] as String,
      linkGroupId: json['linkGroupId'] as String,
      title: json['title'] as String,
      language: json['language'] as String,
      totalPlayedSeconds: (json['totalPlayedSeconds'] as num).toInt(),
      lastWatchedAt: _dateTime(json['lastWatchedAt']),
    );
  }
}

class EmployeeSopAudit {
  final EastAppUser user;
  final int totalPlayedSeconds;
  final List<EmployeeSopPlayback> videos;

  const EmployeeSopAudit({
    required this.user,
    required this.totalPlayedSeconds,
    required this.videos,
  });

  factory EmployeeSopAudit.fromJson(Map<String, dynamic> json) {
    return EmployeeSopAudit(
      user: EastAppUser.fromJson(json['user'] as Map<String, dynamic>),
      totalPlayedSeconds: (json['totalPlayedSeconds'] as num).toInt(),
      videos: (json['videos'] as List<dynamic>? ?? const [])
          .map(
            (item) => EmployeeSopPlayback.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

class SopPlaybackImpact {
  final String sopId;
  final String linkGroupId;
  final String title;
  final String language;
  final int totalPlayedSeconds;
  final int uniqueViewers;
  final DateTime? lastWatchedAt;

  const SopPlaybackImpact({
    required this.sopId,
    required this.linkGroupId,
    required this.title,
    required this.language,
    required this.totalPlayedSeconds,
    required this.uniqueViewers,
    required this.lastWatchedAt,
  });

  factory SopPlaybackImpact.fromJson(Map<String, dynamic> json) {
    return SopPlaybackImpact(
      sopId: json['sopId'] as String,
      linkGroupId: json['linkGroupId'] as String,
      title: json['title'] as String,
      language: json['language'] as String,
      totalPlayedSeconds: (json['totalPlayedSeconds'] as num).toInt(),
      uniqueViewers: (json['uniqueViewers'] as num).toInt(),
      lastWatchedAt: _dateTime(json['lastWatchedAt']),
    );
  }
}

class SopImpactAudit {
  final int totalPlayedSeconds;
  final int uniqueViewers;
  final List<SopPlaybackImpact> videos;

  const SopImpactAudit({
    required this.totalPlayedSeconds,
    required this.uniqueViewers,
    required this.videos,
  });

  factory SopImpactAudit.fromJson(Map<String, dynamic> json) {
    return SopImpactAudit(
      totalPlayedSeconds: (json['totalPlayedSeconds'] as num).toInt(),
      uniqueViewers: (json['uniqueViewers'] as num).toInt(),
      videos: (json['videos'] as List<dynamic>? ?? const [])
          .map(
            (item) => SopPlaybackImpact.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(growable: false),
    );
  }
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}
