# Example app

## What it is
`example/`, a Flutter app that depends on the package by path. It is the manual test harness — one page per feature — the only place the Windows runner's window classes exist, and the home of the compiled copies of the README's samples.

## Governing decisions
**None.**

## Design model
From the source:
- **Pages per feature**: `CapsLockPage`, `KeyboardStatusPage`, `ImeDisablePage`, `InputSourceChangePage`, `ForceEnglishPage` (`example/lib/main.dart`).
- **`readme_examples.dart` holds the README's code samples verbatim**, with only a wrapping `StatefulWidget` and numeric class suffixes added, so `flutter analyze` in CI type-checks the documentation — see [README samples](../invariant/readme-samples-match.md).
- **It is a Flutter app on purpose**, with its own SDK constraint (`^3.6.1`), `flutter_lints`, and a lockfile; nothing in it ships.
- **Its Windows runner creates `FLUTTER_RUNNER_WIN32_WINDOW` with a `FLUTTERVIEW` child**, which is what [window resolution](window-resolution.md) looks for.

## Code
- `example/lib/main.dart` — `MyApp`, `HomePage`, `CapsLockPage`, `KeyboardStatusPage`, `ImeDisablePage`, `InputSourceChangePage`, `ForceEnglishPage`
- `example/lib/readme_examples.dart` — `readmeUsage` and the sample `State` classes
- `example/integration_test/plugin_integration_test.dart`
- `example/test/widget_test.dart`
- `example/windows/runner/`, `example/macos/Runner/` — generated Flutter runners

## Reference behaviour
**None.**

## Cross-cutting invariants
- [README samples match the compiled copies](../invariant/readme-samples-match.md)

## Blast radius
- [Window resolution](window-resolution.md) — regenerating the runner with a template that renames its window classes makes every Windows call fall to the foreground guess.
- [CI](ci.md) — three jobs build this app.
- [Public API](public-api.md) — every page calls the public functions; a signature change breaks the build.

## Known holes / open
- **`plugin_integration_test.dart` is stale** (maintainer, 2026-10-24): it expects `setInputSource('deadbeef:not-a-number:0')` to throw `PlatformException`, which 3.0.0 made silent, and it expects `setEnglishKeyboard` to make `isEnglishKeyboard` true, which macOS does not guarantee when ABC is not enabled. CI does not run it. Tracked: #29
- `MacosIme.describeCurrentInputSource` and `WindowResolution` are documented as feeding this app, but it stopped using them in `8397162`; `describeCurrentInputSource` is now reachable only from tests. Tracked: #30
