/// Stand-in for the FFI implementation on platforms without `dart:ffi`.
///
/// Web is the case that matters. A `dart:ffi` import anywhere in the reachable
/// library graph fails the web compile outright — verified against this
/// package, where `dart:io` compiles fine for web but `dart:ffi` does not. The
/// conditional import in `flutter_ime_ffi.dart` selects this file instead, so
/// a consumer building for web keeps working.
///
/// Nothing constructs this in practice: the platform gating in the public API
/// short-circuits before reaching any implementation on unsupported platforms.
library;

import '../../flutter_ime_platform_interface.dart';

/// Web-safe stand-in that mirrors the real implementation's surface.
class FfiFlutterIme extends FlutterImePlatform {
  FfiFlutterIme();

  Never _unsupported() => throw UnsupportedError(
      'flutter_ime has no FFI implementation on this platform.');

  /// Always null here; the real implementation reports the resolved window.
  String? describeResolvedWindow() => null;

  @override
  Future<void> setEnglishKeyboard() async => _unsupported();

  @override
  Future<bool> isEnglishKeyboard() async => _unsupported();
}
