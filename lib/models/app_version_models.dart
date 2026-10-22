class AppVersionPolicy {
  final String platform;
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final bool updateRequired;
  final String updateUrl;

  const AppVersionPolicy({
    required this.platform,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.updateRequired,
    required this.updateUrl,
  });

  String get currentDisplayVersion => '$currentVersion+$currentBuildNumber';

  String get latestDisplayVersion => '$latestVersion+$latestBuildNumber';

  factory AppVersionPolicy.fromJson(Map<String, dynamic> json) {
    return AppVersionPolicy(
      platform: json['platform'] as String? ?? '',
      currentVersion: json['currentVersion'] as String? ?? '',
      currentBuildNumber: (json['currentBuildNumber'] as num?)?.toInt() ?? 0,
      latestVersion: json['latestVersion'] as String? ?? '',
      latestBuildNumber: (json['latestBuildNumber'] as num?)?.toInt() ?? 0,
      updateRequired: json['updateRequired'] as bool? ?? false,
      updateUrl: json['updateUrl'] as String? ?? '',
    );
  }
}
