// The regression net for the classification fix in #16.
//
// 2.x asked whether the input-source ID contained "com.apple.keylayout.ABC" or
// "com.apple.keylayout.US", so every other English layout — Dvorak, Colemak,
// British, Australian, Canadian — was reported as *not* English. The README's
// "force English" recipe reacts to that answer by switching the keyboard, so
// the package actively fought those users.
//
// The language lists below are not invented: they were read off a real macOS
// machine by enumerating every installed input source and printing its
// kTISPropertyInputSourceLanguages. Several English layouts share the same
// list; they are still spelled out one by one, because the point of this file
// is to name the layouts that used to be wrong.
library;

import 'package:flutter_ime/src/english_input_source.dart';
import 'package:test/test.dart';

void main() {
  group('English layouts classify as English', () {
    const englishLayouts = <String, List<String>>{
      'ABC': ['en'],
      'U.S.': ['en'],
      'Dvorak': ['en'],
      'Colemak': ['en'],
      'British': ['en'],
      'Australian': ['en'],
      'Canadian': ['en'],
      'U.S. Extended': ['en'],
      'U.S. International — PC': ['en'],
    };

    englishLayouts.forEach((layout, languages) {
      test(layout, () => expect(isEnglishInputSource(languages), isTrue));
    });
  });

  group('non-English layouts and IMEs classify as non-English', () {
    const otherSources = <String, List<String>>{
      'Korean 2-Set': ['ko'],
      'Japanese Romaji': ['ja'],
      'Pinyin Simplified': ['zh-Hans'],
      'Canadian French': ['fr'],
      'German': ['de'],
      // Two layouts whose IDs begin with the exact string 2.x substring-matched
      // on, com.apple.keylayout.ABC, but which type French and German. The old
      // rule called both of them English.
      'ABC — AZERTY': ['fr'],
      'ABC — QWERTZ': ['de'],
    };

    otherSources.forEach((source, languages) {
      test(source, () => expect(isEnglishInputSource(languages), isFalse));
    });
  });

  group('language tags', () {
    test('a regional English tag is still English', () {
      expect(isEnglishInputSource(['en-GB']), isTrue);
      expect(isEnglishInputSource(['en-AU']), isTrue);
    });

    test('case does not matter', () {
      expect(isEnglishInputSource(['EN']), isTrue);
      expect(isEnglishInputSource(['En-gb']), isTrue);
    });

    test('a language that merely starts with "en" is not English', () {
      // Without splitting on the subtag separator, a prefix match would claim
      // these.
      expect(isEnglishInputSource(['enm']), isFalse);
      expect(isEnglishInputSource(['eng']), isFalse);
    });
  });

  group('only the primary language decides', () {
    test('an English secondary language does not make a source English', () {
      // A Korean IME that also lists English is a Korean IME. Reporting it as
      // English would leave a password field accepting Hangul.
      expect(isEnglishInputSource(['ko', 'en']), isFalse);
    });

    test('a non-English secondary language does not disqualify a source', () {
      expect(isEnglishInputSource(['en', 'ko']), isTrue);
    });
  });

  group('degenerate input', () {
    test('no languages at all is not English', () {
      // Some input sources expose no language list. Claiming English for them
      // would switch a user away from a keyboard we know nothing about.
      expect(isEnglishInputSource([]), isFalse);
    });

    test('an empty tag is not English', () {
      // The Pinyin keyboard layouts really do report a single empty tag.
      expect(isEnglishInputSource(['']), isFalse);
      expect(isEnglishInputSource(['  ']), isFalse);
    });
  });
}
