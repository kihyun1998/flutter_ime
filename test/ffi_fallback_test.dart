// Which operations reach FFI and which still fall through to the native
// plugin, and — just as importantly — that neither path can touch the
// operating system from a test.
//
// The fall-through exists because of a crash found while driving the example
// app by hand. An earlier FfiFlutterIme threw for operations not ported yet,
// so installing it mid-session crashed on the next page transition: Flutter
// runs the incoming page's initState BEFORE the outgoing page's dispose, and
// an unported operation was reached through an instance believed to be
// uninstalled. During the expand phase a half-ported instance has to be safe
// to install at any moment, and one that throws is not.
library;

import 'dart:ffi';

// The real implementation, not the `flutter_ime_ffi.dart` entry point. That
// entry point is a conditional export, and the analyzer resolves it to the web
// stub — which cannot name `WindowsIme`, since naming it would drag `dart:ffi`
// into the web build. This test is VM-only anyway, having just imported it.
import 'package:flutter_ime/src/ffi/ffi_flutter_ime.dart';
import 'package:flutter_ime/src/ffi/window_resolver.dart';
import 'package:flutter_ime/src/ffi/windows_ime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/mock_flutter_ime_platform.dart';

/// A [WindowsIme] whose window never resolves, so every operation
/// short-circuits before reaching a single Win32 call.
///
/// This is not a convenience — it is a safety requirement. A real [WindowsIme]
/// in a test process finds no Flutter window and falls back to
/// `GetForegroundWindow`, so a ported operation would apply itself to whatever
/// application happened to be focused on the machine running the tests.
/// Detaching a stranger's IME context is not an acceptable side effect of
/// `flutter test`.
WindowsIme unresolvableWindowsIme() => WindowsIme(
      resolver: WindowResolver(
        findOwnTopLevelWindow: (_) => nullptr,
        findChildWindow: (_, __) => nullptr,
        getForegroundWindow: () => nullptr,
        isWindowAlive: (_) => false,
      ),
    );

void main() {
  late MockFlutterImePlatform fallback;
  late FfiFlutterIme ffi;

  setUp(() {
    fallback = MockFlutterImePlatform();
    ffi = FfiFlutterIme(
      windowsIme: unresolvableWindowsIme(),
      fallback: fallback,
    );
  });

  tearDown(() => fallback.dispose());

  group('operations not ported yet fall through to the native plugin', () {
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

    test('reaching an unported operation never throws', () async {
      // The shape of the original crash: whoever holds the instance, an
      // unported operation must not raise.
      await expectLater(ffi.isCapsLockOn(), completes);
      expect(() => ffi.onInputSourceChanged, returnsNormally);
      expect(() => ffi.onCapsLockChanged, returnsNormally);
    });
  });

  group('ported operations do not fall through', () {
    // The complement of the group above: once an operation is ported, sending
    // it to the native plugin as well would mean doing the work twice, or
    // doing it through the layer this migration exists to remove.
    test('setEnglishKeyboard', () async {
      await ffi.setEnglishKeyboard();
      expect(fallback.calls, isEmpty);
    });

    test('isEnglishKeyboard', () async {
      expect(await ffi.isEnglishKeyboard(), isFalse);
      expect(fallback.calls, isEmpty);
    });

    test('getCurrentInputSource', () async {
      expect(await ffi.getCurrentInputSource(), isNull);
      expect(fallback.calls, isEmpty);
    });

    test('setInputSource', () async {
      await ffi.setInputSource('00000412:1:0');
      expect(fallback.calls, isEmpty);
    });

    test('disableIME', () async {
      await ffi.disableIME();
      expect(fallback.calls, isEmpty);
    });

    test('enableIME', () async {
      await ffi.enableIME();
      expect(fallback.calls, isEmpty);
    });
  });

  group('an unresolvable window degrades rather than failing', () {
    // Ticket #12 requires the no-window case to be a documented no-op instead
    // of an error. Every ported operation has to hold that line.
    test('no ported operation throws when no window resolves', () async {
      await expectLater(ffi.setEnglishKeyboard(), completes);
      await expectLater(ffi.isEnglishKeyboard(), completes);
      await expectLater(ffi.getCurrentInputSource(), completes);
      await expectLater(ffi.setInputSource('00000412:1:0'), completes);
      await expectLater(ffi.disableIME(), completes);
      await expectLater(ffi.enableIME(), completes);
    });
  });
}
