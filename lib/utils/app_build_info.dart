import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

abstract final class AppBuildInfo {
  static const String _buildName = String.fromEnvironment(
    'FLUTTER_BUILD_NAME',
    defaultValue: '1.0.1',
  );
  static const String _buildNumber = String.fromEnvironment(
    'FLUTTER_BUILD_NUMBER',
    defaultValue: '4',
  );
  static String _runtimeBuildName = _buildName;
  static String _runtimeBuildNumber = _buildNumber;
  static Future<void>? _initialising;

  static String get buildName =>
      _runtimeBuildName.trim().isEmpty ? '1.0.1' : _runtimeBuildName.trim();

  static String get buildNumber =>
      _runtimeBuildNumber.trim().isEmpty ? '4' : _runtimeBuildNumber.trim();

  static Future<void> initialise() => _initialising ??= _loadPackageInfo();

  static Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.trim().isNotEmpty) {
        _runtimeBuildName = info.version.trim();
      }
      if (info.buildNumber.trim().isNotEmpty) {
        _runtimeBuildNumber = info.buildNumber.trim();
      }
    } catch (_) {
      // Compile-time values remain available if native package info cannot load.
    }
  }

  static String get displayVersion => '$buildName+$buildNumber';

  static int get numericBuildNumber => int.tryParse(buildNumber) ?? 1;

  static String? get platformApiValue {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'ANDROID',
      TargetPlatform.iOS => 'IOS',
      _ => null,
    };
  }

  static String get releaseLabel => 'flow_v$buildNumber';
}
