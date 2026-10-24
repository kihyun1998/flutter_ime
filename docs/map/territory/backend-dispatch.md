# Backend dispatch

## What it is
`FfiFlutterIme`, the one implementation of `FlutterImePlatform` on platforms with `dart:ffi`. It picks a Windows or a macOS backend from `Platform` at construction, routes every operation to whichever is present, gives the documented default when neither is, and owns the three change streams it builds over the backends.

## Governing decisions
**None.** The shape is described in commit `8397162` (2026-07-22, "feat!: delete the native plugin and make Dart FFI the default"), which made this the only implementation.

## Design model
From the source:
- **One dispatch shape everywhere: try Windows, then macOS, then the default.** Written as explicit `if` branches, never a `??` chain over results, because `getCurrentInputSource` answers null for a keyboard it could not read and a chain would carry on into the other backend (`ffi_flutter_ime.dart`, the comment above `_pollInterval`).
- **It holds the documented default on its own**, not relying on the gating in `flutter_ime.dart` (`FfiFlutterIme` class doc).
- **Backend booleans are discarded.** `WindowsIme`/`MacosIme` return `false` on failure; the `Future<void>` operations drop it, which is how failure becomes silent.
- **Stream wiring:** `onInputSourceChanged` is a `ValuePoller` over `WindowsIme.readEnglishStateOrNull` on Windows and a `ChangeStream` over the macOS notification observer on macOS; `onCapsLockChanged` is a `ValuePoller` on both. Each is built lazily once and cached in a field.
- **`_pollInterval` is 50 ms and deliberately not configurable**: chosen so reverting an unwanted switch in the "force English" recipe lets no character through (`_pollInterval` doc). No measurement is recorded for it.
- **Tests build it with `FfiFlutterIme.withBackends`**, so no test reaches the host OS (`withBackends` doc; added in commit `35f1920`).

## Code
- `lib/src/ffi/ffi_flutter_ime.dart` — `FfiFlutterIme`, `FfiFlutterIme.withBackends`, `_pollInterval`, `onInputSourceChanged`, `onCapsLockChanged`
- Tests: `test/ffi_routing_test.dart`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Unreadable is null, not false](../invariant/unreadable-is-null.md) — the input-source stream is wired to the `…OrNull` readers, never to `isEnglishKeyboard`.

## Blast radius
- [Change streams](change-streams.md) — the emit-only-on-change and stop-on-last-cancel rules the streams here promise live there.
- [macOS input-source observer](macos-input-source-observer.md) — the macOS stream's start/stop callbacks are that observer's, and its one-per-process rule surfaces through this stream as a `StateError`.
- [Caps Lock](caps-lock.md) — both platforms' Caps Lock stream is this file's poller at this interval.
- [Public API](public-api.md) — the defaults here must match the gating's.

## Known holes / open
- `_pollInterval`'s 50 ms has a stated reason and no recorded measurement.
