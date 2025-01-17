import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ime_platform_interface.dart';

/// Method Channel을 사용하는 기본 구현체
class MethodChannelFlutterIme extends FlutterImePlatform {
  /// Method Channel 인스턴스
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_ime');

  @override
  Future<void> setEnglishKeyboard() async {
    await methodChannel.invokeMethod<void>('setEnglishKeyboard');
  }

  @override
  Future<bool> isEnglishKeyboard() async {
    final result = await methodChannel.invokeMethod<bool>('isEnglishKeyboard');
    return result ?? false;
  }
}
