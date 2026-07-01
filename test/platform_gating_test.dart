import 'package:flutter_ime/flutter_ime.dart';
import 'package:flutter_ime/flutter_ime_platform_interface.dart';
import 'package:flutter_ime/src/platform_support.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mock_flutter_ime_platform.dart';

/// Fixed platform policy so every gating branch can be exercised
/// deterministically on any host.
class _FakePlatformSupport implements PlatformSupport {
  const _FakePlatformSupport({
    required this.isSupported,
    required this.isWindowsOnly,
  });

  @override
  final bool isSupported;

  @override
  final bool isWindowsOnly;
}

const _FakePlatformSupport _windows =
    _FakePlatformSupport(isSupported: true, isWindowsOnly: true);
const _FakePlatformSupport _macos =
    _FakePlatformSupport(isSupported: true, isWindowsOnly: false);
const _FakePlatformSupport _unsupported =
    _FakePlatformSupport(isSupported: false, isWindowsOnly: false);

void main() {
  late MockFlutterImePlatform mock;

  setUp(() {
    mock = MockFlutterImePlatform();
    FlutterImePlatform.instance = mock;
  });

  tearDown(() {
    mock.dispose();
    debugSetPlatformSupport(null);
  });

  group('unsupported platform', () {
    setUp(() => debugSetPlatformSupport(_unsupported));

    test('setEnglishKeyboard is a no-op', () async {
      await setEnglishKeyboard();
      expect(mock.calls, isEmpty);
    });

    test('isEnglishKeyboard returns false without delegating', () async {
      expect(await isEnglishKeyboard(), isFalse);
      expect(mock.calls, isEmpty);
    });

    test('getCurrentInputSource returns null without delegating', () async {
      expect(await getCurrentInputSource(), isNull);
      expect(mock.calls, isEmpty);
    });

    test('setInputSource is a no-op', () async {
      await setInputSource('x');
      expect(mock.calls, isEmpty);
    });

    test('disableIME is a no-op', () async {
      await disableIME();
      expect(mock.calls, isEmpty);
    });

    test('enableIME is a no-op', () async {
      await enableIME();
      expect(mock.calls, isEmpty);
    });

    test('isCapsLockOn returns false without delegating', () async {
      expect(await isCapsLockOn(), isFalse);
      expect(mock.calls, isEmpty);
    });

    test('onInputSourceChanged is an empty stream without delegating',
        () async {
      final Stream<bool> stream = onInputSourceChanged();
      expect(await stream.isEmpty, isTrue);
      expect(mock.calls, isEmpty);
    });

    test('onCapsLockChanged is an empty stream without delegating', () async {
      final Stream<bool> stream = onCapsLockChanged();
      expect(await stream.isEmpty, isTrue);
      expect(mock.calls, isEmpty);
    });
  });

  group('supported platform (Windows)', () {
    setUp(() => debugSetPlatformSupport(_windows));

    test('setEnglishKeyboard delegates', () async {
      await setEnglishKeyboard();
      expect(mock.calls, contains('setEnglishKeyboard'));
    });

    test('isEnglishKeyboard delegates and returns the native result', () async {
      mock.englishResult = true;
      expect(await isEnglishKeyboard(), isTrue);
      expect(mock.calls, contains('isEnglishKeyboard'));
    });

    test('getCurrentInputSource delegates and returns the native value',
        () async {
      mock.currentSource = 'com.apple.keylayout.ABC';
      expect(await getCurrentInputSource(), 'com.apple.keylayout.ABC');
    });

    test('setInputSource delegates with the sourceId', () async {
      await setInputSource('00000412:1:0');
      expect(mock.calls, contains('setInputSource'));
      expect(mock.lastSourceId, '00000412:1:0');
    });

    test('disableIME delegates', () async {
      await disableIME();
      expect(mock.calls, contains('disableIME'));
    });

    test('enableIME delegates', () async {
      await enableIME();
      expect(mock.calls, contains('enableIME'));
    });

    test('isCapsLockOn delegates and returns the native result', () async {
      mock.capsLockResult = true;
      expect(await isCapsLockOn(), isTrue);
    });

    test('onInputSourceChanged delegates and forwards events', () async {
      final Stream<bool> stream = onInputSourceChanged();
      expect(mock.calls, contains('onInputSourceChanged'));
      final Future<void> expectation = expectLater(stream, emits(true));
      mock.inputSourceController.add(true);
      await expectation;
    });

    test('onCapsLockChanged delegates and forwards events', () async {
      final Stream<bool> stream = onCapsLockChanged();
      expect(mock.calls, contains('onCapsLockChanged'));
      final Future<void> expectation = expectLater(stream, emits(true));
      mock.capsLockController.add(true);
      await expectation;
    });
  });

  group('macOS (Windows-only features disabled)', () {
    setUp(() => debugSetPlatformSupport(_macos));

    test('setEnglishKeyboard still delegates (supported)', () async {
      await setEnglishKeyboard();
      expect(mock.calls, contains('setEnglishKeyboard'));
    });

    test('disableIME does not delegate', () async {
      await disableIME();
      expect(mock.calls, isEmpty);
    });

    test('enableIME does not delegate', () async {
      await enableIME();
      expect(mock.calls, isEmpty);
    });
  });
}
