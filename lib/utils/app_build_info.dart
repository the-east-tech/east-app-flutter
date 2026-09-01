abstract final class AppBuildInfo {
  static const String _buildName = String.fromEnvironment(
    'FLUTTER_BUILD_NAME',
    defaultValue: '1.0.0',
  );
  static const String _buildNumber = String.fromEnvironment(
    'FLUTTER_BUILD_NUMBER',
    defaultValue: '314',
  );

  static String get buildName =>
      _buildName.trim().isEmpty ? '1.0.0' : _buildName.trim();

  static String get buildNumber =>
      _buildNumber.trim().isEmpty ? '314' : _buildNumber.trim();

  static String get displayVersion => '$buildName+$buildNumber';

  static String get releaseLabel => 'east_app_v$buildNumber';
}
