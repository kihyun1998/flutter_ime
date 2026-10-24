# Caps Lock

## What it is
`isCapsLockOn` and `onCapsLockChanged`: reading the Caps Lock toggle and streaming its changes on Windows and macOS. Polled on both platforms.

## Governing decisions
**None.** Issues #15 (Windows) and #18 (macOS), both closed.

## Design model
From the source:
- **Windows reads the toggle bit of `GetKeyState(VK_CAPITAL)`** — the low bit, not the held-down high bit — and needs no window (`WindowsIme.isCapsLockOn`, `keyStateToggledMask`).
- **macOS reads hardware modifier state**, `CGEventSourceFlagsState(kCGEventSourceStateHIDSystemState) & kCGEventFlagMaskAlphaShift`, which needs no Accessibility permission; 2.x used a global event monitor that delivered nothing without one (`CoreGraphics.eventSourceFlagsState` doc).
- **Polled on macOS too, deliberately**: the push alternative needs that permission (`FfiFlutterIme.onCapsLockChanged` doc).
- **A macOS language switch really toggles the lock**, for about 12 ms on a quick tap; a 50 ms poll lands inside it roughly one time in four, so the stream sometimes reports a toggle the user did not mean (`MacosIme.isCapsLockOn` doc; `CHANGELOG.md` 3.0.0).
- **Filtering it out was tried and reverted** (`c430f8f`, reverted by `72fe7f1`, 2026-07-22): `CGEventSourceKeyState` for Caps Lock reports the lock, not whether the key is held — measured with the lock on and nobody touching the keyboard, both read true — so only duration separates the cases, and a timing threshold was judged worse than reporting the truth (`isCapsLockOn` doc; commit `dd20e42`).
- **The readers never return null**, so the Caps Lock stream has no unreadable state.

## Code
- `lib/src/ffi/windows_ime.dart` — `WindowsIme.isCapsLockOn`
- `lib/src/ffi/win32.dart` — `getKeyState`, `vkCapital`, `keyStateToggledMask`
- `lib/src/ffi/macos_ime.dart` — `MacosIme.isCapsLockOn`
- `lib/src/ffi/core_graphics.dart` — `CoreGraphics.eventSourceFlagsState`, `cgEventSourceStateHidSystemState`, `cgEventFlagMaskAlphaShift`
- `lib/src/ffi/ffi_flutter_ime.dart` — `FfiFlutterIme.isCapsLockOn`, `onCapsLockChanged`

## Reference behaviour
- `GetKeyState` — Win32 docs and `winuser.h`; `CGEventSourceFlagsState` — Apple docs and `CGEventSource.h` ([thegraph references](../../agents/thegraph.md)).
- The 12 ms and one-in-four figures and the `CGEventSourceKeyState` measurement are recorded only in `MacosIme.isCapsLockOn`'s doc and commit `dd20e42`; no measurement script exists.

## Cross-cutting invariants
**None.**

## Blast radius
- [Change streams](change-streams.md) — the stream's de-duplication is what turns a 12 ms toggle into exactly two emissions.
- [Backend dispatch](backend-dispatch.md) — the poll interval there sets how often the language-switch flicker is caught.

## Known holes / open
- The language-switch flicker is reported, not filtered; any consumer driving a warning from the stream sees it.
