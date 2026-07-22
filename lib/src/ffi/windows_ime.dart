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

  /// Runs [body] against [window]'s IME context, releasing the context on every
  /// exit path.
  ///
  /// Takes an already-resolved window rather than resolving one itself, so a
  /// single operation always targets a single window. Resolving twice within
  /// one call would let the answer change in between — the layout could be read
  /// from one window and the conversion state from another.
  ///
  /// Returns null when the window has no IME context. A detached context is the
  /// normal state while the IME is disabled, so null means "nothing to do", not
  /// "something broke".
  T? _withImeContext<T>(
      ResolvedWindow window, T Function(Handle32 context) body) {
    if (!window.isUsable) return null;

    final context = _win32.immGetContext(window.handle);
    if (context == nullptr) return null;
    try {
      return body(context);
    } finally {
      _win32.immReleaseContext(window.handle, context);
    }
  }

  /// Reads the IME conversion and sentence modes, or null if unavailable.
  ({int conversion, int sentence})? _readConversionStatus(Handle32 context) {
    // One allocation for both out-parameters. Two separate allocations would
    // leave a window where the second one throwing leaks the first.
    final out = calloc<Uint32>(2);
    try {
      if (_win32.immGetConversionStatus(context, out, out + 1) == 0) {
        return null;
      }
      return (conversion: out.value, sentence: (out + 1).value);
    } finally {
      calloc.free(out);
    }
  }

  /// Switches the IME to alphanumeric conversion mode.
  ///
  /// Returns false when the switch could not be performed, including when
  /// there is no resolvable window or no IME context.
  bool setEnglishKeyboard() {
    final window = _resolver.resolve();
    return _withImeContext(
            window,
            (context) =>
                _win32.immSetConversionStatus(
                    context, imeCmodeAlphanumeric, imeSmodeNone) !=
                0) ??
        false;
  }

  /// Whether the IME is currently in English (non-native) conversion mode.
  ///
  /// Returns false when there is no window or no IME context, matching the
  /// native plugin's behaviour.
  bool isEnglishKeyboard() {
    final window = _resolver.resolve();
    final status = _withImeContext(window, _readConversionStatus);
    if (status == null) return false;
    return isEnglishConversionMode(status.conversion);
  }

  /// Reads the current keyboard layout and IME conversion state as an opaque
  /// token, or null if the layout could not be read.
  ///
  /// Degraded paths mirror the native plugin: a failed layout read yields null,
  /// and a window with no IME context yields a layout-only token, which still
  /// round-trips through [setInputSource].
  String? getCurrentInputSource() {
    final window = _resolver.resolve();
    if (!window.isUsable) return null;

    final klid = _readKeyboardLayoutName();
    if (klid == null) return null;

    final context = _win32.immGetContext(window.handle);
    if (context == nullptr) return klid;
    try {
      // The native plugin ignores whether the status read succeeded and formats
      // the out-parameters regardless, so a failed read yields ":0:0" rather
      // than a layout-only token. Matched deliberately: the two tokens restore
      // differently — one forces alphanumeric mode, the other leaves the
      // conversion state alone — and this must produce the same token 2.x did
      // for the same keyboard state.
      final status =
          _readConversionStatus(context) ?? (conversion: 0, sentence: 0);
      return formatInputSourceToken(klid, status.conversion, status.sentence);
    } finally {
      _win32.immReleaseContext(window.handle, context);
    }
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
      _withImeContext(
          window,
          (context) => _win32.immSetConversionStatus(
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
}
