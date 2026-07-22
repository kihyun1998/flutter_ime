/// Windows IME operations expressed directly against IMM32.
///
/// A thin adapter: acquire a handle, make one system call, release what was
/// acquired, and hand any interpretation to a pure function. There is
/// deliberately no logic here beyond null guards, because nothing in this file
/// can be unit-tested without a live IME.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ime_conversion_mode.dart';
import '../input_source_token.dart';
import 'win32.dart';
import 'window_resolver.dart';

class WindowsIme {
  WindowsIme({Win32? win32, WindowResolver? resolver})
      : _win32 = win32 ?? Win32.instance,
        _resolver = resolver ?? WindowResolver();

  final Win32 _win32;
  final WindowResolver _resolver;

  /// Resolves the window these calls target, searching the window tree if the
  /// answer is not already cached.
  ///
  /// A method rather than a getter because it does real work: on a cache miss
  /// it walks the process's top-level windows. Do not call it from a `build`.
  ResolvedWindow resolveWindow() => _resolver.resolve();

  /// Runs [body] against the window's IME context, releasing the context on
  /// every exit path.
  ///
  /// Returns null when there is no window to target or the window has no IME
  /// context. A detached context is the normal state while the IME is
  /// disabled, so null here means "nothing to do", not "something broke".
  T? _withImeContext<T>(T Function(Handle32 context) body) {
    final window = _resolver.resolve();
    if (!window.isUsable) return null;

    final context = _win32.immGetContext(window.handle);
    if (context == nullptr) return null;
    try {
      return body(context);
    } finally {
      _win32.immReleaseContext(window.handle, context);
    }
  }

  /// Switches the IME to alphanumeric conversion mode.
  ///
  /// Returns false when the switch could not be performed, including when
  /// there is no resolvable window or no IME context.
  bool setEnglishKeyboard() =>
      _withImeContext((context) =>
          _win32.immSetConversionStatus(
              context, imeCmodeAlphanumeric, imeSmodeNone) !=
          0) ??
      false;

  /// Reads the current keyboard layout and IME conversion state as an opaque
  /// token, or null if the layout could not be read.
  ///
  /// Mirrors the native plugin exactly, including its two degraded paths: a
  /// failed layout read yields null, and a window with no IME context yields a
  /// layout-only token rather than nothing.
  String? getCurrentInputSource() {
    final window = _resolver.resolve();
    if (!window.isUsable) return null;

    final klid = _readKeyboardLayoutName();
    if (klid == null) return null;

    final conversion = _withImeContext((context) {
      final out = calloc<Uint32>(2);
      try {
        if (_win32.immGetConversionStatus(context, out, out + 1) == 0) {
          return null;
        }
        return formatInputSourceToken(klid, out.value, (out + 1).value);
      } finally {
        calloc.free(out);
      }
    });

    // No IME context, or the status read failed: the layout alone is still
    // worth handing back, and it round-trips through setInputSource.
    return conversion ?? klid;
  }

  /// Restores a keyboard layout, and the IME conversion state if the token
  /// carries any. Returns false if the token is malformed or the layout could
  /// not be loaded.
  bool setInputSource(String sourceId) {
    // Parse before touching the OS, so a malformed token costs nothing and can
    // never reach a system call.
    final token = parseInputSourceToken(sourceId);
    if (token == null) return false;

    final window = _resolver.resolve();
    if (!window.isUsable) return false;

    final klidPtr = token.klid.toNativeUtf8(allocator: calloc);
    try {
      if (_win32.loadKeyboardLayout(klidPtr, klfActivate) == nullptr) {
        return false;
      }
    } finally {
      calloc.free(klidPtr);
    }

    if (token.hasConversion) {
      _withImeContext((context) => _win32.immSetConversionStatus(
          context, token.conversion!, token.sentence!));
    }
    // The layout switched, which is the part that always applies. Conversion
    // state is best-effort: a window with no IME context has none to restore.
    return true;
  }

  /// Reads the active keyboard layout identifier, or null if unavailable.
  String? _readKeyboardLayoutName() {
    final buffer = calloc<Uint8>(klNameLength);
    try {
      if (_win32.getKeyboardLayoutName(buffer.cast<Utf8>()) == 0) return null;
      return buffer.cast<Utf8>().toDartString();
    } finally {
      calloc.free(buffer);
    }
  }

  /// Whether the IME is currently in English (non-native) conversion mode.
  ///
  /// Returns false when there is no window or no IME context, matching the
  /// native plugin's behaviour.
  bool isEnglishKeyboard() =>
      _withImeContext((context) {
        // One allocation for both out-parameters. Two separate allocations
        // would leave a window where the second one throwing leaks the first.
        final out = calloc<Uint32>(2);
        try {
          if (_win32.immGetConversionStatus(context, out, out + 1) == 0) {
            return false;
          }
          return isEnglishConversionMode(out.value);
        } finally {
          calloc.free(out);
        }
      }) ??
      false;
}
