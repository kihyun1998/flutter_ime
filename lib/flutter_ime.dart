import 'dart:io';

import 'flutter_ime_platform_interface.dart';

/// Flutter IME Plugin Main class
class FlutterIme {
  /// Change IME > English
  ///
  /// Supported platforms: Windows, macOS
  Future<void> setEnglishKeyboard() async {
    if (!Platform.isWindows && !Platform.isMacOS) return;

    await FlutterImePlatform.instance.setEnglishKeyboard();
  }

  /// Check is IME English
  ///
  /// Returns:
  /// - true: is English
  /// - false: is not english or not supported platform
  Future<bool> isEnglishKeyboard() async {
    if (!Platform.isWindows && !Platform.isMacOS) return false;

    return FlutterImePlatform.instance.isEnglishKeyboard();
  }
}
