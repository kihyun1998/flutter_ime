import 'flutter_ime_platform_interface.dart';
import 'src/platform_support.dart';

/// Changes the IME (Input Method Editor) to English mode.
///
/// This is useful for text fields that require English-only input,
/// such as password fields, code editors, or ID fields.
///
/// ## Platform Support
/// - **Windows**: Sets the IME conversion mode to alphanumeric
/// - **macOS**: Selects the ABC layout, if the user has it enabled. Enabling a
///   layout the user never added would put a keyboard in their input menu they
///   did not ask for, so this stays within what they already have.
/// - **Other platforms**: Does nothing (no-op)
///
/// Failure is silent: if there is no window to act on, or the switch is
/// refused, nothing happens and nothing is raised. 2.x reported these as a
/// `PlatformException`.
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
  if (!platformSupport.isSupported) return;

  await FlutterImePlatform.instance.setEnglishKeyboard();
}

/// Checks if the current IME is in English mode.
///
/// Use this to verify the keyboard state before accepting input
/// or to display a warning to the user.
///
/// **This means something different on each platform**, and always has:
/// - **Windows**: the IME is not in native-language conversion mode. A Korean
///   keyboard in alphanumeric mode answers `true`.
/// - **macOS**: the selected layout types English. Asked of the layout itself,
///   so Dvorak, Colemak, British, Australian and Canadian all answer `true` —
///   2.x recognised only ABC and US and answered `false` for the rest.
/// - **Other platforms**: always `false`
///
/// ## Returns
/// - `true` if the current keyboard is in English mode
/// - `false` if non-English (e.g., Korean, Japanese), if the state cannot be
///   read, or on an unsupported platform
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
  if (!platformSupport.isSupported) return false;

  return FlutterImePlatform.instance.isEnglishKeyboard();
}

/// Gets the current input source as an opaque token.
///
/// Returns a token identifying the currently active keyboard input source.
/// Save it as-is and later restore it with [setInputSource].
///
/// **Treat the value as opaque**: it is platform-specific and its format is an
/// implementation detail. Do not parse, compare, or construct it yourself. The
/// examples below are illustrative only.
///
/// The format is unchanged from 2.x, so a token your app saved before
/// upgrading still restores afterwards.
///
/// ## Platform Support
/// - **macOS**: Returns input source ID (e.g., "com.apple.keylayout.ABC",
///   "com.apple.inputmethod.Korean.2SetKorean")
/// - **Windows**: Returns keyboard layout and IME state in format "KLID:conversion:sentence"
///   (e.g., "00000412:1:0" for Korean keyboard in Hangul mode)
/// - **Other platforms**: Returns `null`
///
/// ## Returns
/// - Input source ID string on supported platforms
/// - `null` on unsupported platforms or if unable to get input source
///
/// ## Example
/// ```dart
/// // Save current keyboard before switching to English
/// final savedInputSource = await getCurrentInputSource();
/// await setEnglishKeyboard();
///
/// // Later, restore the previous keyboard
/// if (savedInputSource != null) {
///   await setInputSource(savedInputSource);
/// }
/// ```
///
/// See also:
/// - [setInputSource] to restore a saved input source
/// - [setEnglishKeyboard] to switch to English mode
Future<String?> getCurrentInputSource() async {
  if (!platformSupport.isSupported) return null;

  return FlutterImePlatform.instance.getCurrentInputSource();
}

/// Restores a keyboard input source from an opaque token.
///
/// Use this to restore a token previously saved from [getCurrentInputSource].
/// Pass the saved token back unchanged — do not construct or modify it. The
/// token's format is platform-specific and may change between releases.
///
/// ## Platform Support
/// - **Windows**: Loads the keyboard layout and restores the IME conversion
///   mode the token carried
/// - **macOS**: Selects the input source, **enabling it first if the user has
///   it installed but not enabled**. That adds a keyboard to their input menu
///   and persists after your app exits. It is what makes restoring reliable —
///   the source was theirs to begin with — but pass only tokens that came from
///   [getCurrentInputSource], never ones a user or a server supplied.
/// - **Other platforms**: Does nothing (no-op)
///
/// Failure is silent: a malformed token, or a layout that no longer exists on
/// the machine, does nothing and raises nothing. Tokens come back from your own
/// storage and can go stale, so a failed restore is expected rather than
/// exceptional. 2.x reported these as a `PlatformException`.
///
/// ## Parameters
/// - [sourceId]: The input source ID to activate
///   - macOS: e.g., "com.apple.keylayout.ABC"
///   - Windows: e.g., "00000412:1:0" (KLID:conversion:sentence)
///
/// ## Example
/// ```dart
/// // Save and restore keyboard around English-only input
/// String? savedInputSource;
///
/// focusNode.addListener(() async {
///   if (focusNode.hasFocus) {
///     savedInputSource = await getCurrentInputSource();
///     await setEnglishKeyboard();
///   } else {
///     if (savedInputSource != null) {
///       await setInputSource(savedInputSource!);
///     }
///   }
/// });
/// ```
///
/// See also:
/// - [getCurrentInputSource] to get the current input source ID
/// - [setEnglishKeyboard] to switch to English mode
Future<void> setInputSource(String sourceId) async {
  if (!platformSupport.isSupported) return;

  await FlutterImePlatform.instance.setInputSource(sourceId);
}

/// Detaches the IME from the app window, so composition cannot start.
///
/// Stronger than [setEnglishKeyboard], which only changes the current mode and
/// leaves the user free to change it back. With the IME context detached there
/// is nothing to compose with, so switching to a Korean or Japanese keyboard
/// and typing produces nothing.
///
/// **It does not prevent pasted or programmatically injected text.** Nothing
/// here touches the clipboard: paste never travels the keyboard path, so
/// `Ctrl+V` puts Korean into the field whatever this call did. The same was
/// true in 2.x — that version's documentation claimed non-English input was
/// "impossible", which it never was. If you need a guarantee about the *value*
/// of a field rather than about typing, filter it in Dart with an
/// `inputFormatter`; that catches paste too.
///
/// **Important**: Always call [enableIME] when the text field loses focus,
/// or the IME stays detached for the rest of the app's life.
///
/// ## Platform Support
/// - **Windows only**: Detaches the window's IME context
/// - **macOS**: Not supported (use [setEnglishKeyboard] + [onInputSourceChanged]
///   instead)
/// - **Other platforms**: Does nothing (no-op)
///
/// Failure is silent, and there is one case worth knowing: if the package
/// cannot positively identify a window belonging to this process, it refuses
/// rather than guessing. Detaching an IME context is not undone by anything
/// except [enableIME], so acting on a window that turned out to be another
/// application's would disable the IME where the user is actually typing.
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
  if (!platformSupport.isWindowsOnly) return;

  await FlutterImePlatform.instance.disableIME();
}

/// Enables IME, restoring normal input method functionality.
///
/// Call this after [disableIME] to restore the user's ability
/// to type in non-English characters.
///
/// ## Platform Support
/// - **Windows only**: Restores the window's default IME context
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
  if (!platformSupport.isWindowsOnly) return;

  await FlutterImePlatform.instance.enableIME();
}

/// A stream that emits when the input source (keyboard layout) changes.
///
/// This allows you to react to user's keyboard switching in real-time.
/// Useful for enforcing English-only input by reverting changes.
///
/// **Emits only on a change, and not the value you started from.** Subscribing
/// captures the current state as a baseline and stays silent until it moves;
/// use [isEnglishKeyboard] for the value right now. Two switches that land on
/// the same answer — Korean to Japanese, say — emit once, not twice. 2.x
/// emitted on every keyboard-change message, including repeats.
///
/// [disableIME] and [enableIME] do not emit. While the IME context is detached
/// the state is unreadable rather than non-English, and announcing a switch
/// that never happened would fight the "force English" recipe below.
///
/// ## Platform Support
/// - **Windows**: polled a few times a second. There is no callback the OS can
///   hand a Dart isolate that also returns a value synchronously, which is what
///   a window procedure needs, so polling is the honest option.
/// - **macOS**: pushed, from the system notification. A notification callback
///   returns nothing, so there is no such constraint.
/// - **Other platforms**: Returns an empty stream
///
/// Nothing is polled or observed until you listen, and it stops again when the
/// last listener cancels.
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
  if (!platformSupport.isSupported) {
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
/// - **Windows**: reads the Caps Lock toggle state
/// - **macOS**: reads hardware modifier state, which needs no Accessibility
///   permission. 2.x used an event monitor that silently delivered nothing
///   unless the user had granted one.
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
  if (!platformSupport.isSupported) return false;

  return FlutterImePlatform.instance.isCapsLockOn();
}

/// A stream that emits when Caps Lock state changes.
///
/// Use this to show or hide a Caps Lock warning indicator in real-time.
///
/// Like [onInputSourceChanged], this emits only on a change and not the state
/// you started from — use [isCapsLockOn] for that — and nothing is polled until
/// you listen.
///
/// **On macOS a language switch can report a Caps Lock toggle.** The Caps Lock
/// key doubles as the input-source switch there, so changing language really
/// does turn the lock on and off again, for about twelve milliseconds. This
/// reports it because it happened. If you drive a warning indicator from this
/// stream, expect it to flicker when the user switches language; there is no
/// state that distinguishes the two cases, only duration.
///
/// ## Platform Support
/// - **Windows**: polled a few times a second
/// - **macOS**: polled a few times a second
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
  if (!platformSupport.isSupported) {
    return const Stream.empty();
  }

  return FlutterImePlatform.instance.onCapsLockChanged;
}
