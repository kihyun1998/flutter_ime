import 'package:flutter_ime/flutter_ime_method_channel.dart';
import 'package:flutter_ime/flutter_ime_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

// Gating behavior of the public API (supported / unsupported / Windows-only) is
// covered deterministically in platform_gating_test.dart via the PlatformSupport
// seam. This file only pins the default platform binding.
void main() {
  test('default platform interface is the MethodChannel implementation', () {
    expect(FlutterImePlatform.instance, isA<MethodChannelFlutterIme>());
  });
}
