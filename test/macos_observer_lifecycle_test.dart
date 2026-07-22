// How the macOS input-source observer is registered and unregistered, checked
// against fake CoreFoundation bindings rather than the real notification
// centre.
//
// This exists because of a crash found while driving the example app:
//
//   Restarted application in 213ms.
//   error: Callback invoked after it has been deleted.
//     __CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__
//     DLRT_GetFfiCallbackMetadata
//
// A registration lives in the notification centre, which belongs to the
// process. A NativeCallable belongs to its isolate. Hot restart destroys the
// isolate and leaves the registration pointing at a deleted trampoline, with no
// Dart code running on the way out to unregister it.
//
// **What is asserted here is the protocol, not the delivery.** An earlier
// version of this file posted a real notification and watched for the crash,
// which worked under `flutter test` and cannot work now: distributed
// notifications arrive on the main dispatch queue, and a plain Dart test runs
// its isolate on a worker thread that never drains it. A test that silently
// fails to deliver would exercise nothing while looking like coverage. So the
// rules the fix turns on are checked directly — the token is the shared one, a
// stale registration is cleared before a new one is made, and stopping does not
// close the callable — and the delivery path itself stays where it was
// verified: by hand, on a real machine, in a real app.
library;

import 'dart:ffi';

import 'package:flutter_ime/src/ffi/core_foundation.dart';
import 'package:flutter_ime/src/ffi/macos_ime.dart';
import 'package:flutter_ime/src/ffi/text_input_sources.dart';
import 'package:test/test.dart';

/// A distinct address per role, so a test can tell which pointer was passed
/// where. Nothing is ever dereferenced.
CFRef _sentinel(int address) => Pointer<Void>.fromAddress(address);

final CFRef _notificationName = _sentinel(0xA000);
final CFRef _distributedCentre = _sentinel(0xB000);

/// One call to the notification centre.
typedef _ObserverCall = ({String kind, CFRef token, int behaviour});

/// Records the notification-centre calls and answers nothing else.
class _FakeCoreFoundation implements CoreFoundation {
  final List<_ObserverCall> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #notificationCenterGetDistributedCenter:
        return () => _distributedCentre;
      case #notificationCenterAddObserver:
        return (CFRef centre, CFRef token, Pointer<NativeFunction> callback,
            CFRef name, CFRef object, int behaviour) {
          expect(centre, _distributedCentre);
          expect(name, _notificationName,
              reason: 'the notification subscribed to');
          calls.add((kind: 'add', token: token, behaviour: behaviour));
        };
      case #notificationCenterRemoveObserver:
        return (CFRef centre, CFRef token, CFRef name, CFRef object) {
          expect(centre, _distributedCentre);
          calls.add((kind: 'remove', token: token, behaviour: -1));
        };
      default:
        throw StateError(
            'unexpected CoreFoundation call: ${invocation.memberName}');
    }
  }
}

class _FakeTextInputSources implements TextInputSources {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #notifySelectedKeyboardInputSourceChanged) {
      return _notificationName;
    }
    throw StateError(
        'unexpected Text Input Sources call: ${invocation.memberName}');
  }
}

void main() {
  late _FakeCoreFoundation cf;
  late MacosIme ime;

  MacosIme build() => MacosIme(
        coreFoundation: cf,
        textInputSources: _FakeTextInputSources(),
      );

  setUp(() {
    cf = _FakeCoreFoundation();
    ime = build();
  });

  List<String> kinds() => cf.calls.map((c) => c.kind).toList();

  group('the observer token is one every isolate can compute', () {
    test('it is the notification name, not the callable address', () {
      // The crux of the hot-restart fix. Filing the registration under the
      // callable's own address — the obvious choice, and the original one —
      // means the isolate that inherits the wreckage has no way to name it, so
      // the registration can never be removed by anyone.
      ime.startInputSourceNotifications(() {});

      expect(cf.calls.map((c) => c.token).toSet(), {_notificationName});
    });

    test('start and stop use the same token', () {
      ime.startInputSourceNotifications(() {});
      final registered = cf.calls.last.token;
      cf.calls.clear();

      ime.stopInputSourceNotifications();

      expect(cf.calls.single.token, registered);
    });
  });

  group('a stale registration is cleared before a new one is made', () {
    test('constructing clears whatever was left behind', () {
      // The earliest moment this package gets to run any code. A consumer who
      // installs the implementation at startup is covered from then on rather
      // than from whenever something first subscribes.
      expect(kinds(), ['remove']);
    });

    test('starting removes before it adds', () {
      cf.calls.clear();

      ime.startInputSourceNotifications(() {});

      expect(kinds(), ['remove', 'add'],
          reason: 'adding first would leave the predecessor registration live '
              'alongside the new one');
    });

    test('the registration asks for immediate delivery', () {
      // Coalescing would merge the two notifications macOS posts for one
      // keyboard switch, which sounds helpful and is not: the point of the
      // stream is that a change arrives before the user types the next
      // character.
      cf.calls.clear();

      ime.startInputSourceNotifications(() {});

      expect(cf.calls.last.behaviour,
          cfNotificationSuspensionBehaviorDeliverImmediately);
    });

    test('starting twice registers once', () {
      cf.calls.clear();

      ime.startInputSourceNotifications(() {});
      ime.startInputSourceNotifications(() {});

      expect(kinds().where((k) => k == 'add'), hasLength(1));
    });
  });

  group('stopping unregisters without closing the callable', () {
    test('stopping removes the observer', () {
      ime.startInputSourceNotifications(() {});
      cf.calls.clear();

      ime.stopInputSourceNotifications();

      expect(kinds(), ['remove']);
    });

    test('stopping twice removes once', () {
      ime.startInputSourceNotifications(() {});
      cf.calls.clear();

      ime.stopInputSourceNotifications();
      ime.stopInputSourceNotifications();

      expect(kinds(), ['remove']);
    });

    test('stopping without starting does nothing', () {
      cf.calls.clear();

      ime.stopInputSourceNotifications();

      expect(cf.calls, isEmpty);
    });

    test('a stopped observer can be started again', () {
      // The callable is reused rather than rebuilt, so a second subscription
      // has to re-register it rather than assume it is still registered.
      ime.startInputSourceNotifications(() {});
      ime.stopInputSourceNotifications();
      cf.calls.clear();

      ime.startInputSourceNotifications(() {});

      expect(kinds(), ['remove', 'add']);
    });

    test('many cycles register and unregister in balance', () {
      cf.calls.clear();

      for (var i = 0; i < 10; i++) {
        ime.startInputSourceNotifications(() {});
        ime.stopInputSourceNotifications();
      }

      expect(kinds().where((k) => k == 'add'), hasLength(10));
      expect(kinds().where((k) => k == 'remove'), hasLength(20),
          reason: 'each start clears first, then each stop unregisters');
    });
  });
}
