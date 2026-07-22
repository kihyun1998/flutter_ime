// The trigger contract: who starts it, who stops it, and what a trigger is
// allowed to be.
//
// `value_poller_test.dart` already covers the change rules through the timer
// flavour. What is only testable here is the half macOS depends on — that the
// trigger is started and stopped in balance with the listeners, and that a
// trigger which turns out to be nothing emits nothing. macOS posts the
// input-source notification twice for a single keyboard switch, so "a trigger
// is not a change" is load-bearing rather than defensive.
library;

import 'package:flutter_ime/src/change_stream.dart';
import 'package:flutter_test/flutter_test.dart';

/// A trigger the test fires by hand, counting how often it was started and
/// stopped. Standing in for the native observer, which cannot be registered
/// from a test.
class _FakeTrigger {
  int starts = 0;
  int stops = 0;
  void Function()? _reread;

  bool get running => _reread != null;

  void start(void Function() reread) {
    starts++;
    _reread = reread;
  }

  void stop() {
    stops++;
    _reread = null;
  }

  /// Delivers one trigger, as the notification centre would.
  void fire() => _reread?.call();
}

void main() {
  late _FakeTrigger trigger;

  setUp(() => trigger = _FakeTrigger());

  ChangeStream<T> streamOf<T extends Object>(T? Function() read) =>
      ChangeStream<T>(read: read, start: trigger.start, stop: trigger.stop);

  group('the trigger runs only while something is listening', () {
    test('nothing is started before the first listener arrives', () {
      streamOf<bool>(() => false);

      expect(trigger.starts, 0);
    });

    test('the first listener starts it', () {
      final changes = streamOf<bool>(() => false);
      final subscription = changes.stream.listen((_) {});
      addTearDown(subscription.cancel);

      expect(trigger.starts, 1);
      expect(trigger.running, isTrue);
    });

    test('a second listener does not start it again', () async {
      final changes = streamOf<bool>(() => false);
      final first = changes.stream.listen((_) {});
      final second = changes.stream.listen((_) {});

      expect(trigger.starts, 1);

      await first.cancel();
      await second.cancel();
    });

    test('the last cancel stops it', () async {
      final changes = streamOf<bool>(() => false);
      final first = changes.stream.listen((_) {});
      final second = changes.stream.listen((_) {});

      await first.cancel();
      expect(trigger.stops, 0, reason: 'one listener remains');

      await second.cancel();
      expect(trigger.stops, 1);
      expect(trigger.running, isFalse);
    });

    test('repeated listen/cancel cycles start and stop in balance', () async {
      // The leak this guards against is a native one: every start registers a
      // notification observer and a native callable, and an unbalanced stop
      // leaves both alive with nothing to close them.
      final changes = streamOf<bool>(() => false);

      for (var i = 0; i < 5; i++) {
        final subscription = changes.stream.listen((_) {});
        await subscription.cancel();
      }

      expect(trigger.starts, 5);
      expect(trigger.stops, 5);
      expect(trigger.running, isFalse);
    });

    test('dispose stops a running trigger', () {
      final changes = streamOf<bool>(() => false);
      changes.stream.listen((_) {});

      changes.dispose();

      expect(trigger.stops, 1);
      expect(trigger.running, isFalse);
    });

    test('dispose without a listener does not throw', () {
      // Nothing was ever started, so stop has nothing to undo. It still runs,
      // which is why the callback has to tolerate it.
      final changes = streamOf<bool>(() => false);

      expect(changes.dispose, returnsNormally);
      expect(trigger.stops, 1);
    });
  });

  group('a trigger is not a change', () {
    test('a trigger with the same value emits nothing', () async {
      final changes = streamOf<bool>(() => false);
      final seen = <bool>[];
      final subscription = changes.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      trigger.fire();
      trigger.fire();
      await pumpEventQueue();

      expect(seen, isEmpty);
    });

    test('macOS firing twice for one switch emits once', () async {
      // Exactly the observed behaviour: switching keyboard posts the
      // notification twice, and a consumer reverting an unwanted switch must
      // not see the change twice.
      var english = false;
      final changes = streamOf<bool>(() => english);
      final seen = <bool>[];
      final subscription = changes.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      english = true;
      trigger.fire();
      trigger.fire();
      await pumpEventQueue();

      expect(seen, [true]);
    });

    test('an unreadable value is skipped and the baseline survives it',
        () async {
      bool? value = false;
      final changes = streamOf<bool>(() => value);
      final seen = <bool>[];
      final subscription = changes.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      value = null;
      trigger.fire();
      value = false;
      trigger.fire();
      await pumpEventQueue();

      expect(seen, isEmpty, reason: 'the value never actually moved');
    });

    test('a throwing read neither emits nor stops the trigger', () async {
      var shouldThrow = false;
      final changes = streamOf<bool>(() {
        if (shouldThrow) throw StateError('unreadable');
        return true;
      });
      final seen = <bool>[];
      final subscription = changes.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      shouldThrow = true;
      trigger.fire();
      await pumpEventQueue();

      expect(seen, isEmpty);
      expect(trigger.running, isTrue);
    });
  });

  group('changes reach the listener', () {
    test('a trigger after a real change emits it', () async {
      var english = false;
      final changes = streamOf<bool>(() => english);
      final seen = <bool>[];
      final subscription = changes.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      english = true;
      trigger.fire();
      english = false;
      trigger.fire();
      await pumpEventQueue();

      expect(seen, [true, false]);
    });

    test('the value at subscription time is not emitted', () async {
      final changes = streamOf<bool>(() => true);
      final seen = <bool>[];
      final subscription = changes.stream.listen(seen.add);
      addTearDown(subscription.cancel);

      trigger.fire();
      await pumpEventQueue();

      expect(seen, isEmpty);
    });

    test('every listener gets the same change', () async {
      var english = false;
      final changes = streamOf<bool>(() => english);
      final first = <bool>[];
      final second = <bool>[];
      final a = changes.stream.listen(first.add);
      final b = changes.stream.listen(second.add);

      english = true;
      trigger.fire();
      await pumpEventQueue();

      expect(first, [true]);
      expect(second, [true]);

      await a.cancel();
      await b.cancel();
    });
  });
}
