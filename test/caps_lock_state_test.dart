// The rule that keeps a Korean user's language switch from looking like a
// Caps Lock toggle.
//
// On macOS the Caps Lock key doubles as the input-source switch: a tap changes
// language, a long press latches Caps Lock. Both press the same key, and while
// it is held the alpha-shift flag is set either way. Measured on a real
// machine, a language-switch tap looks like this:
//
//     9655ms  alphaShift=true   keyDown=true
//     9667ms  alphaShift=false  keyDown=false
//
// Twelve milliseconds of "Caps Lock is on" that never happened. A 50ms poller
// catches it often enough to matter, and the result was a password field
// flashing a Caps Lock warning every time the user switched to Korean.
//
// A real latch was measured too, and it is what tells the two apart: the flag
// goes up during the press and *stays* up after the key is released.
library;

import 'package:flutter_ime/src/caps_lock_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('while the key is up, the flag is the answer', () {
    test('flag set means Caps Lock is on', () {
      expect(capsLockState(alphaShiftSet: true, keyIsDown: false), isTrue);
    });

    test('flag clear means Caps Lock is off', () {
      expect(capsLockState(alphaShiftSet: false, keyIsDown: false), isFalse);
    });
  });

  group('while the key is down, there is no answer yet', () {
    test('a held key with the flag set is not yet a Caps Lock on', () {
      // The middle of a press. It becomes an "on" only if the flag survives
      // the release, which is what distinguishes a latch from a language
      // switch — and that cannot be known until the key comes up.
      expect(capsLockState(alphaShiftSet: true, keyIsDown: true), isNull);
    });

    test('a held key with the flag clear is also no answer', () {
      expect(capsLockState(alphaShiftSet: false, keyIsDown: true), isNull);
    });
  });

  group('the sequences that were measured', () {
    /// Feeds a recorded sequence through the rule and returns what a change
    /// stream would see, given that null holds the previous value.
    List<bool> settled(List<(bool, bool)> samples) {
      final out = <bool>[];
      for (final (flag, down) in samples) {
        final state = capsLockState(alphaShiftSet: flag, keyIsDown: down);
        if (state != null && (out.isEmpty || out.last != state)) out.add(state);
      }
      return out;
    }

    test('a language-switch tap settles to nothing', () {
      // flag and keyDown rise and fall together, exactly as measured.
      expect(
        settled([
          (false, false),
          (true, true), // key down
          (false, false), // released, flag gone with it
        ]),
        [false],
        reason: 'it never left the state it started in',
      );
    });

    test('a real latch settles to on', () {
      // The flag comes up during the press and survives the release.
      expect(
        settled([
          (false, false),
          (true, true), // held
          (true, true), // still held
          (true, false), // released, flag stayed
        ]),
        [false, true],
      );
    });

    test('unlatching settles to off', () {
      expect(
        settled([
          (true, false),
          (true, true), // held again
          (false, false), // released, flag gone
        ]),
        [true, false],
      );
    });
  });
}
