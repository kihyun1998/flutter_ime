import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ime_method_channel.dart';

/// Flutter IME 플러그인을 위한 플랫폼 인터페이스
abstract class FlutterImePlatform extends PlatformInterface {
  FlutterImePlatform() : super(token: _token);

  static final Object _token = Object();
  static FlutterImePlatform _instance = MethodChannelFlutterIme();

  /// 기본 인스턴스 반환
  static FlutterImePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterImePlatform] when
  /// they register themselves.
  static set instance(FlutterImePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// IME를 영문 상태로 변경
  Future<void> setEnglishKeyboard() async {
    throw UnimplementedError('setEnglishKeyboard() must be implemented');
  }

  /// 현재 IME 상태 확인
  Future<bool> isEnglishKeyboard() async {
    throw UnimplementedError('isEnglishKeyboard() must be implemented');
  }

  /// IME 비활성화 (Windows only)
  Future<void> disableIME() async {
    throw UnimplementedError('disableIME() must be implemented');
  }

  /// IME 활성화 (Windows only)
  Future<void> enableIME() async {
    throw UnimplementedError('enableIME() must be implemented');
  }

  /// 입력 소스 변경 이벤트 스트림
  Stream<bool> get onInputSourceChanged {
    throw UnimplementedError('onInputSourceChanged must be implemented');
  }
}
