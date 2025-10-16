import 'dart:io';

import 'flutter_ime_platform_interface.dart';

/// Change IME to English
///
/// Supported platforms: Windows, macOS
///
/// Does nothing on unsupported platforms.
Future<void> setEnglishKeyboard() async {
  if (!Platform.isWindows && !Platform.isMacOS) return;

  await FlutterImePlatform.instance.setEnglishKeyboard();
}

/// Check if current IME is English
///
/// Supported platforms: Windows, macOS
///
/// Returns:
/// - `true`: Current keyboard is English
/// - `false`: Current keyboard is not English or platform is not supported
Future<bool> isEnglishKeyboard() async {
  if (!Platform.isWindows && !Platform.isMacOS) return false;

  return FlutterImePlatform.instance.isEnglishKeyboard();
}
