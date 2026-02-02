import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ime_method_channel.dart';

/// Platform interface for Flutter IME plugin.
abstract class FlutterImePlatform extends PlatformInterface {
  FlutterImePlatform() : super(token: _token);

  static final Object _token = Object();
  static FlutterImePlatform _instance = MethodChannelFlutterIme();

  /// Returns the default instance.
  static FlutterImePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterImePlatform] when
  /// they register themselves.
  static set instance(FlutterImePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Changes IME to English mode.
  Future<void> setEnglishKeyboard() async {
    throw UnimplementedError('setEnglishKeyboard() must be implemented');
  }

  /// Checks if current IME is in English mode.
  Future<bool> isEnglishKeyboard() async {
    throw UnimplementedError('isEnglishKeyboard() must be implemented');
  }

  /// Disables IME (Windows only).
  Future<void> disableIME() async {
    throw UnimplementedError('disableIME() must be implemented');
  }

  /// Enables IME (Windows only).
  Future<void> enableIME() async {
    throw UnimplementedError('enableIME() must be implemented');
  }

  /// Stream that emits when input source changes.
  Stream<bool> get onInputSourceChanged {
    throw UnimplementedError('onInputSourceChanged must be implemented');
  }

  /// Checks if Caps Lock is currently on.
  Future<bool> isCapsLockOn() async {
    throw UnimplementedError('isCapsLockOn() must be implemented');
  }

  /// Stream that emits when Caps Lock state changes.
  Stream<bool> get onCapsLockChanged {
    throw UnimplementedError('onCapsLockChanged must be implemented');
  }
}
