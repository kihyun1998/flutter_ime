# Public API

## What it is
The nine top-level functions consumers call — `setEnglishKeyboard`, `isEnglishKeyboard`, `getCurrentInputSource`, `setInputSource`, `disableIME`, `enableIME`, `onInputSourceChanged`, `isCapsLockOn`, `onCapsLockChanged` — and the platform-gating policy each one consults before it reaches the platform interface. This is the contract the README and CHANGELOG describe, and the dartdoc on each function is where its per-platform meaning is written.

## Governing decisions
**None.** No decision records exist in this repo. The 3.0.0 behaviour changes are stated in `CHANGELOG.md` under 3.0.0 and were specified in the closed issue #11 ("Spec: migrate to a pure Dart FFI package (3.0.0)"); neither is a record.

## Design model
From the source and the CHANGELOG:
- **Every function is gated first.** Each one returns its documented default — `false`, `null`, an empty stream, or nothing — when `platformSupport.isSupported` is false, before touching `FlutterImePlatform.instance` (`flutter_ime.dart`, every function). `disableIME`/`enableIME` gate on `isWindowsOnly` instead.
- **The gating policy lives in one place**, `PlatformSupport`, so tests swap it with `debugSetPlatformSupport` rather than faking `Platform` (`platform_support.dart`).
- **Failure is silent.** Since 3.0.0 no public function raises; a failed switch, a stale token or a missing window does nothing (`CHANGELOG.md` 3.0.0, "Failures are silent"). The only raising code in the package is the web stub, which is unreachable through these functions — see [web build](web-build.md).
- **`FlutterImePlatform.instance` is the seam.** It defaults to `FfiFlutterIme()` (a lazy static, so it is built on the first call into the package) and is replaceable through the token-verified setter (`flutter_ime_platform_interface.dart`). The base class throws `UnimplementedError` for anything an override leaves out.
- **`isEnglishKeyboard` asks a different question per platform**: Windows "the IME is not converting to the native language", macOS "the selected layout types English" — owned by [English classification](english-classification.md).

## Code
- `lib/flutter_ime.dart` — the nine top-level functions
- `lib/src/platform_support.dart` — `PlatformSupport`, `platformSupport`, `debugSetPlatformSupport`
- `lib/flutter_ime_platform_interface.dart` — `FlutterImePlatform`, `FlutterImePlatform.instance`
- Tests: `test/platform_gating_test.dart`, `test/flutter_ime_test.dart`, `test/support/mock_flutter_ime_platform.dart`

## Reference behaviour
**None.** The surface is this package's own; it was compared only against its own 2.x behaviour (`CHANGELOG.md`).

## Cross-cutting invariants
- [README samples match the compiled copies](../invariant/readme-samples-match.md) — the README's samples call these functions.

## Blast radius
- [Backend dispatch](backend-dispatch.md) — it must give the same documented default this gating gives, since a caller of `FlutterImePlatform.instance` bypasses the gating.
- [Web build](web-build.md) — the stub assumes no public function reaches the platform interface on web; a function that skipped the gating would throw there.
- [Example app](example-app.md) — the README samples compiled there call these signatures.
- [Package manifest](package-manifest.md) — a changed signature or default is a breaking change for the version and CHANGELOG.

## Known holes / open
- Nothing records why the platform interface still extends `PlatformInterface` with a replaceable `instance` now that there is one implementation; the CHANGELOG says only that the interface "and its `instance` setter are unchanged".
