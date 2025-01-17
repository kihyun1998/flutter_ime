import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ime/flutter_ime.dart';
import 'package:flutter_ime/flutter_ime_platform_interface.dart';
import 'package:flutter_ime/flutter_ime_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterImePlatform
    with MockPlatformInterfaceMixin
    implements FlutterImePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterImePlatform initialPlatform = FlutterImePlatform.instance;

  test('$MethodChannelFlutterIme is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterIme>());
  });

  test('getPlatformVersion', () async {
    FlutterIme flutterImePlugin = FlutterIme();
    MockFlutterImePlatform fakePlatform = MockFlutterImePlatform();
    FlutterImePlatform.instance = fakePlatform;

    expect(await flutterImePlugin.getPlatformVersion(), '42');
  });
}
