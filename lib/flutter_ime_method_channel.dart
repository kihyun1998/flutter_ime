import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ime_platform_interface.dart';
import 'src/flutter_ime_channels.dart';

/// Default implementation using Method Channel.
class MethodChannelFlutterIme extends FlutterImePlatform {
  /// The method channel instance.
  @visibleForTesting
  final methodChannel = const MethodChannel(ImeChannels.method);

  /// The event channel instance for input source changes.
  @visibleForTesting
  final eventChannel = const EventChannel(ImeChannels.inputSourceChangedEvent);

  /// The event channel instance for Caps Lock changes.
  @visibleForTesting
  final capsLockEventChannel =
      const EventChannel(ImeChannels.capsLockChangedEvent);

  /// Broadcast stream controller for input source changes.
  StreamController<bool>? _streamController;
  StreamSubscription? _eventSubscription;

  /// Stream controller for Caps Lock state changes.
  StreamController<bool>? _capsLockStreamController;
  StreamSubscription? _capsLockEventSubscription;

  @override
  Future<void> setEnglishKeyboard() async {
    await methodChannel.invokeMethod<void>(ImeMethods.setEnglishKeyboard);
  }

  @override
  Future<bool> isEnglishKeyboard() async {
    final result =
        await methodChannel.invokeMethod<bool>(ImeMethods.isEnglishKeyboard);
    return result ?? false;
  }

  @override
  Future<String?> getCurrentInputSource() async {
    final result = await methodChannel
        .invokeMethod<String>(ImeMethods.getCurrentInputSource);
    return result;
  }

  @override
  Future<void> setInputSource(String sourceId) async {
    await methodChannel.invokeMethod<void>(
        ImeMethods.setInputSource, {ImeArguments.sourceId: sourceId});
  }

  @override
  Future<void> disableIME() async {
    await methodChannel.invokeMethod<void>(ImeMethods.disableIme);
  }

  @override
  Future<void> enableIME() async {
    await methodChannel.invokeMethod<void>(ImeMethods.enableIme);
  }

  @override
  Stream<bool> get onInputSourceChanged {
    _streamController ??= StreamController<bool>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
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
    final result =
        await methodChannel.invokeMethod<bool>(ImeMethods.isCapsLockOn);
    return result ?? false;
  }

  @override
  Stream<bool> get onCapsLockChanged {
    _capsLockStreamController ??= StreamController<bool>.broadcast(
      onListen: _startCapsLockListening,
      onCancel: _stopCapsLockListening,
    );
    return _capsLockStreamController!.stream;
  }

  void _startCapsLockListening() {
    _capsLockEventSubscription =
        capsLockEventChannel.receiveBroadcastStream().listen(
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
