import 'dart:io';

import 'flutter_ime_platform_interface.dart';

/// Flutter IME Plugin Main class
class FlutterIme {
  /// Change IME > English
  ///
  /// Only use in Windows
  Future<void> setEnglishKeyboard() async {
    if (!Platform.isWindows) return;

    await FlutterImePlatform.instance.setEnglishKeyboard();
  }

  /// Check is IME English
  ///
  /// Returns:
  /// - true: is English
  /// - false: is not english or not windows
  Future<bool> isEnglishKeyboard() async {
    if (!Platform.isWindows) return false;

    return FlutterImePlatform.instance.isEnglishKeyboard();
  }

  Future<String?> getPlatformVersion() {
    return FlutterImePlatform.instance.getPlatformVersion();
  }
}
