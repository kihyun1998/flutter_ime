import 'dart:io';

import 'package:flutter/foundation.dart';

/// Single source of truth for which platforms the plugin supports.
///
/// The public API in `flutter_ime.dart` consults [platformSupport] instead of
/// checking [Platform] directly in every function, so the supported-platform
/// policy lives in exactly one place and can be overridden in tests via
/// [debugSetPlatformSupport].
class PlatformSupport {
  const PlatformSupport();

  /// Whether the current platform has IME support at all (macOS or Windows).
  bool get isSupported => Platform.isMacOS || Platform.isWindows;

  /// Whether the current platform supports the Windows-only features
  /// ([disableIME] / [enableIME]).
  bool get isWindowsOnly => Platform.isWindows;
}

PlatformSupport _platformSupport = const PlatformSupport();

/// The active platform-support policy consulted by the public API.
PlatformSupport get platformSupport => _platformSupport;

/// Overrides the active [platformSupport] policy for tests. Passing `null`
/// restores the real, [Platform]-backed policy.
@visibleForTesting
void debugSetPlatformSupport(PlatformSupport? value) {
  _platformSupport = value ?? const PlatformSupport();
}
