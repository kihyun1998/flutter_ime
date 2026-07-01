import 'dart:async';
import 'dart:io';

import 'package:flutter_ime/flutter_ime.dart';
import 'package:flutter_ime/flutter_ime_method_channel.dart';
import 'package:flutter_ime/flutter_ime_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A fake platform implementation that records delegated calls instead of
/// touching any real IME. [MockPlatformInterfaceMixin] bypasses the platform
/// interface token check used by the real subclasses.
class MockFlutterImePlatform
    with MockPlatformInterfaceMixin
    implements FlutterImePlatform {
  final List<String> calls = <String>[];
  String? lastSourceId;

  bool englishResult = true;
  bool capsLockResult = true;
  String? currentSource = 'mock.source';

  final StreamController<bool> inputSourceController =
      StreamController<bool>.broadcast();
  final StreamController<bool> capsLockController =
      StreamController<bool>.broadcast();

  void dispose() {
    inputSourceController.close();
    capsLockController.close();
  }

  @override
  Future<void> setEnglishKeyboard() async => calls.add('setEnglishKeyboard');

  @override
  Future<bool> isEnglishKeyboard() async {
    calls.add('isEnglishKeyboard');
    return englishResult;
  }

  @override
  Future<String?> getCurrentInputSource() async {
    calls.add('getCurrentInputSource');
    return currentSource;
  }

  @override
  Future<void> setInputSource(String sourceId) async {
    calls.add('setInputSource');
    lastSourceId = sourceId;
  }

  @override
  Future<void> disableIME() async => calls.add('disableIME');

  @override
  Future<void> enableIME() async => calls.add('enableIME');

  @override
  Stream<bool> get onInputSourceChanged {
    calls.add('onInputSourceChanged');
    return inputSourceController.stream;
  }

  @override
  Future<bool> isCapsLockOn() async {
    calls.add('isCapsLockOn');
    return capsLockResult;
  }

  @override
  Stream<bool> get onCapsLockChanged {
    calls.add('onCapsLockChanged');
    return capsLockController.stream;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Whether the current host is a platform the plugin actually supports. The
  // top-level API delegates on these and no-ops elsewhere, so expectations are
  // branched to keep the suite green on any CI host (including Linux).
  final bool supported = Platform.isWindows || Platform.isMacOS;
  final bool windowsOnly = Platform.isWindows;

  group('default platform interface', () {
    test('defaults to the MethodChannel implementation', () {
      expect(FlutterImePlatform.instance, isA<MethodChannelFlutterIme>());
    });
  });

  group('top-level API', () {
    late MockFlutterImePlatform mock;

    setUp(() {
      mock = MockFlutterImePlatform();
      FlutterImePlatform.instance = mock;
    });

    tearDown(() {
      mock.dispose();
    });

    test('setEnglishKeyboard delegates only on supported platforms', () async {
      await setEnglishKeyboard();
      expect(
        mock.calls,
        supported ? contains('setEnglishKeyboard') : isEmpty,
      );
    });

    test('isEnglishKeyboard returns the native result or false', () async {
      mock.englishResult = true;
      expect(await isEnglishKeyboard(), supported ? isTrue : isFalse);
    });

    test('getCurrentInputSource returns the native value or null', () async {
      mock.currentSource = 'com.apple.keylayout.ABC';
      expect(
        await getCurrentInputSource(),
        supported ? 'com.apple.keylayout.ABC' : isNull,
      );
    });

    test('setInputSource delegates with the sourceId on supported platforms',
        () async {
      await setInputSource('00000412:1:0');
      if (supported) {
        expect(mock.calls, contains('setInputSource'));
        expect(mock.lastSourceId, '00000412:1:0');
      } else {
        expect(mock.calls, isEmpty);
      }
    });

    test('disableIME delegates only on Windows', () async {
      await disableIME();
      expect(mock.calls, windowsOnly ? contains('disableIME') : isEmpty);
    });

    test('enableIME delegates only on Windows', () async {
      await enableIME();
      expect(mock.calls, windowsOnly ? contains('enableIME') : isEmpty);
    });

    test('isCapsLockOn returns the native result or false', () async {
      mock.capsLockResult = true;
      expect(await isCapsLockOn(), supported ? isTrue : isFalse);
    });

    test('onInputSourceChanged forwards events or is empty', () async {
      final Stream<bool> stream = onInputSourceChanged();
      if (supported) {
        expect(mock.calls, contains('onInputSourceChanged'));
        final Future<void> expectation = expectLater(stream, emits(true));
        mock.inputSourceController.add(true);
        await expectation;
      } else {
        expect(mock.calls, isEmpty);
        expect(await stream.isEmpty, isTrue);
      }
    });

    test('onCapsLockChanged forwards events or is empty', () async {
      final Stream<bool> stream = onCapsLockChanged();
      if (supported) {
        expect(mock.calls, contains('onCapsLockChanged'));
        final Future<void> expectation = expectLater(stream, emits(true));
        mock.capsLockController.add(true);
        await expectation;
      } else {
        expect(mock.calls, isEmpty);
        expect(await stream.isEmpty, isTrue);
      }
    });
  });
}
