# macOS input-source observer

## What it is
Being told by macOS that the keyboard changed. The package registers a CoreFoundation distributed-notification observer for `kTISNotifySelectedKeyboardInputSourceChanged`, bridged into Dart with a listener `NativeCallable`, and serves it as the trigger of the macOS input-source `ChangeStream`. Its lifecycle — hot restart, a second instance, isolate exit — is the subtle part.

## Governing decisions
**None.** The lifecycle was settled across commits `d48cd08`, `9ca6e01` and `b0bbef3` (2026-07-22) and `CHANGELOG.md` 3.0.0's one-observer note.

## Design model
From the source (`macos_ime.dart`):
- **Push, not polling**: a notification callback returns nothing, which a listener callable can be; Windows cannot do the same because a window procedure must return a value synchronously (`startInputSourceNotifications` doc).
- **The callable is created once and never closed.** `CFNotificationCenterRemoveObserver` stops only deliveries not yet enqueued, so closing on cancel would let a queued block call freed memory (`_callable` doc; commit `9ca6e01`). `_onChanged` is nulled instead, so a late delivery reaches a live callable that does nothing.
- **The observer token is an address every isolate computes the same way** — the notification name's `CFStringRef` — not the callable's address. Hot restart destroys the isolate and its callable but not the process's registration; with a shared token the next isolate can find and remove the stale one (`_observerToken` doc). It is removed in the constructor and again before every add.
- **Therefore one registration per process.** A second live `MacosIme` that subscribes throws `StateError` instead of silently unregistering the first (`_observerOwner`, `startInputSourceNotifications`; commit `b0bbef3`). The constructor clears stale registrations only when no instance in this isolate owns one.
- **`keepIsolateAlive` tracks the registration, not the callable**: true while registered, false after stop, so a plain Dart CLI can exit (`_callable` doc). This is why the SDK floor is 3.4 — see [package manifest](package-manifest.md).
- **Delivered immediately even when the app is suspended** (`cfNotificationSuspensionBehaviorDeliverImmediately` doc).

## Code
- `lib/src/ffi/macos_ime.dart` — `MacosIme` constructor, `_observerOwner`, `debugResetObserverOwner`, `_callable`, `_onChanged`, `_observerToken`, `startInputSourceNotifications`, `stopInputSourceNotifications`, `_removeObserver`
- `lib/src/ffi/core_foundation.dart` — `notificationCenterGetDistributedCenter`, `notificationCenterAddObserver`, `notificationCenterRemoveObserver`, `CFNotificationCallbackNative`
- `lib/src/ffi/text_input_sources.dart` — `notifySelectedKeyboardInputSourceChanged`
- Tests: `test/macos_observer_lifecycle_test.dart`

## Reference behaviour
- `CFNotificationCenterAddObserver` / `RemoveObserver` delivery semantics — Apple docs (summarized) and `CFNotificationCenter.h`; the "removal does not stop enqueued deliveries" behaviour is recorded from the crash, not from the header ([thegraph references](../../agents/thegraph.md)).
- `NativeCallable.listener` and `keepIsolateAlive` — dart.dev docs (summarized).

## Cross-cutting invariants
**None.**

## Blast radius
- [Change streams](change-streams.md) — the observer is started and stopped only through `ChangeStream`'s first-listen / last-cancel; a stream that never cancels keeps the isolate alive.
- [Backend dispatch](backend-dispatch.md) — `FfiFlutterIme` builds one `MacosIme`; a second `FfiFlutterIme` (or a hand-built `MacosIme`) that subscribes while the first listens hits the `StateError`.
- [Package manifest](package-manifest.md) — the Dart 3.4 floor exists for `keepIsolateAlive`.
- [Native bindings](native-bindings.md) — the notification name is a data symbol that must be dereferenced; the undereferenced pointer subscribes to a name nothing posts.

## Known holes / open
- The never-closed callable is one allocation per process lifetime by design; nothing measures it.
- Whether a Flutter app with two engines (two isolates live at once) can observe from both is unaddressed: the one-registration rule is per process, `_observerOwner` is per isolate.
