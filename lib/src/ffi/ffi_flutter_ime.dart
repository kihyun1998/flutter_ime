/// The FFI-backed platform implementation, selected on platforms that have
/// `dart:ffi`.
library;

import 'dart:io';

import '../../flutter_ime_platform_interface.dart';
import 'windows_ime.dart';

/// Calls the operating system directly through `dart:ffi`, with no platform
/// channel and no native plugin code.
///
/// While the migration is in progress this is opt-in: the native plugin is
/// still registered and still the default. Assign it explicitly to try it:
///
/// ```dart
/// FlutterImePlatform.instance = FfiFlutterIme();
/// ```
///
/// Only Windows English-keyboard control is implemented so far. The remaining
/// operations still route through the native plugin unless this instance is
/// installed, in which case they throw until their own tickets land.
class FfiFlutterIme extends FlutterImePlatform {
  FfiFlutterIme({WindowsIme? windowsIme})
      : _windowsIme =
            windowsIme ?? (Platform.isWindows ? WindowsIme() : null);

  final WindowsIme? _windowsIme;

  /// A description of which window the Windows implementation resolved and how
  /// it found it, or null off Windows.
  ///
  /// Deliberately a string rather than a structured type: it crosses the
  /// conditional-import boundary, and the web stub cannot name a type that
  /// depends on `dart:ffi`. Intended for diagnostics in the example app.
  String? get windowDiagnostics => _windowsIme?.lastResolution.toString();

  WindowsIme get _windows {
    final ime = _windowsIme;
    if (ime == null) {
      throw UnsupportedError(
          'The FFI implementation currently supports Windows only. '
          'macOS support arrives with its own ticket.');
    }
    return ime;
  }

  @override
  Future<void> setEnglishKeyboard() async => _windows.setEnglishKeyboard();

  @override
  Future<bool> isEnglishKeyboard() async => _windows.isEnglishKeyboard();
}
