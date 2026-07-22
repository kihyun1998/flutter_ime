// Ported from the GoogleTest suite that covered the C++ implementation
// (windows/test/input_source_token_test.cpp). Every case there is carried over
// rather than reinvented, including the two that guard the 2.1.4 crash fix.
//
// One case does not port for free. The C++ parser got its 32-bit range check
// from `std::stoul` throwing `out_of_range`, because `unsigned long` is 32 bits
// on MSVC. Dart's `int` is 64 bits, so an oversized segment parses happily and
// the bound has to be enforced explicitly.
library;

import 'package:flutter_ime/src/input_source_token.dart';
import 'package:test/test.dart';

void main() {
  group('parseInputSourceToken', () {
    test('a bare layout id carries no conversion state', () {
      final token = parseInputSourceToken('00000412');

      expect(token, isNotNull);
      expect(token!.klid, '00000412');
      expect(token.hasConversion, isFalse);
    });

    test('a well-formed token decodes every part', () {
      final token = parseInputSourceToken('00000409:2:1');

      expect(token, isNotNull);
      expect(token!.klid, '00000409');
      expect(token.hasConversion, isTrue);
      expect(token.conversion, 2);
      expect(token.sentence, 1);
    });

    test('a trailing colon with no second segment is layout-only', () {
      final token = parseInputSourceToken('00000412:');

      expect(token, isNotNull);
      expect(token!.klid, '00000412');
      expect(token.hasConversion, isFalse);
    });

    test('a single conversion segment with no sentence is layout-only', () {
      // The C++ parser looked for a second colon and gave up on the conversion
      // state without it, rather than restoring half of it.
      final token = parseInputSourceToken('00000412:1');

      expect(token, isNotNull);
      expect(token!.klid, '00000412');
      expect(token.hasConversion, isFalse);
    });

    test('an empty token is rejected', () {
      expect(parseInputSourceToken(''), isNull);
    });

    group('rejects malformed segments without throwing', () {
      // These are the 2.1.4 regression cases. In C++ they would reach
      // std::stoul and throw across the method-channel boundary, crashing the
      // host app. Reaching the expectation at all is half the assertion.
      test('non-numeric conversion', () {
        expect(parseInputSourceToken('00000412:abc:0'), isNull);
      });

      test('non-numeric sentence', () {
        expect(parseInputSourceToken('00000412:1:xyz'), isNull);
      });

      test('trailing garbage after a number', () {
        // "1x" would make std::stoul stop early and silently succeed.
        expect(parseInputSourceToken('00000412:1x:0'), isNull);
      });

      test('empty conversion segment', () {
        expect(parseInputSourceToken('00000412::0'), isNull);
      });

      test('empty sentence segment', () {
        expect(parseInputSourceToken('00000412:1:'), isNull);
      });

      test('a number beyond the 32-bit range', () {
        // Free in C++ via a thrown out_of_range; must be explicit in Dart.
        expect(parseInputSourceToken('00000412:99999999999999:0'), isNull);
      });

      test('a number exactly one past the 32-bit maximum', () {
        expect(parseInputSourceToken('00000412:4294967296:0'), isNull);
        // ...but the maximum itself is valid.
        expect(parseInputSourceToken('00000412:4294967295:0')?.conversion,
            4294967295);
      });

      test('a negative number', () {
        // Conversion modes are unsigned. C++ let stoul wrap these silently;
        // rejecting is stricter and no token 2.x produces is ever negative.
        expect(parseInputSourceToken('00000412:-1:0'), isNull);
      });

      test('whitespace around a number', () {
        // std::stoul skips leading whitespace; Dart does not, and no token
        // 2.x produces contains any.
        expect(parseInputSourceToken('00000412: 1:0'), isNull);
      });

      test('an empty layout id', () {
        // C++ accepted this and let LoadKeyboardLayout fail later. Rejecting
        // here is observably identical — setInputSource returns false either
        // way — and fails at the point the problem actually exists.
        expect(parseInputSourceToken(':1:0'), isNull);
      });
    });
  });

  group('formatInputSourceToken', () {
    test('joins the parts with colons', () {
      expect(formatInputSourceToken('00000412', 1, 0), '00000412:1:0');
    });

    test('round-trips through the parser', () {
      final token =
          parseInputSourceToken(formatInputSourceToken('00000409', 2, 1));

      expect(token, isNotNull);
      expect(token!.klid, '00000409');
      expect(token.hasConversion, isTrue);
      expect(token.conversion, 2);
      expect(token.sentence, 1);
    });
  });

  group('compatibility with tokens saved under 2.x', () {
    // The format is a hard compatibility requirement: consumers persist these,
    // and a token written by 2.x must still restore after upgrading. These are
    // literal strings the 2.x formatter produces, not values recomputed here.
    const savedByTwoX = <String, List<int>>{
      '00000412:1:0': [1, 0], // Korean, Hangul mode
      '00000412:0:0': [0, 0], // Korean, alphanumeric mode
      '00000409:0:0': [0, 0], // US English
      '00000411:9:0': [9, 0], // Japanese, native + full-shape
    };

    for (final entry in savedByTwoX.entries) {
      test('accepts ${entry.key}', () {
        final token = parseInputSourceToken(entry.key);

        expect(token, isNotNull, reason: '${entry.key} must still parse');
        expect(token!.conversion, entry.value[0]);
        expect(token.sentence, entry.value[1]);
        expect(
            formatInputSourceToken(
                token.klid, token.conversion!, token.sentence!),
            entry.key,
            reason: 're-formatting must reproduce the token byte for byte');
      });
    }
  });
}
