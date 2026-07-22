// The README's code samples, compiled.
//
// Documentation that no longer compiles is worse than no documentation: it
// looks authoritative and sends the reader down a dead end. These samples went
// stale once already — they were written against 2.x — so they are kept here
// where `flutter analyze` in CI has to agree they still typecheck.
//
// **The text is verbatim.** Only two things are added: the `StatefulWidget`
// each `State` needs, and a numeric suffix on class names so five samples that
// all call their page `_MyPageState` can share a file. Neither touches an API
// call, which is the part that can actually break.
//
// If you change a sample here, change it in the README, and the other way
// round.
//
// ignore_for_file: prefer_const_constructors, avoid_print, unused_element
// ignore_for_file: unused_local_variable
// ignore_for_file: prefer_const_literals_to_create_immutables
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ime/flutter_ime.dart';

/// The "Usage" section.
Future<void> readmeUsage() async {
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
}

/// The "Automatic Password Field" section.
class _ReadmePage1 extends StatefulWidget {
  const _ReadmePage1();

  @override
  State<_ReadmePage1> createState() => _LoginPageState1();
}

class _LoginPageState1 extends State<_ReadmePage1> {
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

/// The "Disable IME" section.
class _ReadmePage2 extends StatefulWidget {
  const _ReadmePage2();

  @override
  State<_ReadmePage2> createState() => _MyPageState2();
}

class _MyPageState2 extends State<_ReadmePage2> {
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

/// The "Cross-platform English Only Field" section.
class _ReadmePage3 extends StatefulWidget {
  const _ReadmePage3();

  @override
  State<_ReadmePage3> createState() => _MyPageState3();
}

class _MyPageState3 extends State<_ReadmePage3> {
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

/// The "Save and Restore Input Source" section.
class _ReadmePage4 extends StatefulWidget {
  const _ReadmePage4();

  @override
  State<_ReadmePage4> createState() => _MyPageState4();
}

class _MyPageState4 extends State<_ReadmePage4> {
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

/// The "Caps Lock Warning" section.
class _ReadmePage5 extends StatefulWidget {
  const _ReadmePage5();

  @override
  State<_ReadmePage5> createState() => _LoginPageState5();
}

class _LoginPageState5 extends State<_ReadmePage5> {
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
