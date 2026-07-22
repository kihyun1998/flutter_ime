/// Windows IME operations expressed directly against IMM32.
///
/// A thin adapter: it acquires a handle, makes one system call, releases what
/// it acquired, and hands any interpretation to a pure function. There is
/// deliberately no logic here beyond null guards, because nothing in this file
/// can be unit-tested without a live IME.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../ime_conversion_mode.dart';
import 'win32.dart';
import 'window_resolver.dart';

class WindowsIme {
  WindowsIme({Win32? win32, WindowResolver? resolver})
      : _win32 = win32 ?? Win32.instance,
        _resolver = resolver ?? WindowResolver();

  final Win32 _win32;
  final WindowResolver _resolver;

  /// Which window the last call targeted, for diagnostics.
  ResolvedWindow get lastResolution => _resolver.resolve();

  /// Switches the IME to alphanumeric conversion mode.
  ///
  /// Returns false when there is no window to target or the window has no IME
  /// context — the latter is the normal state while the IME is disabled.
  bool setEnglishKeyboard() {
    final window = _resolver.resolve();
    if (!window.isUsable) return false;

    final context = _win32.immGetContext(window.handle);
    if (context == nullptr) return false;
    try {
      return _win32.immSetConversionStatus(
              context, imeCmodeAlphanumeric, imeSmodeNone) !=
          0;
    } finally {
      _win32.immReleaseContext(window.handle, context);
    }
  }

  /// Whether the IME is currently in English (non-native) conversion mode.
  ///
  /// Returns false when there is no window or no IME context, matching the
  /// native plugin's behaviour.
  bool isEnglishKeyboard() {
    final window = _resolver.resolve();
    if (!window.isUsable) return false;

    final context = _win32.immGetContext(window.handle);
    if (context == nullptr) return false;

    final conversion = calloc<Uint32>();
    final sentence = calloc<Uint32>();
    try {
      if (_win32.immGetConversionStatus(context, conversion, sentence) == 0) {
        return false;
      }
      return isEnglishConversionMode(conversion.value);
    } finally {
      calloc.free(conversion);
      calloc.free(sentence);
      _win32.immReleaseContext(window.handle, context);
    }
  }
}
