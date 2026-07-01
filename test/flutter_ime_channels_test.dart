import 'package:flutter_ime/src/flutter_ime_channels.dart';
import 'package:flutter_test/flutter_test.dart';

// The right-hand literals below are the wire contract that the native macOS
// (macos/Classes/FlutterImePlugin.swift) and Windows
// (windows/flutter_ime_plugin.cpp) plugins register and dispatch on. They are
// the independent source of truth; this test pins the Dart-side constants to
// them so a typo in the constants file is caught as contract drift.
void main() {
  group('IME channel contract', () {
    test('channel names match the native registration', () {
      expect(ImeChannels.method, 'flutter_ime');
      expect(ImeChannels.inputSourceChangedEvent,
          'flutter_ime/input_source_changed');
      expect(ImeChannels.capsLockChangedEvent, 'flutter_ime/caps_lock_changed');
    });

    test('method names match the native handlers', () {
      expect(ImeMethods.setEnglishKeyboard, 'setEnglishKeyboard');
      expect(ImeMethods.isEnglishKeyboard, 'isEnglishKeyboard');
      expect(ImeMethods.getCurrentInputSource, 'getCurrentInputSource');
      expect(ImeMethods.setInputSource, 'setInputSource');
      expect(ImeMethods.disableIme, 'disableIME');
      expect(ImeMethods.enableIme, 'enableIME');
      expect(ImeMethods.isCapsLockOn, 'isCapsLockOn');
    });

    test('argument keys match the native argument map', () {
      expect(ImeArguments.sourceId, 'sourceId');
    });
  });
}
