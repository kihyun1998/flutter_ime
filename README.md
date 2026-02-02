# flutter_ime

A Flutter plugin for controlling IME (Input Method Editor) state. This plugin helps you manage keyboard input modes in Windows and macOS applications, particularly useful for login forms and password fields where English input is preferred.

[![pub package](https://img.shields.io/pub/v/flutter_ime.svg)](https://pub.dev/packages/flutter_ime)

## Features

* Switch to English keyboard mode programmatically on Windows and macOS
* Check current keyboard input mode
* Disable/Enable IME completely (Windows only)
* Detect keyboard layout changes in real-time (Windows, macOS)
* Detect Caps Lock state and changes (Windows, macOS)
* Automatic IME mode switching for password fields
* Native API implementation (Windows IMM32, macOS Carbon)

## Getting started

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ime: ^2.1.2
```

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

### Disable IME Example (Windows only)

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
| `disableIME()` | Disable IME (prevents non-English input) | Windows only |
| `enableIME()` | Enable IME (restores input method) | Windows only |
| `onInputSourceChanged()` | Stream that emits when keyboard layout changes | Windows, macOS |
| `isCapsLockOn()` | Check if Caps Lock is currently on | Windows, macOS |
| `onCapsLockChanged()` | Stream that emits when Caps Lock state changes | Windows, macOS |

## Platform Support

| Platform | `setEnglishKeyboard` | `isEnglishKeyboard` | `getCurrentInputSource` | `setInputSource` | `disableIME` / `enableIME` | `onInputSourceChanged` | `isCapsLockOn` | `onCapsLockChanged` |
|----------|---------------------|---------------------|------------------------|------------------|---------------------------|------------------------|----------------|---------------------|
| Windows  | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| macOS    | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| Others   | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

## Requirements

* Windows 7 or later (for Windows)
* macOS 10.10 or later (for macOS)
* Flutter SDK 3.0.0 or later

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Issues and Feedback

Please file issues and feedback using the [GitHub Issues](https://github.com/kihyun1998/flutter_ime/issues).
