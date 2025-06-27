# flutter_ime

A Flutter plugin for controlling Windows IME (Input Method Editor) state. This plugin helps you manage keyboard input modes in Windows applications, particularly useful for login forms and password fields where English input is preferred.

[![pub package](https://img.shields.io/pub/v/flutter_ime.svg)](https://pub.dev/packages/flutter_ime)

## Features

* Switch to English keyboard mode programmatically on Windows
* Check current keyboard input mode
* Automatic IME mode switching for password fields
* Pure Windows API implementation with no external dependencies

## Getting started

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ime: ^1.0.3
```

## Usage

```dart
import 'package:flutter_ime/flutter_ime.dart';

// Create an instance
final flutterIme = FlutterIme();

// Switch to English keyboard
await flutterIme.setEnglishKeyboard();

// Check if current keyboard is English
bool isEnglish = await flutterIme.isEnglishKeyboard();
```

### Automatic Password Field Example

```dart
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _flutterIme = FlutterIme();
  final _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    // Switch to English keyboard when password field gets focus
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        _flutterIme.setEnglishKeyboard();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: _passwordFocusNode,
      obscureText: true,
      decoration: InputDecoration(
        labelText: 'Password',
      ),
    );
  }
}
```

## Additional information

### Platform Support

* Windows - ✅ Fully supported
* Other platforms - ❌ Not supported

### Requirements

* Windows 7 or later
* Flutter SDK 3.0.0 or later

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Issues and Feedback

Please file issues and feedback using the [GitHub Issues](https://github.com/kihyun1998/flutter_ime/issues).