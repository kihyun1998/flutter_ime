# IME disable

## What it is
`disableIME` / `enableIME`, Windows only: detaching the IME context from the app window so composition cannot start, and re-attaching the default one.

## Governing decisions
**None.** Issue #14 (closed), "context detach only".

## Design model
From the source:
- **Detaching the context is the whole mechanism**: `ImmAssociateContextEx(hwnd, NULL, 0)` to detach, `IACE_DEFAULT` to restore (`WindowsIme.disableIme`, `enableIme`).
- **2.x's window-procedure hook is not reproduced.** Dart FFI cannot express a window procedure (it must return a value synchronously on the platform thread), and a spike found the hook contributed nothing the detach did not already do (`disableIme` doc, citing branch `spike/wndproc-block-necessity` at `c5c33fb` — neither is in this clone; also `CHANGELOG.md` 3.0.0 "Internal").
- **Only a window positively identified as this process's is acted on.** A foreground-window guess is refused, because a detach persists until something re-attaches and on another application's window it would disable the IME where the user is typing (`_isOwnWindow` doc). This is the only operation that checks.
- **Paste is not prevented**, and never was — paste does not travel the keyboard path (`disableIme` doc, README "Disable IME").
- **Neither call emits on the input-source stream**: while detached the conversion state is unreadable, which is null, not "not English" — see [Unreadable is null](../invariant/unreadable-is-null.md).

## Code
- `lib/src/ffi/windows_ime.dart` — `WindowsIme.disableIme`, `WindowsIme.enableIme`, `_isOwnWindow`
- `lib/src/ffi/win32.dart` — `immAssociateContextEx`, `iaceDefault`
- Tests: `test/ffi_routing_test.dart` group "IME association refuses a foreground-window guess"

## Reference behaviour
- `ImmAssociateContextEx`, `IACE_DEFAULT` — Win32 IMM docs and `imm.h` ([thegraph references](../../agents/thegraph.md)).
- The spike that dropped the hook: branch `spike/wndproc-block-necessity`, commit `c5c33fb`, as cited in `disableIme`'s doc (not reachable from this clone).

## Cross-cutting invariants
- [Unreadable is null, not false](../invariant/unreadable-is-null.md) — a detached context is the main unreadable case.

## Blast radius
- [Window resolution](window-resolution.md) — the own-window check reads `ResolvedWindow.source`; a resolver that labels a guess as found would let a detach hit another application.
- [Change streams](change-streams.md) — a detach makes the Windows reader return null for as long as it lasts; the stream must hold its baseline through it.
- [English classification](english-classification.md) — `isEnglishKeyboard` answers false while detached, by design (the collapse to false).

## Known holes / open
- An app that calls `disableIME` and never `enableIME` leaves the IME detached for the rest of its life; documented, not guarded.
- The spike evidence lives on a branch this clone does not have.
