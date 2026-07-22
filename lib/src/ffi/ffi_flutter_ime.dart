/// The platform implementation, selected on platforms that have `dart:ffi`.
library;

import 'dart:io';

import 'package:meta/meta.dart';

import '../../flutter_ime_platform_interface.dart';
import '../change_stream.dart';
import '../value_poller.dart';
import 'macos_ime.dart';
import 'windows_ime.dart';

/// Calls the operating system directly through `dart:ffi`, with no platform
/// channel and no native plugin code.
///
/// This is the default and only implementation as of 3.0.0. Until then it was
/// opt-in beside a native plugin, and every operation it had not yet ported
/// fell through to that plugin. Both the plugin and the fall-through are gone;
/// what an unsupported platform gets now is the documented default, not a
/// second implementation.
///
/// **Off Windows and macOS every operation is a no-op.** In practice nothing
/// reaches here on those platforms — the gating in `flutter_ime.dart`
/// short-circuits first — but this holds the line on its own rather than
/// relying on a caller to. A backend that is null is a platform with no IME to
/// talk to, and the documented answer there is that nothing happened.
class FfiFlutterIme extends FlutterImePlatform {
  FfiFlutterIme()
      : _windowsIme = Platform.isWindows ? WindowsIme() : null,
        _macosIme = Platform.isMacOS ? MacosIme() : null;

  /// Builds an instance with the backends given, doing no platform detection
  /// of its own.
  ///
  /// Tests use this so that what they exercise does not depend on the host they
  /// run on. The default constructor picks a backend from [Platform], which in
  /// a test means the real one — a test run on a Mac would then switch the
  /// developer's keyboard layout, and one on Windows would reach into whatever
  /// window happened to be focused.
  @visibleForTesting
  FfiFlutterIme.withBackends({WindowsIme? windowsIme, MacosIme? macosIme})
      : _windowsIme = windowsIme,
        _macosIme = macosIme;

  /// Null off Windows.
  final WindowsIme? _windowsIme;

  /// Null off macOS. Covers everything macOS supports; [disableIME] and
  /// [enableIME] are unsupported there and always have been.
  final MacosIme? _macosIme;

  // Every operation below dispatches the same way: try Windows, then macOS,
  // then give the documented default. One backend is always null in practice,
  // but the shape is uniform on purpose. Written as a `??` chain over the
  // *results* it would read as "first non-null answer wins", which is wrong
  // wherever null is itself an answer — `getCurrentInputSource` returns null
  // for a keyboard it could not read, and a chain would carry on into the
  // other backend rather than reporting it.

  /// How often the polled streams re-read their value.
  ///
  /// Deliberately not configurable: the public API should not grow a knob for
  /// it. Chosen so that reverting an unwanted keyboard switch feels immediate —
  /// the "force English" recipe in the README reacts to these events, and a
  /// slower poll would let a character or two through first. Two cheap reads at
  /// this rate cost nothing measurable.
  static const Duration _pollInterval = Duration(milliseconds: 50);

  ValuePoller<bool>? _inputSourcePoller;
  ValuePoller<bool>? _capsLockPoller;

  /// The macOS input-source stream. Notification-driven, so it has no interval
  /// and is not a [ValuePoller].
  ChangeStream<bool>? _inputSourceChanges;

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
    _macosIme?.setEnglishKeyboard();
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
  /// [disableIME], which leaves no context to read — and on macOS when there is
  /// no readable current input source.
  ///
  /// **The macOS answer differs from 2.x** for every English layout that is not
  /// ABC or US. `isEnglishInputSource` records why.
  @override
  Future<bool> isEnglishKeyboard() async {
    final windows = _windowsIme;
    if (windows != null) return windows.isEnglishKeyboard();
    return _macosIme?.isEnglishKeyboard() ?? false;
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
    return _macosIme?.getCurrentInputSource();
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
    _macosIme?.setInputSource(sourceId);
  }

  /// Disables the IME so composition cannot start in the app window.
  ///
  /// Windows only; a no-op on macOS, as in 2.x.
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
    _windowsIme?.disableIme();
  }

  /// Restores normal IME functionality after [disableIME]. Windows only.
  ///
  /// Does nothing if the target window cannot be resolved, and — like
  /// [disableIME] — reports that by staying silent rather than raising, where
  /// 2.x raised a `PlatformException`.
  @override
  Future<void> enableIME() async {
    _windowsIme?.enableIme();
  }

  /// Whether Caps Lock is currently on.
  ///
  /// **Differs from 2.x on macOS**, where this now reads hardware modifier
  /// state rather than watching for modifier-key events. See `CoreGraphics`.
  @override
  Future<bool> isCapsLockOn() async {
    final windows = _windowsIme;
    if (windows != null) return windows.isCapsLockOn();
    return _macosIme?.isCapsLockOn() ?? false;
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
    return const Stream<bool>.empty();
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
    if (windows == null && macos == null) return const Stream<bool>.empty();
    return (_capsLockPoller ??= ValuePoller<bool>(
      read: windows != null ? windows.isCapsLockOn : macos!.isCapsLockOn,
      interval: _pollInterval,
    ))
        .stream;
  }
}
