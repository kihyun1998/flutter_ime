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
  /// the app has no window of its own to find.
  ///
  /// **Differs from 2.x.** The native plugin reported failure as a
  /// `PlatformException`; this reports it by doing nothing. Callers wire these
  /// to focus changes, where an unhandled async error is worse than a keyboard
  /// that did not switch. Code that caught the exception will simply stop
  /// seeing it — nothing breaks, but nothing warns either.
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
  /// **Differs from 2.x**, which raised a `PlatformException` when the token
  /// was malformed or the layout could not be loaded. Both are silent here.
  /// Tokens come back from a consumer's own storage and can be stale — the
  /// saved layout may have been uninstalled since — so a failed restore is an
  /// expected outcome rather than an exceptional one. 2.1.4 already had to fix
  /// a crash on this path.
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
