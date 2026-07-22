# flutter_ime

Control the IME (Input Method Editor) from Dart on Windows and macOS — switch to an English keyboard, watch for keyboard changes, and read Caps Lock. Most useful for login forms and other fields where English input is expected.

[![pub package](https://img.shields.io/pub/v/flutter_ime.svg)](https://pub.dev/packages/flutter_ime)

**No native code and no build step.** As of 3.0.0 this is a plain Dart package that calls the system libraries through `dart:ffi`. There is no plugin to register, no CMake or CocoaPods involved, and nothing for your build to compile — adding it cannot break your build the way a plugin's native layer can. It works from a plain Dart program too, not only from Flutter.

## Features

* Switch to an English keyboard on Windows and macOS
* Check the current keyboard mode
* Disable and re-enable the IME (Windows only)
* Watch for keyboard layout changes
* Read Caps Lock and watch it change
* Safe to call on any platform — unsupported ones return documented defaults

## Getting started

```yaml
dependencies:
  flutter_ime: ^3.0.0
```

### Upgrading from 2.x

The API is unchanged: every function keeps its name, parameters and return type, and saved input-source tokens still restore. Most apps upgrade by changing the version constraint.

Four behaviours did change. They are listed in the [CHANGELOG](CHANGELOG.md); the two most likely to matter are that failures are now silent rather than raising a `PlatformException`, and that on macOS `isEnglishKeyboard()` now answers `true` for English layouts other than ABC and US.

2.x is frozen but stays published, so `flutter_ime: ^2.1.4` keeps working if you need it. It is not more capable — see the note under [Disable IME](#disable-ime-windows-only) — just older.

## Usage

```dart
import 'package:flutter_ime/flutter_ime.dart';

// Switch to English keyboard
await setEnglishKeyboard();

// Check if current keyboard is English
bool isEnglish = await isEnglishKeyboard();

// Disable IME completely (Windows only)
await disableIME();

// Enable IME again (Windows only)
await enableIME();

// Listen for keyboard layout changes (Windows, macOS)
onInputSourceChanged().listen((isEnglish) {
  print('Keyboard changed to: ${isEnglish ? "English" : "Non-English"}');
});

// Check if Caps Lock is on (Windows, macOS)
bool capsLock = await isCapsLockOn();

// Listen for Caps Lock state changes (Windows, macOS)
onCapsLockChanged().listen((isOn) {
  print('Caps Lock: ${isOn ? "ON" : "OFF"}');
});

// Get current input source ID (Windows, macOS)
String? inputSource = await getCurrentInputSource();
// macOS: "com.apple.keylayout.ABC", "com.apple.inputmethod.Korean.2SetKorean"
// Windows: "00000412:1:0" (KLID:conversion:sentence)

// Restore saved input source (Windows, macOS)
if (inputSource != null) {
  await setInputSource(inputSource);
}
```

### Automatic Password Field Example

```dart
class _LoginPageState extends State<LoginPage> {
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Switch to English keyboard when password field gets focus
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        setEnglishKeyboard();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: _passwordFocusNode,
      obscureText: true,
      decoration: InputDecoration(labelText: 'Password'),
    );
  }
}
```

### Disable IME (Windows only)

`disableIME()` detaches the IME from your window, so composition cannot start: the user can switch to a Korean or Japanese keyboard and typing produces nothing.

**It does not prevent pasted text.** Paste never travels the keyboard path, so `Ctrl+V` puts Korean into the field regardless. 2.x documented this as making non-English input "impossible", which it never was — 2.x did not prevent paste either. If you need a guarantee about a field's *value* rather than about typing, filter it in Dart with an `inputFormatter`, which catches paste as well.

Always pair it with `enableIME()`, or the IME stays detached for the rest of the app's life.


```dart
class _MyPageState extends State<MyPage> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Disable IME on focus, enable on unfocus
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        disableIME();
      } else {
        enableIME();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: _focusNode,
      decoration: InputDecoration(labelText: 'English only'),
    );
  }
}
```

### Cross-platform English Only Field (Windows, macOS)

For macOS where `disableIME()` is not available, use `onInputSourceChanged()` to detect and revert keyboard changes:

```dart
class _MyPageState extends State<MyPage> {
  final _focusNode = FocusNode();
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Switch to English on focus
        setEnglishKeyboard();
        // Revert to English if user switches to non-English
        _subscription = onInputSourceChanged().listen((isEnglish) {
          if (!isEnglish) {
            setEnglishKeyboard();
          }
        });
      } else {
        _subscription?.cancel();
        _subscription = null;
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: _focusNode,
      decoration: InputDecoration(labelText: 'English only'),
      // Filter out non-English characters as fallback
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(r'[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};:"\\|,.<>/?`~ ]'),
        ),
      ],
    );
  }
}
```

### Save and Restore Input Source Example (Windows, macOS)

Save the keyboard state before switching to English, then restore it when the field loses focus:

> **Note:** The value from `getCurrentInputSource()` is an **opaque token**. Its format is platform-specific and may change — save it and pass it back to `setInputSource()` unchanged. Don't parse or construct it yourself.

```dart
class _MyPageState extends State<MyPage> {
  final _focusNode = FocusNode();
  StreamSubscription<bool>? _subscription;
  String? _savedInputSource;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() async {
      if (_focusNode.hasFocus) {
        // Save current keyboard before switching to English
        _savedInputSource = await getCurrentInputSource();
        setEnglishKeyboard();
        // Keep English while focused
        _subscription = onInputSourceChanged().listen((isEnglish) {
          if (!isEnglish) {
            setEnglishKeyboard();
          }
        });
      } else {
        _subscription?.cancel();
        _subscription = null;
        // Restore previous keyboard (no isEnglish check needed - more efficient)
        if (_savedInputSource != null) {
          await setInputSource(_savedInputSource!);
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: _focusNode,
      decoration: InputDecoration(labelText: 'English only'),
    );
  }
}
```

### Caps Lock Warning Example (Windows, macOS)

```dart
class _LoginPageState extends State<LoginPage> {
  final _passwordFocusNode = FocusNode();
  StreamSubscription<bool>? _capsLockSubscription;
  bool _isCapsLockOn = false;

  @override
  void initState() {
    super.initState();

    _passwordFocusNode.addListener(() async {
      if (_passwordFocusNode.hasFocus) {
        // Check current Caps Lock state
        final capsLock = await isCapsLockOn();
        setState(() => _isCapsLockOn = capsLock);

        // Listen for Caps Lock changes while focused
        _capsLockSubscription = onCapsLockChanged().listen((isOn) {
          setState(() => _isCapsLockOn = isOn);
        });
      } else {
        // Stop listening when unfocused
        _capsLockSubscription?.cancel();
        _capsLockSubscription = null;
        setState(() => _isCapsLockOn = false);
      }
    });
  }

  @override
  void dispose() {
    _capsLockSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          focusNode: _passwordFocusNode,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: _isCapsLockOn
                ? Icon(Icons.keyboard_capslock, color: Colors.orange)
                : null,
          ),
        ),
        if (_isCapsLockOn)
          Text('Caps Lock is ON', style: TextStyle(color: Colors.orange)),
      ],
    );
  }
}
```

## API Reference

| Function | Description | Platform |
|----------|-------------|----------|
| `setEnglishKeyboard()` | Switch to English keyboard | Windows, macOS |
| `isEnglishKeyboard()` | Check if current keyboard is English | Windows, macOS |
| `getCurrentInputSource()` | Get current input source ID | Windows, macOS |
| `setInputSource(sourceId)` | Set input source by ID | Windows, macOS |
| `disableIME()` | Detach the IME so composition cannot start (does not stop paste) | Windows only |
| `enableIME()` | Re-attach the IME | Windows only |
| `onInputSourceChanged()` | Stream that emits when keyboard layout changes | Windows, macOS |
| `isCapsLockOn()` | Check if Caps Lock is currently on | Windows, macOS |
| `onCapsLockChanged()` | Stream that emits when Caps Lock state changes | Windows, macOS |

## Platform Support

| Platform | `setEnglishKeyboard` | `isEnglishKeyboard` | `getCurrentInputSource` | `setInputSource` | `disableIME` / `enableIME` | `onInputSourceChanged` | `isCapsLockOn` | `onCapsLockChanged` |
|----------|---------------------|---------------------|------------------------|------------------|---------------------------|------------------------|----------------|---------------------|
| Windows  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| macOS    | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| Others   | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

Unsupported platforms are safe, not broken: every function returns the default in its documentation — `false`, `null`, an empty stream — rather than throwing, so you can call them from shared code without guarding.

### `isEnglishKeyboard()` means something different on each platform

This has always been true and is worth stating:

* **Windows** — the IME is not in native-language conversion mode. A Korean keyboard in alphanumeric mode answers `true`.
* **macOS** — the selected layout types English. The question is asked of the layout itself, so **Dvorak, Colemak, British, Australian and Canadian all answer `true`**. 2.x recognised only ABC and US and answered `false` for the rest, which meant the "force English" recipe above dragged those users onto ABC against their will.

### Event delivery differs too

* **macOS** pushes input-source changes from a system notification, so they arrive immediately.
* **Windows** polls a few times a second. Learning about a change there requires a callback that returns a value synchronously, which is what a window procedure needs and what Dart FFI cannot provide — so polling is the honest option rather than a shortcut. The delay is not perceptible by hand.

Both streams emit only when the value actually changes, and neither emits the value you started from — subscribing captures it as a baseline. Use `isEnglishKeyboard()` or `isCapsLockOn()` for the current value.

**On macOS, a language switch can report a Caps Lock toggle.** The Caps Lock key doubles as the input-source switch, so changing language really does turn the lock on and off again for about twelve milliseconds, and a polled stream sometimes catches it. A warning indicator driven by `onCapsLockChanged()` will flicker when the user switches language.

## Requirements

* Dart SDK 3.4 or later
* Windows 7 or later, macOS 10.11 or later
* Flutter is **not** required — the package works from a plain Dart program

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Issues and Feedback

Please file issues and feedback using the [GitHub Issues](https://github.com/kihyun1998/flutter_ime/issues).
