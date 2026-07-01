import 'package:flutter/services.dart';
import 'package:flutter_ime/flutter_ime_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelFlutterIme platform = MethodChannelFlutterIme();
  const MethodChannel channel = MethodChannel('flutter_ime');
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Records every MethodCall the platform sends, so tests can assert on the
  // method name and arguments crossing the channel.
  final List<MethodCall> log = <MethodCall>[];

  // Per-test override for what the "native" side returns. Defaults to null,
  // which mirrors a void native handler.
  Object? Function(MethodCall call)? responder;

  setUp(() {
    log.clear();
    responder = null;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      log.add(call);
      return responder?.call(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('method invocations', () {
    test('setEnglishKeyboard invokes the matching method with no arguments',
        () async {
      await platform.setEnglishKeyboard();
      expect(log, hasLength(1));
      expect(log.single.method, 'setEnglishKeyboard');
      expect(log.single.arguments, isNull);
    });

    test('isEnglishKeyboard returns the native boolean', () async {
      responder = (_) => true;
      expect(await platform.isEnglishKeyboard(), isTrue);
      expect(log.single.method, 'isEnglishKeyboard');
    });

    test('isEnglishKeyboard defaults to false when native returns null',
        () async {
      responder = (_) => null;
      expect(await platform.isEnglishKeyboard(), isFalse);
    });

    test('getCurrentInputSource returns the native string', () async {
      responder = (_) => 'com.apple.keylayout.ABC';
      expect(await platform.getCurrentInputSource(), 'com.apple.keylayout.ABC');
      expect(log.single.method, 'getCurrentInputSource');
    });

    test('getCurrentInputSource returns null when native returns null',
        () async {
      responder = (_) => null;
      expect(await platform.getCurrentInputSource(), isNull);
    });

    test('setInputSource forwards the sourceId argument', () async {
      await platform.setInputSource('00000412:1:0');
      expect(log.single.method, 'setInputSource');
      expect(
        log.single.arguments,
        <String, Object?>{'sourceId': '00000412:1:0'},
      );
    });

    test('disableIME invokes the matching method', () async {
      await platform.disableIME();
      expect(log.single.method, 'disableIME');
    });

    test('enableIME invokes the matching method', () async {
      await platform.enableIME();
      expect(log.single.method, 'enableIME');
    });

    test('isCapsLockOn returns the native boolean', () async {
      responder = (_) => true;
      expect(await platform.isCapsLockOn(), isTrue);
      expect(log.single.method, 'isCapsLockOn');
    });

    test('isCapsLockOn defaults to false when native returns null', () async {
      responder = (_) => null;
      expect(await platform.isCapsLockOn(), isFalse);
    });
  });

  group('input-source token is opaque', () {
    test('a saved token is sent back to setInputSource byte-for-byte',
        () async {
      // A Windows-style token whose colons a naive parser might split on. The
      // Dart layer must treat it as an opaque value: save it, restore it,
      // unchanged. All parsing lives natively.
      const String token = '00000412:1:0';
      responder = (MethodCall call) =>
          call.method == 'getCurrentInputSource' ? token : null;

      final String? saved = await platform.getCurrentInputSource();
      expect(saved, token);

      await platform.setInputSource(saved!);

      final MethodCall setCall =
          log.firstWhere((MethodCall c) => c.method == 'setInputSource');
      expect(setCall.arguments, <String, Object?>{'sourceId': token});
    });
  });

  group('onInputSourceChanged stream', () {
    const EventChannel eventChannel =
        EventChannel('flutter_ime/input_source_changed');

    tearDown(() {
      messenger.setMockStreamHandler(eventChannel, null);
    });

    test('forwards events emitted by the native event channel', () {
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            events.success(true);
            events.success(false);
            events.endOfStream();
          },
        ),
      );

      expect(
        platform.onInputSourceChanged,
        emitsInOrder(<Matcher>[equals(true), equals(false)]),
      );
    });

    test('surfaces native errors as stream errors', () {
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            events.error(code: 'BOOM', message: 'native failure');
          },
        ),
      );

      expect(
        platform.onInputSourceChanged,
        emitsError(isA<PlatformException>()),
      );
    });
  });

  group('onCapsLockChanged stream', () {
    const EventChannel capsLockChannel =
        EventChannel('flutter_ime/caps_lock_changed');

    tearDown(() {
      messenger.setMockStreamHandler(capsLockChannel, null);
    });

    test('forwards Caps Lock events emitted by the native event channel', () {
      messenger.setMockStreamHandler(
        capsLockChannel,
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            events.success(true);
            events.success(false);
            events.endOfStream();
          },
        ),
      );

      expect(
        platform.onCapsLockChanged,
        emitsInOrder(<Matcher>[equals(true), equals(false)]),
      );
    });
  });
}
