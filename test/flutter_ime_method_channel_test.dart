import 'package:flutter/services.dart';
import 'package:flutter_ime/flutter_ime_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterIme platform = MethodChannelFlutterIme();
  const MethodChannel channel = MethodChannel('flutter_ime');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'setEnglishKeyboard':
            return null;
          case 'isEnglishKeyboard':
            return true;
          default:
            return '42';
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setEnglishKeyboard', () async {
    await platform.setEnglishKeyboard();
  });

  test('isEnglishKeyboard', () async {
    expect(await platform.isEnglishKeyboard(), true);
  });
}
