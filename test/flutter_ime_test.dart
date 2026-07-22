// Gating behaviour of the public API (supported / unsupported / Windows-only)
// is covered deterministically in platform_gating_test.dart via the
// PlatformSupport seam. This file only pins the default platform binding.
library;

import 'package:flutter_ime/flutter_ime_platform_interface.dart';
import 'package:flutter_ime/src/ffi/ffi_flutter_ime.dart';
import 'package:test/test.dart';

void main() {
  test('the default platform binding is the FFI implementation', () {
    // 3.0.0 flipped this. It used to be a method-channel implementation backed
    // by a native plugin, with the FFI one installable by hand; there is now
    // nothing to install and nothing to install it beside.
    expect(FlutterImePlatform.instance, isA<FfiFlutterIme>());
  });

  test('nothing has to be installed for the default to work', () {
    // The example app used to assign FlutterImePlatform.instance to opt in.
    // Reading the getter without having set anything is the whole assertion:
    // if the default were still a placeholder that throws, this would fail.
    expect(() => FlutterImePlatform.instance, returnsNormally);
  });
}
