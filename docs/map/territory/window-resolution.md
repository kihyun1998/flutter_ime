# Window resolution

## What it is
Finding the window handle IMM32 calls target on Windows. 2.x got it from the Flutter plugin registrar, which a pure Dart package does not have, so it is found from this process's own window tree.

## Governing decisions
**None.**

## Design model
From the source:
- **Precedence: the `FLUTTERVIEW` child of this process's `FLUTTER_RUNNER_WIN32_WINDOW`, then the runner window itself, then the foreground window, then none** (`WindowResolver._search`). The two class names were confirmed by enumerating a running example app (`kFlutterRunnerWindowClass` doc).
- **The top-level search filters by process id**, because another Flutter app has windows of the same class (`_Win32WindowCalls.findOwnTopLevel`).
- **Cached, and revalidated with `IsWindow` on every access**, since a recreated window leaves a stale handle (`WindowResolver.resolve`).
- **A foreground-window result is never cached** — it is a guess, and caching it would pin every later call to whatever was focused then (`resolve`). It is still returned and used by every operation except IME detach — see [IME disable](ime-disable.md).
- **One resolve per operation**, so the layout and the conversion state of one call come from one window (`WindowsIme._withImeContext` doc).
- **Lookups are injected callbacks**, so precedence and caching are tested without an OS (library doc).

## Code
- `lib/src/ffi/window_resolver.dart` — `WindowResolver`, `WindowResolver.resolve`, `_search`, `ResolvedWindow`, `WindowResolution`, `_Win32WindowCalls`, `kFlutterRunnerWindowClass`, `kFlutterViewWindowClass`
- `lib/src/ffi/windows_ime.dart` — `WindowsIme.resolveWindow`
- Tests: `test/window_resolver_test.dart`

## Reference behaviour
- `FindWindowExW`, `GetWindowThreadProcessId`, `GetForegroundWindow`, `IsWindow` — Win32 docs and `winuser.h` ([thegraph references](../../agents/thegraph.md)).
- The Flutter Windows runner's window classes — read from a running example app, not from Flutter's source (`kFlutterRunnerWindowClass` doc).

## Cross-cutting invariants
**None.**

## Blast radius
- [IME disable](ime-disable.md) — its safety rests on `source` honestly saying `foregroundWindow` for a guess.
- [English switch](english-switch.md), [English classification](english-classification.md), [Input-source token](input-source-token.md) — each acts on whatever this returns, a foreground guess included.
- [Example app](example-app.md) — the runner's class names come from the example's runner; a Flutter runner that renames them sends every call to the foreground fallback.

## Known holes / open
- **A plain Dart CLI on Windows has no runner window**, so every operation falls to the foreground window — another process's — except IME detach. The README says the package works from a plain Dart program; nothing records what Windows operations mean there.
- `WindowResolution` and `WindowsIme.resolveWindow` are documented as "exposed so the example app can show it", but the example app no longer uses either (removed with the FFI page in `8397162`); only `test/window_resolver_test.dart` reads `source`.
- The runner class names depend on Flutter's Windows runner template and are not pinned to any Flutter version.
