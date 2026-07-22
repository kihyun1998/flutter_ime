// Regression test for a crash found while driving the example app by hand.
//
// An earlier FfiFlutterIme threw for operations that were not ported yet.
// Installing it mid-session then crashed on the next page transition, because
// Flutter runs the incoming page's initState BEFORE the outgoing page's
// dispose — so an unported operation was reached through an instance that was
// supposed to have been uninstalled already:
//
//   FlutterImePlatform.onInputSourceChanged (flutter_ime_platform_interface.dart)
//   onInputSourceChanged                    (flutter_ime.dart)
//   _InputSourceChangePageState.initState   (example/lib/main.dart)
//
// The fix is that unported operations fall through to the native plugin, which
// makes a half-ported instance safe to install at any point in the migration.
// These tests pin that down for every operation still unported, so the next
// ticket cannot quietly reintroduce a throwing hole.
library;

import 'package:flutter_ime/flutter_ime_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mock_flutter_ime_platform.dart';

void main() {
  late MockFlutterImePlatform fallback;
  late FfiFlutterIme ffi;

  setUp(() {
    fallback = MockFlutterImePlatform();
    ffi = FfiFlutterIme(fallback: fallback);
  });

  tearDown(() => fallback.dispose());

  group('operations not ported yet fall through to the native plugin', () {
    test('disableIME', () async {
      await ffi.disableIME();
      expect(fallback.calls, contains('disableIME'));
    });

    test('enableIME', () async {
      await ffi.enableIME();
      expect(fallback.calls, contains('enableIME'));
    });

    test('isCapsLockOn returns the fallback result', () async {
      fallback.capsLockResult = true;
      expect(await ffi.isCapsLockOn(), isTrue);
      expect(fallback.calls, contains('isCapsLockOn'));
    });

    test('onInputSourceChanged forwards the fallback stream', () async {
      final events = <bool>[];
      final subscription = ffi.onInputSourceChanged.listen(events.add);
      addTearDown(subscription.cancel);

      fallback.inputSourceController.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(fallback.calls, contains('onInputSourceChanged'));
      expect(events, [true]);
    });

    test('onCapsLockChanged forwards the fallback stream', () async {
      final events = <bool>[];
      final subscription = ffi.onCapsLockChanged.listen(events.add);
      addTearDown(subscription.cancel);

      fallback.capsLockController.add(true);
      await Future<void>.delayed(Duration.zero);

      expect(fallback.calls, contains('onCapsLockChanged'));
      expect(events, [true]);
    });

    test('no unported operation throws', () async {
      // The shape of the original crash: reaching an unported operation must
      // never raise, whoever happens to hold the instance.
      await expectLater(ffi.disableIME(), completes);
      await expectLater(ffi.enableIME(), completes);
      await expectLater(ffi.isCapsLockOn(), completes);
      expect(() => ffi.onInputSourceChanged, returnsNormally);
      expect(() => ffi.onCapsLockChanged, returnsNormally);
    });
  });
}
