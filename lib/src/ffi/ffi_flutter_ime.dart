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
      : _windowsIme = windowsIme ?? (Platform.isWindows ? WindowsIme() : null);

  final WindowsIme? _windowsIme;

  /// Resolves the target window and describes it, or returns null off Windows.
  ///
  /// A method, not a getter: on a cache miss this walks the process's window
  /// tree. Call it deliberately — not from a `build`.
  ///
  /// Deliberately returns a string rather than a structured type. It crosses
  /// the conditional-import boundary, and the web stub cannot name a type that
  /// depends on `dart:ffi`. Intended for diagnostics in the example app.
  String? describeResolvedWindow() => _windowsIme?.resolveWindow().toString();

  WindowsIme get _windows {
    final ime = _windowsIme;
    if (ime == null) {
      throw UnsupportedError(
          'The FFI implementation currently supports Windows only. '
          'macOS support arrives with its own ticket.');
    }
    return ime;
  }

  /// Switches the IME to English.
  ///
  /// Does nothing if the target window cannot be resolved — for example while
  /// the app has no window of its own to find. This is a deliberate no-op
  /// rather than an error: the public API returns no value, and callers wire
  /// this to focus changes where throwing would be worse than doing nothing.
  @override
  Future<void> setEnglishKeyboard() async => _windows.setEnglishKeyboard();

  /// Reads the current keyboard as an opaque token.
  ///
  /// Returns null when the layout cannot be read. The token format is
  /// byte-identical to the one 2.x produced, so a token saved before upgrading
  /// still restores.
  @override
  Future<String?> getCurrentInputSource() async =>
      _windows.getCurrentInputSource();

  /// Restores a keyboard from a token previously returned by
  /// [getCurrentInputSource].
  ///
  /// A malformed token is ignored rather than raised: these come back from a
  /// consumer's own storage, and 2.1.4 fixed a crash where one reached the
  /// numeric parser and threw.
  @override
  Future<void> setInputSource(String sourceId) async =>
      _windows.setInputSource(sourceId);

  /// Whether the IME is in English mode.
  ///
  /// Returns false when the target window or its IME context cannot be
  /// reached, which is also what the native plugin reports in that situation.
  /// A detached IME context — the normal state after `disableIME()` — reads as
  /// false for the same reason.
  @override
  Future<bool> isEnglishKeyboard() async => _windows.isEnglishKeyboard();
}
