/// Pure interpretation of the Windows IMM32 conversion-mode bitfield.
///
/// Kept free of `dart:ffi` so it can be unit-tested on any platform, and so the
/// FFI layer stays a thin adapter with no branching logic of its own.
library;

/// `IME_CMODE_ALPHANUMERIC` — no conversion, i.e. plain Latin input.
const int imeCmodeAlphanumeric = 0x0000;

/// `IME_CMODE_NATIVE` — the IME converts to the native language (Hangul,
/// Hiragana, and so on). Its absence is what makes a mode "English".
const int imeCmodeNative = 0x0001;

/// `IME_SMODE_NONE` — no sentence-mode conversion.
const int imeSmodeNone = 0x0000;

/// Whether a conversion-mode bitfield represents English input.
///
/// Only the `NATIVE` bit decides. Every other bit — full-shape, katakana,
/// roman — describes how the native language is rendered and says nothing
/// about whether the IME is converting at all.
bool isEnglishConversionMode(int conversion) =>
    (conversion & imeCmodeNative) == 0;
