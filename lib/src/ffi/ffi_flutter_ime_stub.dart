/// Stand-in for the FFI implementation on platforms without `dart:ffi`.
///
/// Web is the case that matters. A `dart:ffi` import anywhere in the reachable
/// library graph fails the web compile outright — verified against this
/// package, where `dart:io` compiles fine for web but `dart:ffi` does not. The
/// conditional import in `flutter_ime_ffi.dart` selects this file instead, so
/// a consumer building for web keeps working.
///
/// Mirrors the real implementation's shape: nothing is ported here, so every
/// call falls through to the native plugin exactly as it does on a platform the
/// FFI implementation does not cover yet. Nothing constructs this in practice —
/// the platform gating in the public API short-circuits first.
library;

import '../../flutter_ime_method_channel.dart';
import '../../flutter_ime_platform_interface.dart';

/// Web-safe stand-in that mirrors the real implementation's surface.
class FfiFlutterIme extends FlutterImePlatform {
  FfiFlutterIme({FlutterImePlatform? fallback})
      : _fallback = fallback ?? MethodChannelFlutterIme();

  final FlutterImePlatform _fallback;

  /// Always null here; the real implementation reports the resolved window.
  String? describeResolvedWindow() => null;

  /// Always null here; the real implementation reports the selected macOS
  /// input source.
  String? describeCurrentInputSource() => null;

  @override
  Future<void> setEnglishKeyboard() => _fallback.setEnglishKeyboard();

  @override
  Future<bool> isEnglishKeyboard() => _fallback.isEnglishKeyboard();

  @override
  Future<String?> getCurrentInputSource() => _fallback.getCurrentInputSource();

  @override
  Future<void> setInputSource(String sourceId) =>
      _fallback.setInputSource(sourceId);

  @override
  Future<void> disableIME() => _fallback.disableIME();

  @override
  Future<void> enableIME() => _fallback.enableIME();

  @override
  Future<bool> isCapsLockOn() => _fallback.isCapsLockOn();

  @override
  Stream<bool> get onInputSourceChanged => _fallback.onInputSourceChanged;

  @override
  Stream<bool> get onCapsLockChanged => _fallback.onCapsLockChanged;
}
