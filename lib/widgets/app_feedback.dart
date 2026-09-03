import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AppFeedback {
  const AppFeedback._();

  static final AudioPlayer _successPlayer = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  static Future<void> _playClick() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {
      // Some devices may ignore system sounds; haptic feedback still runs.
    }
  }

  static Future<void> _playAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      await _playClick();
    }
  }

  static Future<void> tap() async {
    await Future.wait([
      HapticFeedback.lightImpact(),
      _playClick(),
    ]);
  }

  static Future<void> select() async {
    await Future.wait([
      HapticFeedback.selectionClick(),
      _playClick(),
    ]);
  }

  static Future<void> _playSuccessPop() async {
    try {
      await _successPlayer.stop();
      await _successPlayer.play(AssetSource('sounds/02_success_pop.wav'));
    } catch (_) {
      // Fallback keeps success feedback available if the asset/package is not ready.
      await _playClick();
    }
  }

  static Future<void> success() async {
    await Future.wait([
      HapticFeedback.heavyImpact(),
      _playSuccessPop(),
    ]);
  }

  static Future<void> warning() async {
    await Future.wait([
      HapticFeedback.heavyImpact(),
      _playAlert(),
    ]);
  }

  static Future<void> error() async {
    await Future.wait([
      HapticFeedback.vibrate(),
      _playAlert(),
    ]);
  }

  static Future<void> loginSuccess() async {
    await Future.wait([
      HapticFeedback.mediumImpact(),
      _playClick(),
    ]);
  }

  static Future<void> swipeBack() async {
    await Future.wait([
      HapticFeedback.selectionClick(),
      _playAlert(),
    ]);
  }
}
