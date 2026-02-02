import 'dart:io';

import 'flutter_ime_platform_interface.dart';

/// Changes the IME (Input Method Editor) to English mode.
///
/// This is useful for text fields that require English-only input,
/// such as password fields, code editors, or ID fields.
///
/// ## Platform Support
/// - **Windows**: Uses IMM32 API to set conversion mode to alphanumeric
/// - **macOS**: Switches to ABC keyboard layout
/// - **Other platforms**: Does nothing (no-op)
///
/// ## Example
/// ```dart
/// // Switch to English when password field gains focus
/// FocusNode passwordFocus = FocusNode();
/// passwordFocus.addListener(() {
///   if (passwordFocus.hasFocus) {
///     setEnglishKeyboard();
///   }
/// });
/// ```
///
/// See also:
/// - [isEnglishKeyboard] to check current keyboard state
/// - [onInputSourceChanged] to monitor keyboard changes
Future<void> setEnglishKeyboard() async {
  if (!Platform.isWindows && !Platform.isMacOS) return;

  await FlutterImePlatform.instance.setEnglishKeyboard();
}

/// Checks if the current IME is in English mode.
///
/// Use this to verify the keyboard state before accepting input
/// or to display a warning to the user.
///
/// ## Platform Support
/// - **Windows**: Checks IME conversion mode via IMM32 API
/// - **macOS**: Checks if current input source is ABC or US keyboard
/// - **Other platforms**: Always returns `false`
///
/// ## Returns
/// - `true` if the current keyboard is in English mode
/// - `false` if non-English (e.g., Korean, Japanese) or unsupported platform
///
/// ## Example
/// ```dart
/// final isEnglish = await isEnglishKeyboard();
/// if (!isEnglish) {
///   showWarning('Please switch to English keyboard');
/// }
/// ```
///
/// See also:
/// - [setEnglishKeyboard] to switch to English mode
/// - [onInputSourceChanged] to monitor keyboard changes
Future<bool> isEnglishKeyboard() async {
  if (!Platform.isWindows && !Platform.isMacOS) return false;

  return FlutterImePlatform.instance.isEnglishKeyboard();
}

/// Disables IME completely, preventing non-English input.
///
/// Unlike [setEnglishKeyboard], this completely blocks IME functionality,
/// making it impossible for users to type in non-English characters
/// even if they try to switch keyboard layouts.
///
/// **Important**: Always call [enableIME] when the text field loses focus
/// to restore normal IME functionality.
///
/// ## Platform Support
/// - **Windows only**: Blocks IME messages via WndProc hook and detaches IME context
/// - **macOS**: Not supported (use [setEnglishKeyboard] + [onInputSourceChanged] instead)
/// - **Other platforms**: Does nothing (no-op)
///
/// ## Example
/// ```dart
/// FocusNode focusNode = FocusNode();
/// focusNode.addListener(() {
///   if (focusNode.hasFocus) {
///     disableIME();
///   } else {
///     enableIME();
///   }
/// });
/// ```
///
/// See also:
/// - [enableIME] to restore IME functionality
/// - [setEnglishKeyboard] for a less restrictive approach
Future<void> disableIME() async {
  if (!Platform.isWindows) return;

  await FlutterImePlatform.instance.disableIME();
}

/// Enables IME, restoring normal input method functionality.
///
/// Call this after [disableIME] to restore the user's ability
/// to type in non-English characters.
///
/// ## Platform Support
/// - **Windows only**: Restores IME context and stops blocking IME messages
/// - **Other platforms**: Does nothing (no-op)
///
/// ## Example
/// ```dart
/// // Restore IME when leaving a restricted text field
/// focusNode.addListener(() {
///   if (!focusNode.hasFocus) {
///     enableIME();
///   }
/// });
/// ```
///
/// See also:
/// - [disableIME] to disable IME
Future<void> enableIME() async {
  if (!Platform.isWindows) return;

  await FlutterImePlatform.instance.enableIME();
}

/// A stream that emits when the input source (keyboard layout) changes.
///
/// This allows you to react to user's keyboard switching in real-time.
/// Useful for enforcing English-only input by reverting changes.
///
/// ## Platform Support
/// - **Windows**: Monitors `WM_INPUTLANGCHANGE` and `WM_IME_NOTIFY` messages
/// - **macOS**: Monitors `kTISNotifySelectedKeyboardInputSourceChanged` notification
/// - **Other platforms**: Returns an empty stream
///
/// ## Emits
/// - `true` when switched to English keyboard
/// - `false` when switched to non-English keyboard (e.g., Korean)
///
/// ## Example
/// ```dart
/// // Force English keyboard - revert any language switch
/// StreamSubscription? subscription;
///
/// focusNode.addListener(() {
///   if (focusNode.hasFocus) {
///     setEnglishKeyboard();
///     subscription = onInputSourceChanged().listen((isEnglish) {
///       if (!isEnglish) {
///         setEnglishKeyboard(); // Revert to English
///       }
///     });
///   } else {
///     subscription?.cancel();
///   }
/// });
/// ```
///
/// See also:
/// - [setEnglishKeyboard] to switch to English mode
/// - [isEnglishKeyboard] to check current state
Stream<bool> onInputSourceChanged() {
  if (!Platform.isWindows && !Platform.isMacOS) {
    return const Stream.empty();
  }

  return FlutterImePlatform.instance.onInputSourceChanged;
}

/// Checks if Caps Lock is currently on.
///
/// Useful for password fields to warn users that Caps Lock is enabled,
/// which might cause unintended uppercase input.
///
/// ## Platform Support
/// - **Windows**: Uses `GetKeyState(VK_CAPITAL)` API
/// - **macOS**: Uses `NSEvent.modifierFlags`
/// - **Other platforms**: Always returns `false`
///
/// ## Returns
/// - `true` if Caps Lock is on
/// - `false` if Caps Lock is off or platform is unsupported
///
/// ## Example
/// ```dart
/// final isCapsLock = await isCapsLockOn();
/// if (isCapsLock) {
///   showWarning('Caps Lock is ON');
/// }
/// ```
///
/// See also:
/// - [onCapsLockChanged] to monitor Caps Lock state changes
Future<bool> isCapsLockOn() async {
  if (!Platform.isWindows && !Platform.isMacOS) return false;

  return FlutterImePlatform.instance.isCapsLockOn();
}

/// A stream that emits when Caps Lock state changes.
///
/// Use this to show or hide a Caps Lock warning indicator in real-time.
///
/// ## Platform Support
/// - **Windows**: Monitors `WM_KEYDOWN`/`WM_KEYUP` for `VK_CAPITAL`
/// - **macOS**: Monitors `NSEvent.flagsChanged` for `.capsLock`
/// - **Other platforms**: Returns an empty stream
///
/// ## Emits
/// - `true` when Caps Lock is turned on
/// - `false` when Caps Lock is turned off
///
/// ## Example
/// ```dart
/// // Show Caps Lock warning in password field
/// bool showCapsLockWarning = false;
/// StreamSubscription? subscription;
///
/// passwordFocusNode.addListener(() async {
///   if (passwordFocusNode.hasFocus) {
///     // Check initial state
///     showCapsLockWarning = await isCapsLockOn();
///     setState(() {});
///
///     // Monitor changes
///     subscription = onCapsLockChanged().listen((isOn) {
///       setState(() {
///         showCapsLockWarning = isOn;
///       });
///     });
///   } else {
///     subscription?.cancel();
///     setState(() {
///       showCapsLockWarning = false;
///     });
///   }
/// });
/// ```
///
/// See also:
/// - [isCapsLockOn] to check current state
Stream<bool> onCapsLockChanged() {
  if (!Platform.isWindows && !Platform.isMacOS) {
    return const Stream.empty();
  }

  return FlutterImePlatform.instance.onCapsLockChanged;
}
