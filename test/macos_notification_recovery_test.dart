// The hot-restart crash, and the recovery that keeps it from happening twice.
//
// Reported from the example app as:
//
//   Restarted application in 213ms.
//   error: Callback invoked after it has been deleted.
//     __CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__
//     DLRT_GetFfiCallbackMetadata
//
// A registration lives in the notification centre, which belongs to the
// process. A NativeCallable belongs to its isolate. Hot restart destroys the
// isolate and leaves the registration pointing at a deleted trampoline, with no
// Dart code running on the way out to unregister it. The next keyboard switch
// calls into freed memory.
//
// This stands in for the two isolates within one process: register, close the
// callable without unregistering — exactly the state hot restart leaves behind
// — and check that a fresh registration cleans up after its predecessor
// instead of inheriting a landmine.
//
// **The notification is posted rather than provoked.** Switching the keyboard
// for real would work, but `flutter test` has no business changing the layout
// of the machine it runs on, and a test that restores what it changed is still
// a test that changed it. Posting the same notification exercises the same
// delivery path and touches nothing.
//
// macOS-only, and reaches the real notification centre, so it does not run on
// CI. Everything it checks is observable only by not crashing, which is why it
// is a test rather than a comment.
@TestOn('mac-os')
library;

import 'dart:ffi';

import 'package:flutter_ime/src/ffi/core_foundation.dart';
import 'package:flutter_ime/src/ffi/macos_ime.dart';
import 'package:flutter_ime/src/ffi/text_input_sources.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _PostNative = Void Function(CFRef, CFRef, CFRef, CFRef, Uint8);
typedef _PostDart = void Function(CFRef, CFRef, CFRef, CFRef, int);

final _cf = CoreFoundation.instance;
final _tis = TextInputSources.instance;

/// Posts the input-source-changed notification without changing anything.
///
/// Test-only, which is why the binding lives here rather than in
/// `core_foundation.dart`: the package observes this notification and has no
/// reason to ever post it.
final _post = DynamicLibrary.open(
        '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation')
    .lookupFunction<_PostNative, _PostDart>(
        'CFNotificationCenterPostNotification');

Future<void> postInputSourceChanged() async {
  _post(
    _cf.notificationCenterGetDistributedCenter(),
    _tis.notifySelectedKeyboardInputSourceChanged,
    nullptr,
    nullptr,
    1, // deliverImmediately
  );
  // Delivery is a hop through the main dispatch queue, not a direct call.
  await Future<void>.delayed(const Duration(milliseconds: 500));
}

/// Leaves the process in the state hot restart leaves it in: a live
/// registration whose callable has been deleted.
///
/// Uses the token [MacosIme] uses, since the whole question is whether the next
/// registration can find this one.
void abandonARegistration() {
  final orphan = NativeCallable<CFNotificationCallbackNative>.listener(
    (CFRef _, CFRef __, CFRef ___, CFRef ____, CFRef _____) {},
  );
  _cf.notificationCenterAddObserver(
    _cf.notificationCenterGetDistributedCenter(),
    _tis.notifySelectedKeyboardInputSourceChanged,
    orphan.nativeFunction,
    _tis.notifySelectedKeyboardInputSourceChanged,
    nullptr,
    cfNotificationSuspensionBehaviorDeliverImmediately,
  );
  orphan.close();
}

void main() {
  test('a registration orphaned by hot restart is cleaned up, not inherited',
      () async {
    final ime = MacosIme();

    abandonARegistration();

    var fired = 0;
    ime.startInputSourceNotifications(() => fired++);
    addTearDown(ime.stopInputSourceNotifications);

    // The delivery that used to take the process down. Surviving it is most of
    // the assertion; the rest is that the live observer still works, since
    // removing too much would be just as wrong as removing too little.
    await postInputSourceChanged();

    expect(fired, greaterThan(0),
        reason: 'the fresh observer must survive its own cleanup');
  });

  test('nothing is delivered after stop', () async {
    final ime = MacosIme();

    var fired = 0;
    ime.startInputSourceNotifications(() => fired++);
    // A second start must not register a second observer. Sharing one token
    // means a second registration would displace the first, silently leaving
    // the stream dead.
    ime.startInputSourceNotifications(() => fired++);

    ime.stopInputSourceNotifications();
    // Stopping twice must not throw and must not close an already-closed
    // callable.
    ime.stopInputSourceNotifications();

    await postInputSourceChanged();

    expect(fired, 0);
  });

  test('a delivery already in flight when the last listener cancels is safe',
      () async {
    // The release-build half of this crash, and the reason the callable is
    // never closed. Delivery is a hop through the main dispatch queue, so a
    // notification posted just before a cancel is already enqueued with the
    // callback address captured, and removing the observer cannot un-enqueue
    // it. If cancelling closed the callable, this block would call into freed
    // memory — no hot restart required.
    //
    // Surviving the pump below is the assertion.
    final ime = MacosIme();

    var fired = 0;
    ime.startInputSourceNotifications(() => fired++);

    _post(
      _cf.notificationCenterGetDistributedCenter(),
      _tis.notifySelectedKeyboardInputSourceChanged,
      nullptr,
      nullptr,
      1,
    );
    // No await: cancel while the delivery is still in the queue.
    ime.stopInputSourceNotifications();

    await Future<void>.delayed(const Duration(seconds: 1));

    // Whether the in-flight one lands before or after the disarm is a race and
    // is not asserted. That it cannot crash either way is the point.
    expect(fired, anyOf(0, greaterThan(0)));
  });

  test('repeated start/stop cycles stay deliverable', () async {
    // Each cycle registers a callable and closes it again. If a cycle ever
    // left one behind, a later delivery would reach it after deletion.
    final ime = MacosIme();

    for (var i = 0; i < 10; i++) {
      ime.startInputSourceNotifications(() {});
      ime.stopInputSourceNotifications();
    }

    var fired = 0;
    ime.startInputSourceNotifications(() => fired++);
    addTearDown(ime.stopInputSourceNotifications);

    await postInputSourceChanged();

    expect(fired, greaterThan(0));
  });
}
