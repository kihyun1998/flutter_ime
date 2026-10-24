# Web build

## What it is
Keeping a consumer's web build compiling. `dart:ffi` does not exist on web, so the platform interface selects a stub implementation there through a conditional import; the stub is constructed but never called.

## Governing decisions
**None.** The promise is stated in `pubspec.yaml`'s `platforms:` comment ("adding this package does not break your web build").

## Design model
From the source:
- **`dart:ffi` stays out of the web library graph.** `flutter_ime_platform_interface.dart` imports `ffi_flutter_ime_stub.dart` unless `dart.library.ffi` exists; `dart:io` compiles on web, `dart:ffi` does not (stub library doc, "verified against this package").
- **The stub throws, synchronously.** Every member throws `UnsupportedError` and none is `async`, so a regression in the gating surfaces at the call line rather than as an unhandled async error from a fire-and-forget focus listener (stub library doc). It is the one place the package raises.
- **Anything crossing into code that must compile on web carries no FFI type** — `MacosIme.describeCurrentInputSource` returns a `String` for that reason (its doc).

## Code
- `lib/flutter_ime_platform_interface.dart` — the conditional import
- `lib/src/ffi/ffi_flutter_ime_stub.dart` — `FfiFlutterIme` (stub), `_unsupported`
- Tests: `test/ffi_routing_test.dart` group "the web stub refuses rather than pretending"
- CI: `.github/workflows/ci.yml` job `example-web` (`flutter build web`)

## Reference behaviour
**None.**

## Cross-cutting invariants
**None.**

## Blast radius
- [Public API](public-api.md) — the stub is safe only while every public function gates before reaching the instance.
- [CI](ci.md) — the web example build is the only check that a stray unconditional `dart:ffi` import breaks web.
- [Package manifest](package-manifest.md) — `platforms: web:` is the published promise this territory keeps.

## Known holes / open
**None.**
