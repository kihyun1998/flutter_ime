import 'dart:async';

import 'package:flutter_ime/flutter_ime_platform_interface.dart';
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
