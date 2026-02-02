# flutter_ime

A Flutter plugin for controlling IME (Input Method Editor) state. This plugin helps you manage keyboard input modes in Windows and macOS applications, particularly useful for login forms and password fields where English input is preferred.

[![pub package](https://img.shields.io/pub/v/flutter_ime.svg)](https://pub.dev/packages/flutter_ime)

## Features

* Switch to English keyboard mode programmatically on Windows and macOS
* Check current keyboard input mode
* Disable/Enable IME completely (Windows only)
* Detect keyboard layout changes in real-time (Windows, macOS)
* Automatic IME mode switching for password fields
* Native API implementation (Windows IMM32, macOS Carbon)

## Getting started

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ime: ^2.1.0
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

## API Reference

| Function | Description | Platform |
|----------|-------------|----------|
| `setEnglishKeyboard()` | Switch to English keyboard | Windows, macOS |
| `isEnglishKeyboard()` | Check if current keyboard is English | Windows, macOS |
| `disableIME()` | Disable IME (prevents non-English input) | Windows only |
| `enableIME()` | Enable IME (restores input method) | Windows only |
| `onInputSourceChanged()` | Stream that emits when keyboard layout changes | Windows, macOS |

## Platform Support

| Platform | `setEnglishKeyboard` | `isEnglishKeyboard` | `disableIME` / `enableIME` | `onInputSourceChanged` |
|----------|---------------------|---------------------|---------------------------|------------------------|
| Windows  | ✅ | ✅ | ✅ | ✅ |
| macOS    | ✅ | ✅ | ❌ | ✅ |
| Others   | ❌ | ❌ | ❌ | ❌ |

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
