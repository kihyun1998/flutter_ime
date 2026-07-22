/// Pure classification of a macOS input source as English or not.
///
/// Kept free of `dart:ffi` so it can be unit-tested on any platform, and so the
/// FFI layer stays a thin adapter with no branching logic of its own — the same
/// arrangement [isEnglishConversionMode] has on the Windows side.
library;

/// The BCP 47 primary subtag for English.
const String _englishSubtag = 'en';

/// Whether an input source's language list denotes an English keyboard.
///
/// [languages] is what macOS reports through
/// `kTISPropertyInputSourceLanguages`, most-significant first. Only the first
/// entry decides: a Korean IME that also lists English is a Korean IME, and
/// reporting it as English would leave a password field accepting Hangul.
///
/// **This replaces the 2.x rule**, which asked whether the input-source ID
/// contained `com.apple.keylayout.ABC` or `com.apple.keylayout.US`. Every other
/// English layout — Dvorak, Colemak, British, Australian, Canadian — answered
/// "not English", and the "force English" recipe in the README reacts to that
/// answer by switching the keyboard, so the package actively fought those
/// users. Asking the input source what language it types is both correct and
/// open-ended: a layout nobody here has heard of classifies correctly too.
///
/// A source with no languages is not English. Some sources expose no list at
/// all, and claiming English for one would switch a user away from a keyboard
/// we know nothing about.
///
/// Note that this makes `isEnglishKeyboard()` mean something different on each
/// platform: on Windows, "the IME is not converting to the native language"; on
/// macOS, "the selected layout types English". That divergence is inherent —
/// macOS switches whole layouts where Windows toggles a conversion mode within
/// one — and predates this change.
bool isEnglishInputSource(List<String> languages) {
  if (languages.isEmpty) return false;
  return _isEnglishLanguageTag(languages.first);
}

/// Whether a BCP 47 language tag names English.
///
/// Split on the subtag separator rather than prefix-matched, so `en-GB` is
/// English while `enm` (Middle English) is not.
///
/// Only the two-letter ISO 639-1 code counts. macOS reports that form, and
/// accepting `eng` as well would mean guessing at a convention this API does
/// not use.
bool _isEnglishLanguageTag(String tag) {
  final primary = tag.trim().toLowerCase().split('-').first;
  return primary == _englishSubtag;
}
