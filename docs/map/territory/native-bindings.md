# Native bindings

## What it is
The raw `dart:ffi` bindings to the operating system: `imm32.dll`, `user32.dll` and `kernel32.dll` on Windows; CoreFoundation, Carbon (for HIToolbox's Text Input Source Services) and CoreGraphics on macOS. One Dart member per system call or data symbol, and no decisions.

## Governing decisions
**None.**

## Design model
From the source:
- **Mechanical by rule**: one function per call, no branching; anything needing a decision goes to a pure function elsewhere (`win32.dart`, `core_foundation.dart`, `text_input_sources.dart`, `core_graphics.dart` library docs).
- **Libraries open lazily**, on first use of a `late final`, so constructing the FFI implementation on the other OS never tries to load a missing framework (`Win32`, `CoreFoundation`, `TextInputSources`, `CoreGraphics` class docs).
- **CoreFoundation ownership is stated at each binding**: *Copy* and *Create* results are the caller's to release, *Get* results are not, and every call site in `macos_ime.dart` says which it is (`macos_ime.dart` library doc). Leaks and over-releases are silent.
- **Exported `CFStringRef` constants are data symbols**, looked up and dereferenced once; using the undereferenced pointer matches nothing and fails silently (`TextInputSources.propertyInputSourceId` doc).
- **Carbon is opened rather than HIToolbox's versioned path** inside another framework (`TextInputSources` doc).
- **Windows ANSI variants are deliberate** for keyboard-layout names — see [input-source token](input-source-token.md).

## Code
- `lib/src/ffi/win32.dart` — `Win32`, `Handle32`, `iaceDefault`, `vkCapital`, `keyStateToggledMask`, `klNameLength`, `klfActivate`
- `lib/src/ffi/core_foundation.dart` — `CoreFoundation`, `CFRef`, `cfStringEncodingUtf8`, `cfAllocatorDefault`, `cfNotificationSuspensionBehaviorDeliverImmediately`
- `lib/src/ffi/text_input_sources.dart` — `TextInputSources`, `noErr`, `tisEnabledOnly`, `tisAllInstalled`
- `lib/src/ffi/core_graphics.dart` — `CoreGraphics`

## Reference behaviour
- Every row of [thegraph references](../../agents/thegraph.md): signatures and constants are binding against the SDK headers (raw) — `imm.h`, `winuser.h`, `TextInputSources.h`, `CFBase.h`, `CGEventSource.h` — with the published docs as summaries that need confirming against them.

## Cross-cutting invariants
**None.**

## Blast radius
- [English classification](english-classification.md), [English switch](english-switch.md), [Input-source token](input-source-token.md), [Caps Lock](caps-lock.md), [IME disable](ime-disable.md), [Window resolution](window-resolution.md) — a wrong signature or constant here is a wrong answer or a crash there, and nothing in the test suite calls a real binding.
- [macOS input-source observer](macos-input-source-observer.md) — the notification name's dereference and the callback signature live here.

## Known holes / open
- **No test exercises a real binding.** Every test injects fakes; a signature mismatch against the SDK headers is caught only by running on the OS. That is by design: the example app is to exercise every public function on real Windows and macOS before release (#11, "Verification the unit tests deliberately do not cover"). Nothing records that pass per release beyond the issues that ran it (#23).
