/// The FFI-backed platform implementation, selected on platforms that have
/// `dart:ffi`.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../flutter_ime_method_channel.dart';
import '../change_stream.dart';
import '../value_poller.dart';
import '../../flutter_ime_platform_interface.dart';
import 'macos_ime.dart';
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
/// can never break an operation that already worked. Both platforms are now
/// fully ported; what still falls through is `disableIME` and `enableIME` on
/// macOS, which macOS never supported in the first place.
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
  FfiFlutterIme({FlutterImePlatform? fallback})
      : _windowsIme = Platform.isWindows ? WindowsIme() : null,
        _macosIme = Platform.isMacOS ? MacosIme() : null,
        _fallback = fallback ?? MethodChannelFlutterIme();

  /// Builds an instance with the backends given, doing no platform detection
  /// of its own.
  ///
  /// Tests use this so that what they exercise does not depend on the host they
  /// run on. The default constructor picks a backend from [Platform], which in a
  /// test means the real one — a `flutter test` run on a Mac would then switch
  /// the developer's keyboard layout, and one on Windows would reach into
  /// whatever window happened to be focused.
  @visibleForTesting
  FfiFlutterIme.withBackends({
    WindowsIme? windowsIme,
    MacosIme? macosIme,
    FlutterImePlatform? fallback,
  })  : _windowsIme = windowsIme,
        _macosIme = macosIme,
        _fallback = fallback ?? MethodChannelFlutterIme();

  final WindowsIme? _windowsIme;

  /// Null off macOS. Covers everything macOS supports; only `disableIME` and
  /// `enableIME` still fall through, and those were never supported here.
  final MacosIme? _macosIme;

  /// Handles everything not yet reachable through FFI.
  final FlutterImePlatform _fallback;

  /// How often the polled streams re-read their value.
  ///
  /// Deliberately not configurable: the public API should not grow a knob for
  /// it. Chosen so that reverting an unwanted keyboard switch feels immediate —
  /// the "force English" recipe in the README reacts to these events, and a
  /// slower poll would let a character or two through first. Two cheap Win32
  /// reads at this rate cost nothing measurable.
  static const Duration _pollInterval = Duration(milliseconds: 50);

  ValuePoller<bool>? _inputSourcePoller;
  ValuePoller<bool>? _capsLockPoller;

  /// The macOS input-source stream. Notification-driven, so it has no interval
  /// and is not a [ValuePoller].
  ChangeStream<bool>? _inputSourceChanges;

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

  /// Describes the selected macOS input source — its identifier and the
  /// languages it types — or null where that is not an FFI operation.
  ///
  /// A string for the same reason as [describeResolvedWindow]: it crosses the
  /// conditional-import boundary, and the web stub cannot name a type that
  /// depends on `dart:ffi`. Intended for diagnostics in the example app, where
  /// it shows why [isEnglishKeyboard] answered the way it did.
  String? describeCurrentInputSource() =>
      _macosIme?.describeCurrentInputSource();

  // -------------------------------------------------------------------------
  // Ported to FFI
  // -------------------------------------------------------------------------

  /// Switches the keyboard to English: alphanumeric conversion mode on
  /// Windows, the ABC layout on macOS.
  ///
  /// Does nothing on Windows if the target window cannot be resolved — for
  /// example while the app has no window of its own to find — and nothing on
  /// macOS if ABC is not among the user's enabled input sources.
  ///
  /// **Differs from 2.x.** The native plugin reported failure as a
  /// `PlatformException`; this reports it by doing nothing. Callers wire these
  /// to focus changes, where an unhandled async error is worse than a keyboard
  /// that did not switch. Code that caught the exception will simply stop
  /// seeing it — nothing breaks, but nothing warns either.
  @override
  Future<void> setEnglishKeyboard() async {
    final windows = _windowsIme;
    if (windows != null) {
      windows.setEnglishKeyboard();
      return;
    }
    final macos = _macosIme;
    if (macos != null) {
      macos.setEnglishKeyboard();
      return;
    }
    return _fallback.setEnglishKeyboard();
  }

  /// Whether the keyboard is currently English.
  ///
  /// **This asks a different question on each platform, deliberately.** On
  /// Windows it means "the IME is not converting to the native language"; on
  /// macOS it means "the selected layout types English". macOS switches whole
  /// layouts where Windows toggles a conversion mode within one, so there is no
  /// single question to ask. The divergence predates this implementation.
  ///
  /// Returns false when the answer cannot be read: on Windows when the target
  /// window or its IME context cannot be reached — including after
  /// `disableIME()`, which leaves no context to read — and on macOS when there
  /// is no readable current input source.
  ///
  /// **The macOS answer differs from 2.x** for every English layout that is not
  /// ABC or US. `isEnglishInputSource` records why.
  @override
  Future<bool> isEnglishKeyboard() async {
    final windows = _windowsIme;
    if (windows != null) return windows.isEnglishKeyboard();
    final macos = _macosIme;
    if (macos != null) return macos.isEnglishKeyboard();
    return _fallback.isEnglishKeyboard();
  }

  /// Reads the current keyboard as an opaque token.
  ///
  /// Returns null when the keyboard cannot be read. The token format is
  /// byte-identical to the one 2.x produced on each platform — the
  /// `KLID:conversion:sentence` triple on Windows, the input-source identifier
  /// on macOS — so a token saved before upgrading still restores.
  @override
  Future<String?> getCurrentInputSource() async {
    final windows = _windowsIme;
    if (windows != null) return windows.getCurrentInputSource();
    final macos = _macosIme;
    if (macos != null) return macos.getCurrentInputSource();
    return _fallback.getCurrentInputSource();
  }

  /// Restores a keyboard from a token previously returned by
  /// [getCurrentInputSource].
  ///
  /// **Differs from 2.x**, which raised a `PlatformException` when the token
  /// was malformed or the keyboard could not be loaded. Both are silent here.
  /// Tokens come back from a consumer's own storage and can be stale — the
  /// saved keyboard may have been uninstalled since — so a failed restore is an
  /// expected outcome rather than an exceptional one. 2.1.4 already had to fix
  /// a crash on this path.
  ///
  /// A token that names nothing changes nothing: the keyboard the user is on
  /// stays selected. On macOS a saved keyboard the user has since switched off
  /// in System Settings is switched back on before being selected, since
  /// restoring hands back something that was theirs already.
  @override
  Future<void> setInputSource(String sourceId) async {
    final windows = _windowsIme;
    if (windows != null) {
      windows.setInputSource(sourceId);
      return;
    }
    final macos = _macosIme;
    if (macos != null) {
      macos.setInputSource(sourceId);
      return;
    }
    return _fallback.setInputSource(sourceId);
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
  ///
  /// Does nothing if the target window cannot be resolved, and — like
  /// [disableIME] — reports that by staying silent rather than raising, where
  /// 2.x raised a `PlatformException`.
  @override
  Future<void> enableIME() async {
    final ime = _windowsIme;
    if (ime == null) return _fallback.enableIME();
    ime.enableIme();
  }

  /// Whether Caps Lock is currently on.
  ///
  /// **Differs from 2.x on macOS**, where this now reads hardware modifier
  /// state rather than watching for modifier-key events. See `CoreGraphics`.
  @override
  Future<bool> isCapsLockOn() async {
    final windows = _windowsIme;
    if (windows != null) return windows.isCapsLockOn();
    final macos = _macosIme;
    if (macos != null) return macos.isCapsLockOn();
    return _fallback.isCapsLockOn();
  }

  /// Emits when the keyboard switches between English and non-English.
  ///
  /// **Differs from 2.x** in one deliberate way. The native plugin emitted on
  /// every layout-change message, so switching Korean to Japanese — both
  /// non-English — emitted `false` a second time. This emits only when the
  /// value actually changes, which is what "emits when the input source
  /// changes" always claimed.
  ///
  /// **The two platforms learn about the change differently, and macOS has the
  /// better end of it.** Windows polls, because a window procedure has to
  /// return a value synchronously and no Dart FFI callback can — see
  /// [ValuePoller]. macOS is told: it posts a distributed notification whose
  /// observer returns nothing, which a listener callable bridges exactly, so
  /// delivery there is immediate rather than up to one poll interval late.
  ///
  /// Nothing runs on either platform until something listens.
  @override
  Stream<bool> get onInputSourceChanged {
    final windows = _windowsIme;
    if (windows != null) {
      return (_inputSourcePoller ??= ValuePoller<bool>(
        read: windows.readEnglishStateOrNull,
        interval: _pollInterval,
      ))
          .stream;
    }
    final macos = _macosIme;
    if (macos != null) {
      return (_inputSourceChanges ??= ChangeStream<bool>(
        read: macos.readEnglishStateOrNull,
        start: macos.startInputSourceNotifications,
        stop: macos.stopInputSourceNotifications,
      ))
          .stream;
    }
    return _fallback.onInputSourceChanged;
  }

  /// Emits when Caps Lock is toggled.
  ///
  /// The state current when a listener attaches is not emitted; use
  /// [isCapsLockOn] for that. Nothing is polled until something listens.
  ///
  /// Polled on both platforms. macOS has a push mechanism for this too — a
  /// global event monitor — but it needs a permission this package never
  /// requested, so swapping it for a poll of hardware state is an improvement
  /// rather than the downgrade that dropping push delivery usually is. See
  /// `CoreGraphics` for the detail.
  @override
  Stream<bool> get onCapsLockChanged {
    final windows = _windowsIme;
    final macos = _macosIme;
    if (windows == null && macos == null) return _fallback.onCapsLockChanged;
    return (_capsLockPoller ??= ValuePoller<bool>(
      read: windows != null ? windows.isCapsLockOn : macos!.isCapsLockOn,
      interval: _pollInterval,
    ))
        .stream;
  }
}
