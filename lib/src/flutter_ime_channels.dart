/// Single source of truth for the platform-channel contract between the Dart
/// layer and the native plugins.
///
/// The method-channel implementation ([MethodChannelFlutterIme]) references
/// these constants instead of inline string literals, so the channel/method/
/// argument names live in exactly one place on the Dart side.
///
/// The native implementations must mirror these exact strings:
/// - macOS: `macos/Classes/FlutterImePlugin.swift`
/// - Windows: `windows/flutter_ime_plugin.cpp`
///
/// A change here is a breaking change to that contract and must be applied to
/// both native plugins in the same commit.
library;

/// Names of the platform channels used by the plugin.
abstract final class ImeChannels {
  /// Method channel for one-shot IME operations.
  static const String method = 'flutter_ime';

  /// Event channel that streams input-source (keyboard layout) changes.
  static const String inputSourceChangedEvent =
      'flutter_ime/input_source_changed';

  /// Event channel that streams Caps Lock state changes.
  static const String capsLockChangedEvent = 'flutter_ime/caps_lock_changed';
}

/// Method names invoked on [ImeChannels.method].
abstract final class ImeMethods {
  /// Switches the IME to English mode.
  static const String setEnglishKeyboard = 'setEnglishKeyboard';

  /// Checks whether the IME is currently in English mode.
  static const String isEnglishKeyboard = 'isEnglishKeyboard';

  /// Reads the current input-source token.
  static const String getCurrentInputSource = 'getCurrentInputSource';

  /// Restores an input source from a previously saved token.
  static const String setInputSource = 'setInputSource';

  /// Disables the IME entirely (Windows only).
  static const String disableIme = 'disableIME';

  /// Re-enables the IME (Windows only).
  static const String enableIme = 'enableIME';

  /// Checks whether Caps Lock is currently on.
  static const String isCapsLockOn = 'isCapsLockOn';
}

/// Argument keys passed alongside method invocations.
abstract final class ImeArguments {
  /// Key for the input-source token passed to [ImeMethods.setInputSource].
  static const String sourceId = 'sourceId';
}
