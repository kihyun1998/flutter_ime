# Input-source token

## What it is
`getCurrentInputSource` and `setInputSource`: saving the current keyboard as an opaque string and restoring it later. Consumers persist these strings, so the format is a compatibility contract with 2.x, not an internal detail.

## Governing decisions
**None.** Issues #13 (Windows) and #17 (macOS), both closed. `CHANGELOG.md` 3.0.0: "input-source tokens saved under 2.x still restore".

## Design model
From the source:
- **Windows token: `KLID` or `KLID:conversion:sentence`.** `parseInputSourceToken` is the only code that looks inside it and never throws: it accepts a bare `KLID`, `KLID:`, and a full triple; it rejects an empty token, an empty `KLID`, and any numeric segment that is not plain digits within `0xFFFFFFFF` (`input_source_token.dart`). Conversion state is all-or-nothing by construction (`InputSourceToken.layoutOnly` / `.withConversion`).
- **Byte-identical with 2.x.** A window with no IME context yields a layout-only token; a failed status read yields `:0:0`, not layout-only, because 2.x formatted the out-parameters regardless and the two tokens restore differently (`WindowsIme.getCurrentInputSource`). The ANSI `GetKeyboardLayoutNameA`/`LoadKeyboardLayoutA` are used to match what 2.x called (`win32.dart` comment above `Win32`).
- **Windows restore parses before touching the OS**, loads the layout with `KLF_ACTIVATE`, then restores conversion state best-effort (`WindowsIme.setInputSource`).
- **macOS token is the input-source identifier itself**; restore searches **every installed** source and enables a disabled one before selecting it (`MacosIme.setInputSource`, `includeUnenabled: true`). 2.x searched only enabled sources, so its enable call could never do anything (`setInputSource` doc).
- **A match that is enabled and then refused stays enabled** — not rolled back, by decision in `_selectInputSourceById`'s doc.
- **Failure is silent on both platforms**: a stale or malformed token is an expected outcome (`CHANGELOG.md` 3.0.0).

## Code
- `lib/src/input_source_token.dart` — `InputSourceToken`, `parseInputSourceToken`, `formatInputSourceToken`, `_parseUint32`
- `lib/src/ffi/windows_ime.dart` — `WindowsIme.getCurrentInputSource`, `WindowsIme.setInputSource`, `_readKeyboardLayoutName`
- `lib/src/ffi/macos_ime.dart` — `MacosIme.getCurrentInputSource`, `MacosIme.setInputSource`, `_readSourceId`, `_selectInputSourceById`
- Tests: `test/input_source_token_test.dart` (group "compatibility with tokens saved under 2.x"), `test/ffi_routing_test.dart`

## Reference behaviour
- 2.x's C++ parser: `std::stoul` bounds and its 2.1.4 crash fix are described in `parseInputSourceToken`'s and `_maxUint32`'s docs; the C++ source is gone (deleted in `8397162`).
- `GetKeyboardLayoutName`, `LoadKeyboardLayout` — Win32 docs and `winuser.h`; `kTISPropertyInputSourceID`, `TISCreateInputSourceList` — Apple docs and `TextInputSources.h` ([thegraph references](../../agents/thegraph.md)).

## Cross-cutting invariants
**None.**

## Blast radius
- [English switch](english-switch.md) — shares `_selectInputSourceById` on macOS; changing its search or enable behaviour changes both.
- [Window resolution](window-resolution.md) — the Windows token reads the resolved window's IME context.
- [Package manifest](package-manifest.md) — any change to the token's bytes breaks tokens consumers already saved, which is a major-version change.

## Known holes / open
- **macOS restore enables whatever installed source a string names**, and nothing enforces that the string came from `getCurrentInputSource`; the dartdoc asks callers to pass only their own tokens. An untrusted string can add a keyboard to the user's input menu.
- A token's input size is unbounded on both platforms; Windows hands the `KLID` to `LoadKeyboardLayoutA` without a length check after parsing.
