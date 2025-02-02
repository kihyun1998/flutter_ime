// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_ime/flutter_ime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setEnglishKeyboard test', (WidgetTester tester) async {
    final FlutterIme plugin = FlutterIme();

    // set ime english
    await plugin.setEnglishKeyboard();

    // check status
    final isEnglish = await plugin.isEnglishKeyboard();
    expect(isEnglish, true);
  });
}
