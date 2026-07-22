// The polling unit that drives both Windows event streams.
//
// Everything here runs under FakeAsync with an injected reader, so the timing
// and de-duplication rules are covered with no real timer, no OS call, and no
// IME. That injection point is the seam agreed in #11 — the same shape the
// window resolver uses for its lookups.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_ime/src/value_poller.dart';
import 'package:flutter_test/flutter_test.dart';

const _interval = Duration(milliseconds: 100);

void main() {
  group('polls only while something is listening', () {
    test('never reads before the first listener arrives', () {
      fakeAsync((async) {
        var reads = 0;
        ValuePoller<bool>(
            read: () {
              reads++;
              return false;
            },
            interval: _interval);

        async.elapse(const Duration(seconds: 5));

        expect(reads, 0, reason: 'an unused stream must cost nothing');
      });
    });

    test('stops reading once the last listener cancels', () {
      fakeAsync((async) {
        var reads = 0;
        final poller = ValuePoller<bool>(
            read: () {
              reads++;
              return false;
            },
            interval: _interval);

        final subscription = poller.stream.listen((_) {});
        async.elapse(const Duration(seconds: 1));
        expect(reads, greaterThan(1));

        subscription.cancel();
        final afterCancel = reads;
        async.elapse(const Duration(seconds: 5));

        expect(reads, afterCancel);
      });
    });

    test('keeps polling while any listener remains', () {
      fakeAsync((async) {
        var reads = 0;
        final poller = ValuePoller<bool>(
            read: () {
              reads++;
              return false;
            },
            interval: _interval);

        final first = poller.stream.listen((_) {});
        final second = poller.stream.listen((_) {});
        async.elapse(const Duration(seconds: 1));

        first.cancel();
        final afterFirstCancel = reads;
        async.elapse(const Duration(seconds: 1));
        expect(reads, greaterThan(afterFirstCancel),
            reason: 'the second listener still wants events');

        second.cancel();
        final afterBothCancelled = reads;
        async.elapse(const Duration(seconds: 1));
        expect(reads, afterBothCancelled);
      });
    });

    test('resumes polling when a new listener arrives after a cancel', () {
      fakeAsync((async) {
        var reads = 0;
        final poller = ValuePoller<bool>(
            read: () {
              reads++;
              return false;
            },
            interval: _interval);

        poller.stream.listen((_) {}).cancel();
        final afterCancel = reads;

        poller.stream.listen((_) {});
        async.elapse(const Duration(seconds: 1));

        expect(reads, greaterThan(afterCancel));
      });
    });
  });

  group('emits changes only', () {
    test('does not emit the value it started from', () {
      fakeAsync((async) {
        final events = <bool>[];
        final poller = ValuePoller<bool>(read: () => true, interval: _interval);

        poller.stream.listen(events.add);
        async.elapse(const Duration(seconds: 1));

        // The native plugin captures the state as a baseline when a listener
        // attaches and reports only subsequent changes. A stream called
        // "onChanged" that fires once just for existing would be a surprise.
        expect(events, isEmpty);
      });
    });

    test('emits when the value changes', () {
      fakeAsync((async) {
        var current = false;
        final events = <bool>[];
        final poller =
            ValuePoller<bool>(read: () => current, interval: _interval);

        poller.stream.listen(events.add);
        async.elapse(_interval * 2);

        current = true;
        async.elapse(_interval * 2);

        expect(events, [true]);
      });
    });

    test('never emits the same value twice in a row', () {
      fakeAsync((async) {
        var current = false;
        final events = <bool>[];
        final poller =
            ValuePoller<bool>(read: () => current, interval: _interval);

        poller.stream.listen(events.add);
        current = true;
        async.elapse(const Duration(seconds: 2));

        expect(events, [true], reason: 'many polls, one change');
      });
    });

    test('emits again when the value changes back', () {
      fakeAsync((async) {
        var current = false;
        final events = <bool>[];
        final poller =
            ValuePoller<bool>(read: () => current, interval: _interval);

        poller.stream.listen(events.add);
        current = true;
        async.elapse(_interval * 2);
        current = false;
        async.elapse(_interval * 2);
        current = true;
        async.elapse(_interval * 2);

        expect(events, [true, false, true]);
      });
    });

    test(
        're-baselines on a new listen, so changes while nobody listened are '
        'not replayed', () {
      fakeAsync((async) {
        var current = false;
        final events = <bool>[];
        final poller =
            ValuePoller<bool>(read: () => current, interval: _interval);

        poller.stream.listen((_) {}).cancel();

        // Caps Lock gets toggled while the app is not watching.
        current = true;

        poller.stream.listen(events.add);
        async.elapse(const Duration(seconds: 1));

        // Matches the native plugin, which re-reads the state as its baseline
        // whenever a sink attaches. The value is available from the one-shot
        // query; the stream reports transitions it actually observed.
        expect(events, isEmpty);
      });
    });

    test('delivers the same change to every listener', () {
      fakeAsync((async) {
        var current = false;
        final first = <bool>[];
        final second = <bool>[];
        final poller =
            ValuePoller<bool>(read: () => current, interval: _interval);

        poller.stream.listen(first.add);
        poller.stream.listen(second.add);
        current = true;
        async.elapse(_interval * 2);

        expect(first, [true]);
        expect(second, [true]);
      });
    });
  });

  group('an unreadable value is not a change', () {
    // The Windows IME conversion state cannot be read at all while
    // disableIME() has the context detached. Treating that as a value would
    // announce an input-source change on every disable and another on every
    // enable, neither of which happened.
    test('a null reading is skipped and the baseline survives it', () {
      fakeAsync((async) {
        var current = true;
        bool? readable = true;
        final events = <bool>[];
        final poller = ValuePoller<bool>(
            read: () => readable == null ? null : current, interval: _interval);

        poller.stream.listen(events.add);
        async.elapse(_interval * 2);

        // The IME context goes away and comes back unchanged.
        readable = null;
        async.elapse(_interval * 4);
        readable = true;
        async.elapse(_interval * 2);

        expect(events, isEmpty, reason: 'nothing actually changed');
      });
    });

    test('a change made while unreadable is reported once readable again', () {
      fakeAsync((async) {
        var current = true;
        bool? readable = true;
        final events = <bool>[];
        final poller = ValuePoller<bool>(
            read: () => readable == null ? null : current, interval: _interval);

        poller.stream.listen(events.add);
        async.elapse(_interval * 2);

        readable = null;
        current = false; // the user really did switch, unobserved
        async.elapse(_interval * 4);
        readable = true;
        async.elapse(_interval * 2);

        expect(events, [false]);
      });
    });

    test('a throwing reader neither emits nor stops the polling', () {
      fakeAsync((async) {
        var explode = true;
        var reads = 0;
        final events = <bool>[];
        final poller = ValuePoller<bool>(
            read: () {
              reads++;
              if (explode) throw StateError('transient');
              return true;
            },
            interval: _interval);

        poller.stream.listen(events.add);
        async.elapse(_interval * 3);
        expect(events, isEmpty);
        expect(reads, greaterThan(1), reason: 'polling must survive a throw');

        explode = false;
        async.elapse(_interval * 2);

        // First readable value becomes the baseline, not an event.
        expect(events, isEmpty);
      });
    });

    test(
        'a reader that throws on the very first read does not strand the '
        'stream', () {
      fakeAsync((async) {
        var explode = true;
        var current = false;
        final events = <bool>[];
        final poller = ValuePoller<bool>(
            read: () {
              if (explode) throw StateError('boom');
              return current;
            },
            interval: _interval);

        // The baseline read happens inside onListen. If it escaped, the
        // subscription would exist with no timer behind it and onListen would
        // never fire again.
        expect(() => poller.stream.listen(events.add), returnsNormally);

        explode = false;
        async.elapse(_interval * 2);
        current = true;
        async.elapse(_interval * 2);

        expect(events, [true]);
      });
    });
  });

  group('repeated listen/cancel cycles', () {
    test('each cycle polls at the same rate, with no timer left behind', () {
      fakeAsync((async) {
        var reads = 0;
        final poller = ValuePoller<bool>(
            read: () {
              reads++;
              return false;
            },
            interval: _interval);

        // Counting reads per elapsed interval, rather than just "more than
        // before", is what would catch a duplicate timer: two overlapping
        // periodic timers double the rate while every looser assertion passes.
        final perCycle = <int>[];
        for (var cycle = 0; cycle < 3; cycle++) {
          final before = reads;
          final subscription = poller.stream.listen((_) {});
          async.elapse(_interval * 10);
          perCycle.add(reads - before);

          subscription.cancel();
          final afterCancel = reads;
          async.elapse(_interval * 10);
          expect(reads, afterCancel,
              reason: 'cycle $cycle left a timer running');
        }

        expect(perCycle.toSet(), hasLength(1),
            reason: 'poll rate drifted across cycles: $perCycle');
      });
    });
  });

  group('dispose', () {
    test('stops polling and closes the stream', () {
      fakeAsync((async) {
        var reads = 0;
        var closed = false;
        final poller = ValuePoller<bool>(
            read: () {
              reads++;
              return false;
            },
            interval: _interval);

        poller.stream.listen((_) {}, onDone: () => closed = true);
        async.elapse(const Duration(seconds: 1));

        poller.dispose();
        final afterDispose = reads;
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        expect(reads, afterDispose);
        expect(closed, isTrue);
      });
    });

    test('is safe to call twice', () {
      final poller = ValuePoller<bool>(read: () => false, interval: _interval);

      poller.dispose();

      expect(poller.dispose, returnsNormally);
    });

    test('reading the stream after dispose throws instead of restarting', () {
      final poller = ValuePoller<bool>(read: () => false, interval: _interval);
      poller.dispose();

      // Left unguarded, the getter would build a fresh controller and the next
      // listen would start a fresh timer — a disposed poller quietly alive
      // again.
      expect(() => poller.stream, throwsStateError);
    });
  });
}
