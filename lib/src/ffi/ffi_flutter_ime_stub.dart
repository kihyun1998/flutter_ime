/// Stand-in for the FFI implementation on platforms without `dart:ffi`.
///
/// Web is the case that matters. A `dart:ffi` import anywhere in the reachable
/// library graph fails the web compile outright — verified against this
/// package, where `dart:io` compiles fine for web but `dart:ffi` does not. The
/// conditional import in `flutter_ime_platform_interface.dart` selects this
/// file instead, so a consumer building for web keeps working.
///
/// **Constructing it is safe; calling it is not.** It is the default instance
/// on web, so it is built on startup whether or not anything uses it. Nothing
/// ever calls it: every public function in `flutter_ime.dart` consults the
/// platform-support policy first, and web is not a supported platform.
/// Throwing rather than quietly returning a default keeps that a fact rather
/// than a hope — if the gating ever regresses, the web build says so instead of
/// silently reporting that no keyboard is English.
///
/// The throws are **synchronous**, which is why none of these are `async`. An
/// `async` method that throws hands back a failed future, and every one of
/// these is routinely called fire-and-forget from a focus listener — so the
/// failure would surface as an unhandled async error in the consumer's zone,
/// far from the call, rather than at the line that made it. This is the one
/// place in the package that raises at all, so it may as well raise where
/// somebody can see it.
library;

import '../../flutter_ime_platform_interface.dart';

/// Web-safe stand-in that mirrors the real implementation's surface.
class FfiFlutterIme extends FlutterImePlatform {
  FfiFlutterIme();

  Never _unsupported(String operation) => throw UnsupportedError(
        'flutter_ime cannot reach an IME on this platform, so $operation has '
        'no implementation here. Reaching this means the platform gating in '
        'flutter_ime.dart was bypassed — call the top-level functions rather '
        'than the platform interface.',
      );

  @override
  Future<void> setEnglishKeyboard() => _unsupported('setEnglishKeyboard');

  @override
  Future<bool> isEnglishKeyboard() => _unsupported('isEnglishKeyboard');

  @override
  Future<String?> getCurrentInputSource() =>
      _unsupported('getCurrentInputSource');

  @override
  Future<void> setInputSource(String sourceId) =>
      _unsupported('setInputSource');

  @override
  Future<void> disableIME() => _unsupported('disableIME');

  @override
  Future<void> enableIME() => _unsupported('enableIME');

  @override
  Future<bool> isCapsLockOn() => _unsupported('isCapsLockOn');

  @override
  Stream<bool> get onInputSourceChanged => _unsupported('onInputSourceChanged');

  @override
  Stream<bool> get onCapsLockChanged => _unsupported('onCapsLockChanged');
}
