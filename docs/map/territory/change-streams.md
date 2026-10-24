# Change streams

## What it is
Turning a value that moves underneath the package into a broadcast stream of its changes. `ChangeStream` holds the rules both platforms share; `ValuePoller` is `ChangeStream` with a periodic timer as its trigger. Every public stream is one of these.

## Governing decisions
**None.**

## Design model
From the source (`change_stream.dart` library doc: "what re-reads the value is injected; everything else is not"):
- **Starts on the first listener and stops on the last cancel**, so an unobserved stream costs nothing (`ChangeStream.stream`, `_begin`, `_end`).
- **The value current at subscription is the baseline, not an emission**, and is re-read on every fresh subscription; changes while nobody listened are not replayed (`_begin`).
- **A trigger is a hint to re-read, not an event.** A reading equal to the baseline is dropped, so spurious triggers cost one read — macOS posts its notification twice per switch (`startInputSourceNotifications` doc).
- **Null is "ask again", not a value**: an unreadable reading keeps the baseline, and a thrown read is treated as unreadable, because a throw in a timer or native callback has nowhere useful to go (`_reread`, `_readOrNull`).
- **The trigger starts before the baseline read**, so a throwing read cannot leave a subscribed-but-dead stream (`_begin` comment).
- **Disposed means disposed**: reading `stream` afterwards throws `StateError` instead of quietly restarting (`stream`, `dispose`).
- **Free of `dart:ffi`**, so all of it is unit-tested on any host with `fake_async`.

## Code
- `lib/src/change_stream.dart` — `ChangeStream`, `stream`, `_begin`, `_reread`, `_readOrNull`, `_end`, `dispose`
- `lib/src/value_poller.dart` — `ValuePoller`
- Tests: `test/change_stream_test.dart`, `test/value_poller_test.dart`

## Reference behaviour
**None.**

## Cross-cutting invariants
- [Unreadable is null, not false](../invariant/unreadable-is-null.md) — this is the consumer that gives null its meaning.

## Blast radius
- [Backend dispatch](backend-dispatch.md) — it builds all three streams over this; a changed start/stop contract changes when polling runs and when the macOS observer is registered.
- [macOS input-source observer](macos-input-source-observer.md) — its `start`/`stop` are this class's trigger, and it relies on `stop` being called on last cancel to release the isolate.
- [Caps Lock](caps-lock.md), [English classification](english-classification.md) — their readers' values are what is compared; a reader that is not stable for the same state emits phantom changes.
- [Public API](public-api.md) — "emits only on a change, not the value you started from" is documented on both public streams and in `CHANGELOG.md` 3.0.0 as a breaking change.

## Known holes / open
**None.**
