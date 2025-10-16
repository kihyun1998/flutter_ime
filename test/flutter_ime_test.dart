import 'package:flutter_ime/flutter_ime.dart';
import 'package:flutter_ime/flutter_ime_method_channel.dart';
import 'package:flutter_ime/flutter_ime_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterImePlatform
    with MockPlatformInterfaceMixin
    implements FlutterImePlatform {
  @override
  Future<bool> isEnglishKeyboard() => Future<bool>.value(true);

  @override
  Future<void> setEnglishKeyboard() => Future<void>.value();
}

void main() {
  final FlutterImePlatform initialPlatform = FlutterImePlatform.instance;

  test(
      '$FlutterImePlatform has the default instance : $MethodChannelFlutterIme',
      () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterIme>());
  });

  test('Test Platform Interface Mock', () async {
    MockFlutterImePlatform fakePlatform = MockFlutterImePlatform();
    FlutterImePlatform.instance = fakePlatform;

    // test setEnglishKeyboard
    await setEnglishKeyboard();

    // tes isEnglishKeyboard
    expect(await isEnglishKeyboard(), true);
  });
}
