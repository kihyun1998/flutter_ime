import 'package:flutter_ime/src/ime_conversion_mode.dart';
import 'package:test/test.dart';

void main() {
  group('isEnglishConversionMode', () {
    test('alphanumeric mode is English', () {
      expect(isEnglishConversionMode(imeCmodeAlphanumeric), isTrue);
    });

    test('native mode is not English', () {
      expect(isEnglishConversionMode(imeCmodeNative), isFalse);
    });

    // The 2.1.0 changelog records isEnglishKeyboard() always returning false
    // because this flag check was wrong. These cases pin the bit test down: the
    // NATIVE bit alone decides, and every other bit is irrelevant.
    test('native mode combined with other flags is still not English', () {
      // Korean IME in Hangul mode reports NATIVE|FULLSHAPE.
      expect(isEnglishConversionMode(imeCmodeNative | 0x0008), isFalse);
      // Japanese IME in Katakana mode reports NATIVE|KATAKANA|FULLSHAPE.
      expect(
          isEnglishConversionMode(imeCmodeNative | 0x0002 | 0x0008), isFalse);
    });

    test('non-native flags without the native bit are still English', () {
      // Full-shape alphanumeric: not native, so still English input.
      expect(isEnglishConversionMode(0x0008), isTrue);
      // Roman flag set without native.
      expect(isEnglishConversionMode(0x0010), isTrue);
    });

    test('only the lowest bit is consulted', () {
      for (var extra = 0; extra < 0x20; extra++) {
        final withoutNative = extra & ~imeCmodeNative;
        expect(
          isEnglishConversionMode(withoutNative),
          isTrue,
          reason: 'conversion 0x${withoutNative.toRadixString(16)} has no '
              'NATIVE bit and must read as English',
        );
        expect(
          isEnglishConversionMode(withoutNative | imeCmodeNative),
          isFalse,
          reason:
              'conversion 0x${(withoutNative | imeCmodeNative).toRadixString(16)} '
              'has the NATIVE bit and must read as non-English',
        );
      }
    });
  });
}
