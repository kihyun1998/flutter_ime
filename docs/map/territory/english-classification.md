# English classification

## What it is
Answering "is the keyboard English right now?" — `isEnglishKeyboard` and the readers the input-source stream polls. The question is different on each platform, and each platform's answer is computed by a pure function so it can be tested without an OS.

## Governing decisions
**None.** The macOS rule replaced 2.x's identifier match in commit `35f1920` (2026-07-22) for issue #16; `CHANGELOG.md` 3.0.0 records it as a breaking change.

## Design model
From the source:
- **Windows: only the `IME_CMODE_NATIVE` bit decides.** English means the IME is not converting to the native language; full-shape, katakana and roman bits say nothing about whether it converts (`isEnglishConversionMode`). A Korean keyboard in alphanumeric mode is English.
- **macOS: the first entry of `kTISPropertyInputSourceLanguages` decides**, and it is English when its BCP 47 primary subtag is exactly `en` — so `en-GB` is English and `enm` is not; `eng` is not accepted because macOS reports the two-letter form (`isEnglishInputSource`, `_isEnglishLanguageTag`). Dvorak, Colemak, British, Australian and Canadian therefore answer true; 2.x matched `com.apple.keylayout.ABC`/`US` only.
- **A Korean IME that also lists English is Korean**, because only the first language counts; reporting it English would leave a password field accepting Hangul (`isEnglishInputSource` doc).
- **No languages is not English**, so the package never switches a user away from a keyboard it knows nothing about.
- **The platform adapters only read and hand over.** `WindowsIme.readEnglishStateOrNull` reads the conversion status through the window's IME context; `MacosIme.readEnglishStateOrNull` copies the current input source and reads its languages, releasing the copy (`_withCurrentInputSource`, `_readLanguages`, which checks the property is a `CFArray` before counting it).

## Code
- `lib/src/ime_conversion_mode.dart` — `isEnglishConversionMode`, `imeCmodeNative`, `imeCmodeAlphanumeric`, `imeSmodeNone`
- `lib/src/english_input_source.dart` — `isEnglishInputSource`, `_isEnglishLanguageTag`
- `lib/src/ffi/windows_ime.dart` — `WindowsIme.isEnglishKeyboard`, `WindowsIme.readEnglishStateOrNull`, `_readConversionStatus`
- `lib/src/ffi/macos_ime.dart` — `MacosIme.isEnglishKeyboard`, `MacosIme.readEnglishStateOrNull`, `_readLanguages`, `_readString`
- Tests: `test/ime_conversion_mode_test.dart`, `test/english_input_source_test.dart`

## Reference behaviour
- Windows `ImmGetConversionStatus` and the `IME_CMODE_*` flags — Win32 IMM docs and `imm.h` ([thegraph references](../../agents/thegraph.md)).
- macOS `TISGetInputSourceProperty` / `kTISPropertyInputSourceLanguages` — Apple docs and `TextInputSources.h` (same table).

## Cross-cutting invariants
- [Unreadable is null, not false](../invariant/unreadable-is-null.md) — both `readEnglishStateOrNull` readers.

## Blast radius
- [English switch](english-switch.md) — the "force English" recipe switches whenever this answers false, so a classification that wrongly says "not English" makes the switch fight the user (`isEnglishInputSource` doc on 2.x).
- [Change streams](change-streams.md) — the input-source stream emits this value, so a reader that changes its answer for the same keyboard emits a change that did not happen.
- [Window resolution](window-resolution.md) — the Windows answer is read from the resolved window's context; a wrong window is a wrong answer.
- [Public API](public-api.md) — the per-platform meaning is documented in `isEnglishKeyboard`'s dartdoc and the README.

## Known holes / open
**None.**
