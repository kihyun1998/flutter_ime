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

/// Disable IME (prevents non-English input)
///
/// Supported platforms: Windows only
///
/// Does nothing on unsupported platforms.
Future<void> disableIME() async {
  if (!Platform.isWindows) return;

  await FlutterImePlatform.instance.disableIME();
}

/// Enable IME (restores input method)
///
/// Supported platforms: Windows only
///
/// Does nothing on unsupported platforms.
Future<void> enableIME() async {
  if (!Platform.isWindows) return;

  await FlutterImePlatform.instance.enableIME();
}

/// Stream that emits when input source (keyboard layout) changes
///
/// Supported platforms: Windows, macOS
///
/// Emits:
/// - `true`: Changed to English keyboard
/// - `false`: Changed to non-English keyboard (e.g., Korean)
///
/// Returns empty stream on unsupported platforms.
Stream<bool> onInputSourceChanged() {
  if (!Platform.isWindows && !Platform.isMacOS) {
    return const Stream.empty();
  }

  return FlutterImePlatform.instance.onInputSourceChanged;
}

/// Check if Caps Lock is currently on
///
/// Supported platforms: Windows, macOS
///
/// Returns:
/// - `true`: Caps Lock is on
/// - `false`: Caps Lock is off or platform is not supported
Future<bool> isCapsLockOn() async {
  if (!Platform.isWindows && !Platform.isMacOS) return false;

  return FlutterImePlatform.instance.isCapsLockOn();
}

/// Stream that emits when Caps Lock state changes
///
/// Supported platforms: Windows, macOS
///
/// Emits:
/// - `true`: Caps Lock turned on
/// - `false`: Caps Lock turned off
///
/// Returns empty stream on unsupported platforms.
Stream<bool> onCapsLockChanged() {
  if (!Platform.isWindows && !Platform.isMacOS) {
    return const Stream.empty();
  }

  return FlutterImePlatform.instance.onCapsLockChanged;
}
