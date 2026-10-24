# CI

## What it is
The GitHub Actions workflow that checks every push to `main` and every pull request: the package's own analysis and tests without Flutter, a plain-Dart consumer, and builds of the example app for web, Windows and macOS.

## Governing decisions
**None.** The no-Flutter Dart job came from commit `b2ba051` (2026-07-22, "ci: let the Dart job run without a Flutter SDK").

## Design model
From `.github/workflows/ci.yml`:
- **`dart` job, no Flutter SDK**: `dart pub get --no-example` (the example cannot resolve without Flutter), `dart format --set-exit-if-changed .` over everything including the example, `dart analyze lib test` scoped to the package, `dart test`. Running the suite through Flutter would hide a Flutter dependency creeping back.
- **`plain-dart-consumer`**: writes a consumer with a path dependency and runs every function on Linux, where each takes the gating path. Reaching the end without throwing is the assertion. It does not touch the streams.
- **`example-web`**: `flutter analyze` on the example (the only place it is analysed) and `flutter build web`, the only check that a stray `dart:ffi` import breaks web.
- **`example-windows`, `example-macos`**: debug builds only — smoke tests that a consumer app still builds; nothing is run.
- **Flutter is pinned** (`FLUTTER_VERSION: "3.41.9"`); the Dart SDK is not.

## Code
- `.github/workflows/ci.yml` — jobs `dart`, `plain-dart-consumer`, `example-web`, `example-windows`, `example-macos`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [No Flutter dependency](../invariant/no-flutter-dependency.md) — the `dart` and `plain-dart-consumer` jobs are two of its sites.
- [README samples match the compiled copies](../invariant/readme-samples-match.md) — `flutter analyze` in `example-web` is what type-checks the copies.

## Blast radius
- [Package manifest](package-manifest.md) — the consumer job's `sdk:` constraint mirrors the floor there.
- [Web build](web-build.md) — the web build is that territory's only automated check.
- [Example app](example-app.md) — three jobs build it; a change that breaks its Flutter resolution breaks them.

## Known holes / open
- **Nothing runs on a real Windows or macOS session.** Every OS-touching path is covered only by fakes ([native bindings](native-bindings.md)); `example/integration_test/` is not run.
- The plain-Dart consumer never subscribes to a stream, so "a CLI that listens and cancels can exit" is verified only by hand (commit `8397162` message).
