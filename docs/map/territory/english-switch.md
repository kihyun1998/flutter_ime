# English switch

## What it is
`setEnglishKeyboard`: putting the user on an English keyboard. Windows sets alphanumeric conversion mode on the app window's IME context; macOS selects the ABC layout if the user has it enabled.

## Governing decisions
**None.** Issues #12 (Windows) and #16 (macOS), both closed, specified the ports.

## Design model
From the source:
- **Windows** calls `ImmSetConversionStatus(context, IME_CMODE_ALPHANUMERIC, IME_SMODE_NONE)` on the resolved window's context, and does nothing when there is no window or no context (`WindowsIme.setEnglishKeyboard`).
- **macOS targets `com.apple.keylayout.ABC` only, and only among enabled sources** (`_selectInputSourceById(..., includeUnenabled: false)`). Selecting ABC for someone who never enabled it would add a keyboard to their input menu; restoring a token is different and widens the search — see [input-source token](input-source-token.md) (`MacosIme.setEnglishKeyboard` doc).
- **ABC rather than "whichever English layout is installed"**, matching 2.x; a Dvorak user is not pushed here because classification already calls Dvorak English (`_englishInputSourceId` doc).
- **Enable runs before select on both paths**; enabling an already-enabled source is a no-op, which is why the narrow caller shares the path (`_selectInputSourceById`).

## Code
- `lib/src/ffi/windows_ime.dart` — `WindowsIme.setEnglishKeyboard`, `_withImeContext`
- `lib/src/ffi/macos_ime.dart` — `MacosIme.setEnglishKeyboard`, `_englishInputSourceId`, `_selectInputSourceById`, `_newString`, `_newFilter`
- Tests: `test/ffi_routing_test.dart`

## Reference behaviour
- `ImmSetConversionStatus` — Win32 IMM docs and `imm.h`; `TISCreateInputSourceList`, `TISEnableInputSource`, `TISSelectInputSource` — Apple docs and `TextInputSources.h` ([thegraph references](../../agents/thegraph.md)).

## Cross-cutting invariants
**None.**

## Blast radius
- [Input-source token](input-source-token.md) — both go through `_selectInputSourceById` on macOS; the `includeUnenabled` flag is the only difference, and widening it here would add keyboards the user never chose.
- [English classification](english-classification.md) — the README's "force English" recipe calls this whenever classification says "not English".
- [Window resolution](window-resolution.md) — the Windows switch acts on the resolved window, including a foreground-window guess.

## Known holes / open
- On Windows the switch is applied to a foreground-window guess too (only disable/enable refuse one — see [IME disable](ime-disable.md)). The source calls conversion state "transient and self-correcting" (`_isOwnWindow` doc); nothing records whether switching another application's IME mode that way was considered acceptable or merely tolerated.
- A macOS user with no ABC enabled gets no switch at all, silently.
