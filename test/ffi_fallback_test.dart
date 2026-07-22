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
import 'package:flutter_ime/src/ffi/ffi_flutter_ime_stub.dart' as stub;
import 'package:flutter_ime/src/ffi/win32.dart';
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

  group('every Windows operation now reaches FFI, not the native plugin', () {
    // Sending a ported operation to the native plugin as well would mean doing
    // the work twice, or doing it through the layer this migration exists to
    // remove. With #15 the Windows set is complete, so nothing here may
    // delegate.
    test('isCapsLockOn', () async {
      await ffi.isCapsLockOn();
      expect(fallback.calls, isEmpty);
    });

    test('onInputSourceChanged', () async {
      final subscription = ffi.onInputSourceChanged.listen((_) {});
      addTearDown(subscription.cancel);

      expect(fallback.calls, isEmpty);
    });

    test('onCapsLockChanged', () async {
      final subscription = ffi.onCapsLockChanged.listen((_) {});
      addTearDown(subscription.cancel);

      expect(fallback.calls, isEmpty);
    });

    test('the streams stay silent while the value never changes', () async {
      final events = <bool>[];
      final subscription = ffi.onCapsLockChanged.listen(events.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(events, isEmpty);
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

  group('IME association refuses a foreground-window guess', () {
    // Detaching an IME context is destructive and persists. Everything else
    // here writes transient conversion state, so a wrong window self-corrects;
    // this one would leave another application's IME disabled with nothing to
    // put it back.
    late MockFlutterImePlatform foregroundFallback;
    late FfiFlutterIme foregroundFfi;

    setUp(() {
      foregroundFallback = MockFlutterImePlatform();
      foregroundFfi = FfiFlutterIme(
        windowsIme: WindowsIme(
          win32: _ExplodingWin32(),
          resolver: WindowResolver(
            // No window of ours, so resolution falls back to the foreground.
            findOwnTopLevelWindow: (_) => nullptr,
            findChildWindow: (_, __) => nullptr,
            getForegroundWindow: () => Pointer<Void>.fromAddress(0xBEEF),
            isWindowAlive: (_) => true,
          ),
        ),
        fallback: foregroundFallback,
      );
    });

    tearDown(() => foregroundFallback.dispose());

    test('disableIME does not touch a foreground window', () async {
      // _ExplodingWin32 throws if any Win32 entry point is reached, so
      // completing normally is the assertion.
      await expectLater(foregroundFfi.disableIME(), completes);
    });

    test('enableIME does not touch a foreground window', () async {
      await expectLater(foregroundFfi.enableIME(), completes);
    });
  });

  group('where there is no FFI implementation, everything falls through', () {
    // The web stub is the shipping form of "this platform has no FFI backend",
    // and it is also the shape macOS is in until its own tickets land. The
    // fall-through is what makes a half-ported instance safe to install at any
    // moment — an earlier version threw instead, and crashed the example app on
    // a page transition.
    late MockFlutterImePlatform stubFallback;
    late stub.FfiFlutterIme stubbed;

    setUp(() {
      stubFallback = MockFlutterImePlatform();
      stubbed = stub.FfiFlutterIme(fallback: stubFallback);
    });

    tearDown(() => stubFallback.dispose());

    test('every operation reaches the native plugin', () async {
      await stubbed.setEnglishKeyboard();
      await stubbed.isEnglishKeyboard();
      await stubbed.getCurrentInputSource();
      await stubbed.setInputSource('00000412:1:0');
      await stubbed.disableIME();
      await stubbed.enableIME();
      await stubbed.isCapsLockOn();
      stubbed.onInputSourceChanged.listen((_) {}).cancel();
      stubbed.onCapsLockChanged.listen((_) {}).cancel();

      expect(
          stubFallback.calls,
          containsAll(<String>[
            'setEnglishKeyboard',
            'isEnglishKeyboard',
            'getCurrentInputSource',
            'setInputSource',
            'disableIME',
            'enableIME',
            'isCapsLockOn',
            'onInputSourceChanged',
            'onCapsLockChanged',
          ]));
    });

    test('no operation throws', () async {
      await expectLater(stubbed.disableIME(), completes);
      expect(() => stubbed.onInputSourceChanged, returnsNormally);
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
      await expectLater(ffi.isCapsLockOn(), completes);
    });
  });
}

/// A [Win32] whose every entry point throws.
///
/// Used to assert a negative: that a code path reaches no system call at all.
/// Asserting "nothing happened" is otherwise untestable, since a Win32 call
/// that is made against the wrong window succeeds just as quietly as one that
/// is never made.
class _ExplodingWin32 implements Win32 {
  Never _boom() => throw StateError(
      'a Win32 entry point was reached on a code path that must not touch '
      'the operating system');

  @override
  dynamic noSuchMethod(Invocation invocation) => _boom();
}
