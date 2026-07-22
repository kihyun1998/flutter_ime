/// The FFI-backed platform implementation, selected on platforms that have
/// `dart:ffi`.
library;

import 'dart:io';

import '../../flutter_ime_method_channel.dart';
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
/// **Operations not ported yet fall through to the native plugin** rather than
/// throwing. That is what makes this safe to install at any point during the
/// migration: a half-ported instance behaves like a whole one, so installing it
/// can never break an operation that already worked. The same applies off
/// Windows, where nothing is ported yet and every call falls through.
///
/// This matters more than it looks. An earlier version threw for unported
/// operations, and installing it mid-session crashed the example app: page
/// transitions run the incoming page's `initState` before the outgoing page's
/// `dispose`, so an unported operation was reached through an instance that was
/// supposed to have been uninstalled already.
///
/// The fallback disappears along with the native plugin once every operation is
/// ported.
class FfiFlutterIme extends FlutterImePlatform {
  FfiFlutterIme({WindowsIme? windowsIme, FlutterImePlatform? fallback})
      : _windowsIme = windowsIme ?? (Platform.isWindows ? WindowsIme() : null),
        _fallback = fallback ?? MethodChannelFlutterIme();

  final WindowsIme? _windowsIme;

  /// Handles everything not yet reachable through FFI.
  final FlutterImePlatform _fallback;

  /// Resolves the target window and describes it, or returns null where there
  /// is no FFI implementation yet.
  ///
  /// A method, not a getter: on a cache miss this walks the process's window
  /// tree. Call it deliberately — not from a `build`.
  ///
  /// Deliberately returns a string rather than a structured type. It crosses
  /// the conditional-import boundary, and the web stub cannot name a type that
  /// depends on `dart:ffi`. Intended for diagnostics in the example app.
  String? describeResolvedWindow() => _windowsIme?.resolveWindow().toString();

  // -------------------------------------------------------------------------
  // Ported to FFI
  // -------------------------------------------------------------------------

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
  Future<void> setEnglishKeyboard() async {
    final ime = _windowsIme;
    if (ime == null) return _fallback.setEnglishKeyboard();
    ime.setEnglishKeyboard();
  }

  /// Whether the IME is in English mode.
  ///
  /// Returns false when the target window or its IME context cannot be
  /// reached, which is also what the native plugin reports in that situation.
  /// A detached IME context — the normal state after `disableIME()` — reads as
  /// false for the same reason.
  @override
  Future<bool> isEnglishKeyboard() async {
    final ime = _windowsIme;
    if (ime == null) return _fallback.isEnglishKeyboard();
    return ime.isEnglishKeyboard();
  }

  /// Reads the current keyboard as an opaque token.
  ///
  /// Returns null when the layout cannot be read. The token format is
  /// byte-identical to the one 2.x produced, so a token saved before upgrading
  /// still restores.
  @override
  Future<String?> getCurrentInputSource() async {
    final ime = _windowsIme;
    if (ime == null) return _fallback.getCurrentInputSource();
    return ime.getCurrentInputSource();
  }

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
  Future<void> setInputSource(String sourceId) async {
    final ime = _windowsIme;
    if (ime == null) return _fallback.setInputSource(sourceId);
    ime.setInputSource(sourceId);
  }

  /// Disables the IME so composition cannot start in the app window.
  ///
  /// Detaching the IME context is the entire mechanism; the native plugin's
  /// window-procedure message filter is deliberately not reproduced, because a
  /// spike showed it never contributed anything the detach did not already do.
  ///
  /// Does **not** prevent pasted or programmatically injected text — neither
  /// did 2.x, since paste never travels the keyboard message path.
  ///
  /// **Differs from 2.x**, which raised a `PlatformException` when there was no
  /// window to operate on. That is silent here, for the reasons given on
  /// [setEnglishKeyboard].
  @override
  Future<void> disableIME() async {
    final ime = _windowsIme;
    if (ime == null) return _fallback.disableIME();
    ime.disableIme();
  }

  /// Restores normal IME functionality after [disableIME].
  @override
  Future<void> enableIME() async {
    final ime = _windowsIme;
    if (ime == null) return _fallback.enableIME();
    ime.enableIme();
  }

  // -------------------------------------------------------------------------
  // Not ported yet — handled by the native plugin
  // -------------------------------------------------------------------------

  @override
  Future<bool> isCapsLockOn() => _fallback.isCapsLockOn();

  @override
  Stream<bool> get onInputSourceChanged => _fallback.onInputSourceChanged;

  @override
  Stream<bool> get onCapsLockChanged => _fallback.onCapsLockChanged;
}
