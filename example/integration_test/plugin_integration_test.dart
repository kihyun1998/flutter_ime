// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter/services.dart';
import 'package:flutter_ime/flutter_ime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setEnglishKeyboard test', (WidgetTester tester) async {
    // set ime english
    await setEnglishKeyboard();

    // check status
    final isEnglish = await isEnglishKeyboard();
    expect(isEnglish, true);
  });

  testWidgets(
      'setInputSource with a malformed token throws instead of crashing',
      (WidgetTester tester) async {
    // A token whose conversion/sentence segments are not numbers. This used to
    // reach std::stoul on Windows and crash the host app; it must now surface a
    // PlatformException the caller can handle.
    await expectLater(
      setInputSource('deadbeef:not-a-number:0'),
      throwsA(isA<PlatformException>()),
    );
  });
}
