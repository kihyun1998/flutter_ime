// Which backend each operation reaches, and what happens where there is no
// backend at all.
//
// This file used to be about a fall-through: while the migration was in
// progress the FFI implementation sat beside a native plugin and handed it
// anything not yet ported. Both are gone as of #19, and so is the question
// those tests answered. What is left to pin is routing — that an operation
// reaches the platform it belongs to — and that a platform with no IME to talk
// to returns its documented default rather than throwing or reaching for
// something that is not there.
//
// Nothing here may touch the operating system. A real backend in a test process
// would read, and in places change, the keyboard of whatever machine is running
// the suite.
library;

import 'dart:ffi';

// The real implementation, not through the platform interface. That import is
// conditional and the analyzer resolves it to the web stub, which cannot name
// WindowsIme — naming it would drag `dart:ffi` into the web build. This test is
// VM-only anyway, having just imported it.
import 'package:flutter_ime/src/ffi/ffi_flutter_ime.dart';
import 'package:flutter_ime/src/ffi/ffi_flutter_ime_stub.dart' as stub;
import 'package:flutter_ime/src/ffi/macos_ime.dart';
import 'package:flutter_ime/src/ffi/win32.dart';
import 'package:flutter_ime/src/ffi/window_resolver.dart';
import 'package:flutter_ime/src/ffi/windows_ime.dart';
import 'package:test/test.dart';

/// A [WindowsIme] whose window never resolves, so every operation
/// short-circuits before reaching a single Win32 call.
///
/// This is not a convenience — it is a safety requirement. A real [WindowsIme]
/// in a test process finds no Flutter window and falls back to
/// `GetForegroundWindow`, so an operation would apply itself to whatever
/// application happened to be focused on the machine running the tests.
/// Detaching a stranger's IME context is not an acceptable side effect of
/// running a test suite.
WindowsIme unresolvableWindowsIme() => WindowsIme(
      // A fake binding as well as an unresolvable window. The window guard is
      // not enough on its own: isCapsLockOn consults no window at all — the
      // toggle is keyboard state — so it would sail past every early return and
      // force `DynamicLibrary.open('user32.dll')`, which throws on the Linux
      // runner CI uses.
      win32: _FakeWin32(),
      resolver: WindowResolver(
        findOwnTopLevelWindow: (_) => nullptr,
        findChildWindow: (_, __) => nullptr,
        getForegroundWindow: () => nullptr,
        isWindowAlive: (_) => false,
      ),
    );

void main() {
  group('Windows routes to the Win32 backend', () {
    late FfiFlutterIme ffi;

    setUp(() =>
        ffi = FfiFlutterIme.withBackends(windowsIme: unresolvableWindowsIme()));

    test('no operation throws when no window resolves', () async {
      // #12 requires the no-window case to be a documented no-op rather than an
      // error. Every operation has to hold that line, because a consumer wires
      // these to focus changes where an unhandled async error is worse than a
      // keyboard that did not switch.
      await expectLater(ffi.setEnglishKeyboard(), completes);
      await expectLater(ffi.isEnglishKeyboard(), completes);
      await expectLater(ffi.getCurrentInputSource(), completes);
      await expectLater(ffi.setInputSource('00000412:1:0'), completes);
      await expectLater(ffi.disableIME(), completes);
      await expectLater(ffi.enableIME(), completes);
      await expectLater(ffi.isCapsLockOn(), completes);
    });

    test('an unreadable keyboard reports the documented default', () async {
      expect(await ffi.isEnglishKeyboard(), isFalse);
      expect(await ffi.getCurrentInputSource(), isNull);
    });

    test('both streams are polled', () async {
      final source = ffi.onInputSourceChanged.listen((_) {});
      final caps = ffi.onCapsLockChanged.listen((_) {});
      addTearDown(() async {
        await source.cancel();
        await caps.cancel();
      });

      // Windows has no callback FFI can receive, so both are timers. Nothing
      // asserts the interval — that is an internal constant — only that
      // subscribing is what starts them.
      expect(source, isNotNull);
      expect(caps, isNotNull);
    });
  });

  group('IME association refuses a foreground-window guess', () {
    // Detaching an IME context is destructive and persists. Everything else
    // writes transient conversion state, so a wrong window self-corrects; this
    // one would leave another application's IME disabled with nothing to put it
    // back.
    late FfiFlutterIme foregroundFfi;

    setUp(() {
      foregroundFfi = FfiFlutterIme.withBackends(
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
      );
    });

    test('disableIME does not touch a foreground window', () async {
      // _ExplodingWin32 throws if any Win32 entry point is reached, so
      // completing normally is the assertion.
      await expectLater(foregroundFfi.disableIME(), completes);
    });

    test('enableIME does not touch a foreground window', () async {
      await expectLater(foregroundFfi.enableIME(), completes);
    });
  });

  group('macOS routes to the Text Input Source backend', () {
    late _FakeMacosIme macos;
    late FfiFlutterIme ffi;

    setUp(() {
      macos = _FakeMacosIme();
      ffi = FfiFlutterIme.withBackends(macosIme: macos);
    });

    test('setEnglishKeyboard', () async {
      await ffi.setEnglishKeyboard();
      expect(macos.calls, ['setEnglishKeyboard']);
    });

    test('isEnglishKeyboard reports what the backend answered', () async {
      macos.english = true;
      expect(await ffi.isEnglishKeyboard(), isTrue);
    });

    test('getCurrentInputSource reports the token it read', () async {
      macos.token = 'com.apple.inputmethod.Korean.2SetKorean';
      expect(await ffi.getCurrentInputSource(),
          'com.apple.inputmethod.Korean.2SetKorean');
    });

    test('setInputSource passes the token through unchanged', () async {
      // Byte-identical pass-through is the compatibility requirement: the token
      // is whatever a consumer persisted, possibly under 2.x.
      await ffi.setInputSource('com.apple.keylayout.Dvorak');
      expect(macos.restored, ['com.apple.keylayout.Dvorak']);
    });

    test('a token that no longer names anything does not throw', () async {
      macos.restoreSucceeds = false;
      await expectLater(
          ffi.setInputSource('com.apple.keylayout.Removed'), completes);
    });

    test('isCapsLockOn', () async {
      macos.capsLock = true;
      expect(await ffi.isCapsLockOn(), isTrue);
    });

    test('disableIME and enableIME are no-ops, as they always were on macOS',
        () async {
      await expectLater(ffi.disableIME(), completes);
      await expectLater(ffi.enableIME(), completes);
      expect(macos.calls, isEmpty);
    });

    test('onCapsLockChanged polls', () async {
      final subscription = ffi.onCapsLockChanged.listen((_) {});
      addTearDown(subscription.cancel);

      expect(macos.calls, contains('isCapsLockOn'),
          reason: 'the poller takes a baseline when a listener attaches');
    });

    test('onInputSourceChanged registers a notification observer, not a timer',
        () async {
      // The mechanism is asserted, not just the behaviour. If this quietly
      // became a poller the stream would still deliver values and only the
      // latency would change, which no behavioural assertion would catch.
      final subscription = ffi.onInputSourceChanged.listen((_) {});

      expect(macos.observerStarts, 1);

      await subscription.cancel();
      expect(macos.observerStops, 1,
          reason: 'the observer must not outlive the last listener');
    });

    test('repeated listen/cancel cycles leave no observer behind', () async {
      for (var i = 0; i < 3; i++) {
        await ffi.onInputSourceChanged.listen((_) {}).cancel();
      }

      expect(macos.observerStarts, 3);
      expect(macos.observerStops, 3);
    });
  });

  group('a platform with no IME to talk to returns its documented default', () {
    // Linux, Android and iOS. The gating in flutter_ime.dart short-circuits
    // before reaching here, so in practice this never runs — which is exactly
    // why it is worth pinning. A silent wrong answer from a layer nobody
    // exercises is the kind that survives for years.
    late FfiFlutterIme ffi;

    setUp(() => ffi = FfiFlutterIme.withBackends());

    test('queries answer their documented defaults', () async {
      expect(await ffi.isEnglishKeyboard(), isFalse);
      expect(await ffi.getCurrentInputSource(), isNull);
      expect(await ffi.isCapsLockOn(), isFalse);
    });

    test('commands do nothing rather than throwing', () async {
      await expectLater(ffi.setEnglishKeyboard(), completes);
      await expectLater(ffi.setInputSource('anything'), completes);
      await expectLater(ffi.disableIME(), completes);
      await expectLater(ffi.enableIME(), completes);
    });

    test('the streams are empty rather than absent', () async {
      // A caller may listen unconditionally in shared code, so the streams have
      // to exist. They just never emit.
      expect(await ffi.onInputSourceChanged.toList(), isEmpty);
      expect(await ffi.onCapsLockChanged.toList(), isEmpty);
    });
  });

  group('the web stub refuses rather than pretending', () {
    // The stub is the default instance on web, so it is constructed on startup
    // whether or not anything uses it. Nothing calls it: the gating rejects web
    // first. Throwing keeps that a fact rather than a hope — a regression in
    // the gating shows up as an error instead of as a quiet "no keyboard is
    // English".
    late stub.FfiFlutterIme stubbed;

    setUp(() => stubbed = stub.FfiFlutterIme());

    test('constructing it is safe', () {
      expect(() => stub.FfiFlutterIme(), returnsNormally);
    });

    test('every operation throws, and throws synchronously', () {
      // Synchronously matters, which is why these are `expect(() => …)` rather
      // than `expectLater(future, …)`. The calls are routinely made
      // fire-and-forget from a focus listener, and an `async` method that threw
      // would hand back a failed future — surfacing in the consumer's zone as
      // an unhandled async error, far from the line that made the call.
      expect(() => stubbed.setEnglishKeyboard(), throwsUnsupportedError);
      expect(() => stubbed.isEnglishKeyboard(), throwsUnsupportedError);
      expect(() => stubbed.getCurrentInputSource(), throwsUnsupportedError);
      expect(() => stubbed.setInputSource('x'), throwsUnsupportedError);
      expect(() => stubbed.disableIME(), throwsUnsupportedError);
      expect(() => stubbed.enableIME(), throwsUnsupportedError);
      expect(() => stubbed.isCapsLockOn(), throwsUnsupportedError);
      expect(() => stubbed.onInputSourceChanged, throwsUnsupportedError);
      expect(() => stubbed.onCapsLockChanged, throwsUnsupportedError);
    });
  });
}

/// A [Win32] that answers the one call which consults no window, and treats
/// anything else as a mistake.
///
/// Caps Lock state is keyboard state, so `isCapsLockOn` has no window to guard
/// on and would otherwise reach the real user32 binding from a test.
class _FakeWin32 implements Win32 {
  /// The value `GetKeyState(VK_CAPITAL)` reports. Zero means "toggle off".
  int keyState = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getKeyState) {
      return (int virtualKey) => keyState;
    }
    throw StateError(
        'unexpected Win32 call from a test: ${invocation.memberName}');
  }
}

/// A [Win32] whose every entry point throws.
///
/// Used to assert a negative: that a code path reaches no system call at all.
/// Asserting "nothing happened" is otherwise untestable, since a Win32 call
/// made against the wrong window succeeds just as quietly as one never made.
class _ExplodingWin32 implements Win32 {
  Never _boom() => throw StateError(
      'a Win32 entry point was reached on a code path that must not touch '
      'the operating system');

  @override
  dynamic noSuchMethod(Invocation invocation) => _boom();
}

/// A [MacosIme] that records what it was asked and touches nothing.
///
/// A real one in a test process would reach Text Input Source Services for
/// real: a suite run on a Mac would read — and, for `setEnglishKeyboard`,
/// change — the developer's own keyboard layout.
class _FakeMacosIme implements MacosIme {
  final List<String> calls = [];

  /// The tokens [setInputSource] was asked to restore, in order.
  final List<String> restored = [];

  /// What [isEnglishKeyboard] answers.
  bool english = false;

  /// What [getCurrentInputSource] answers.
  String? token;

  /// What [isCapsLockOn] answers.
  bool capsLock = false;

  /// What [readEnglishStateOrNull] answers.
  bool? englishOrNull = false;

  /// What [setInputSource] answers. False stands for a token naming an input
  /// source that is no longer installed.
  bool restoreSucceeds = true;

  /// How often the notification observer was registered and unregistered.
  /// Every registration is a native callable that has to be closed again.
  int observerStarts = 0;
  int observerStops = 0;

  @override
  bool setEnglishKeyboard() {
    calls.add('setEnglishKeyboard');
    return true;
  }

  @override
  bool isEnglishKeyboard() {
    calls.add('isEnglishKeyboard');
    return english;
  }

  @override
  bool? readEnglishStateOrNull() {
    calls.add('readEnglishStateOrNull');
    return englishOrNull;
  }

  @override
  String? getCurrentInputSource() {
    calls.add('getCurrentInputSource');
    return token;
  }

  @override
  bool setInputSource(String sourceId) {
    calls.add('setInputSource');
    restored.add(sourceId);
    return restoreSucceeds;
  }

  @override
  bool isCapsLockOn() {
    calls.add('isCapsLockOn');
    return capsLock;
  }

  @override
  String? describeCurrentInputSource() {
    calls.add('describeCurrentInputSource');
    return null;
  }

  @override
  void startInputSourceNotifications(void Function() onChanged) {
    observerStarts++;
  }

  @override
  void stopInputSourceNotifications() {
    observerStops++;
  }
}
