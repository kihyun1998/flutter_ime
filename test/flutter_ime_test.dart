import 'package:flutter_ime/flutter_ime.dart';
import 'package:flutter_ime/flutter_ime_method_channel.dart';
import 'package:flutter_ime/flutter_ime_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterImePlatform
    with MockPlatformInterfaceMixin
    implements FlutterImePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

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

  test('getPlatformVersion', () async {
    FlutterIme flutterImePlugin = FlutterIme();
    MockFlutterImePlatform fakePlatform = MockFlutterImePlatform();
    FlutterImePlatform.instance = fakePlatform;

    expect(await flutterImePlugin.getPlatformVersion(), '42');
  });

  test('Test Platform Interface Mock', () async {
    FlutterIme flutterImePlugin = FlutterIme();
    MockFlutterImePlatform fakePlatform = MockFlutterImePlatform();
    FlutterImePlatform.instance = fakePlatform;

    // test setEnglishKeyboard
    await flutterImePlugin.setEnglishKeyboard();

    // tes isEnglishKeyboard
    expect(await flutterImePlugin.isEnglishKeyboard(), true);
  });
}
