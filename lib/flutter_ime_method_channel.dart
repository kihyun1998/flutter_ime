import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ime_platform_interface.dart';

/// Default implementation using Method Channel.
class MethodChannelFlutterIme extends FlutterImePlatform {
  /// The method channel instance.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_ime');

  /// The event channel instance for input source changes.
  @visibleForTesting
  final eventChannel = const EventChannel('flutter_ime/input_source_changed');

  /// The event channel instance for Caps Lock changes.
  @visibleForTesting
  final capsLockEventChannel = const EventChannel('flutter_ime/caps_lock_changed');

  /// Broadcast stream controller for input source changes.
  StreamController<bool>? _streamController;
  StreamSubscription? _eventSubscription;

  /// Stream controller for Caps Lock state changes.
  StreamController<bool>? _capsLockStreamController;
  StreamSubscription? _capsLockEventSubscription;

  @override
  Future<void> setEnglishKeyboard() async {
    await methodChannel.invokeMethod<void>('setEnglishKeyboard');
  }

  @override
  Future<bool> isEnglishKeyboard() async {
    final result = await methodChannel.invokeMethod<bool>('isEnglishKeyboard');
    return result ?? false;
  }

  @override
  Future<void> disableIME() async {
    await methodChannel.invokeMethod<void>('disableIME');
  }

  @override
  Future<void> enableIME() async {
    await methodChannel.invokeMethod<void>('enableIME');
  }

  @override
  Stream<bool> get onInputSourceChanged {
    if (_streamController == null) {
      _streamController = StreamController<bool>.broadcast(
        onListen: _startListening,
        onCancel: _stopListening,
      );
    }
    return _streamController!.stream;
  }

  void _startListening() {
    _eventSubscription = eventChannel.receiveBroadcastStream().listen(
      (event) {
        _streamController?.add(event as bool);
      },
      onError: (error) {
        _streamController?.addError(error);
      },
    );
  }

  void _stopListening() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  Future<bool> isCapsLockOn() async {
    final result = await methodChannel.invokeMethod<bool>('isCapsLockOn');
    return result ?? false;
  }

  @override
  Stream<bool> get onCapsLockChanged {
    if (_capsLockStreamController == null) {
      _capsLockStreamController = StreamController<bool>.broadcast(
        onListen: _startCapsLockListening,
        onCancel: _stopCapsLockListening,
      );
    }
    return _capsLockStreamController!.stream;
  }

  void _startCapsLockListening() {
    _capsLockEventSubscription = capsLockEventChannel.receiveBroadcastStream().listen(
      (event) {
        _capsLockStreamController?.add(event as bool);
      },
      onError: (error) {
        _capsLockStreamController?.addError(error);
      },
    );
  }

  void _stopCapsLockListening() {
    _capsLockEventSubscription?.cancel();
    _capsLockEventSubscription = null;
  }
}
