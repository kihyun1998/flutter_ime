# Territory map

The territory map. A comment's why, trap and measured value go to a note here.
Notes are added as they come up, or all at once with `grill-map`, which also
reads hand-written notes as leads and keeps their paths.

<!-- grill-map build stamp: 8e5a943 -->
<!-- grill-map synced at: c52963f (2026-10-24) -->

## What it answers

| Question | Open |
|---|---|
| *If I touch this, what else moves?* | the territory below, then its `## Blast radius` and `## Cross-cutting invariants` |
| *What decision is this shape derived from?* | its `## Governing decisions` and `## Design model`, each claim with its evidence |

`## Blast radius` is a checklist: an edge with nothing to do is a correct outcome. A `**None.**` is itself an answer. This repo has no decision records, so every `## Governing decisions` reads **None.** and names the issue or commit that settled it instead.

## The repo in one paragraph

`flutter_ime` is a plain Dart package, without Flutter, that controls the IME on Windows and macOS through `dart:ffi`. Nine public functions gate on the platform, then dispatch to a Windows backend (IMM32 and user32 against the app's own window) or a macOS backend (Text Input Source Services, CoreFoundation and CoreGraphics). Every interpretation lives in a pure function, and every change stream in one shared class, so all of it is tested with fakes. What no automated check covers is the bindings against a real OS: that is a manual pre-release pass on the example app, by design (#11) ([native bindings](territory/native-bindings.md), [CI](territory/ci.md)). That is the largest gap.

## Territories

Public surface
- [Public API](territory/public-api.md)
- [Backend dispatch](territory/backend-dispatch.md)
- [Web build](territory/web-build.md)

Features
- [English classification](territory/english-classification.md)
- [English switch](territory/english-switch.md)
- [Input-source token](territory/input-source-token.md)
- [IME disable](territory/ime-disable.md)
- [Window resolution](territory/window-resolution.md)
- [Caps Lock](territory/caps-lock.md)

Shared machinery
- [Change streams](territory/change-streams.md)
- [macOS input-source observer](territory/macos-input-source-observer.md)
- [Native bindings](territory/native-bindings.md)

Shipping
- [Package manifest](territory/package-manifest.md)
- [CI](territory/ci.md)
- [Example app](territory/example-app.md)

## Cross-cutting invariants

- [Unreadable is null, not false](invariant/unreadable-is-null.md)
- [No Flutter dependency](invariant/no-flutter-dependency.md)
- [README samples match the compiled copies](invariant/readme-samples-match.md)

## Conventions

- Section headings are exact strings in every note. An empty one holds `**None.**`.
- Code is cited by symbol (`file — Symbol`), never by line.
- A fact another artifact owns, such as an issue's state or a count, is linked, never restated.
- Every claim carries its evidence (a symbol, a commit) or its source and date (`(maintainer, 2026-10-24)`).
- External sources are the rows of [`docs/agents/thegraph.md`](../agents/thegraph.md). Its "summarized" rows need confirming against the headers.

## What the map cannot answer

Source files, tests, issues and commits are text inside notes, not nodes. The map does not list every caller of a symbol; grep does that.

## Scope

A territory gets a note when the repo commits to it with code, a spec or an open issue that has a design. An idea with nothing behind it does not get one, so an absent note means nothing here does that.

Out of scope, with reasons:
- `docs/agents/` is agent configuration, not part of the system.
- `.codeignore` is configuration for an outside code-dump tool, and nothing in the repo reads it (maintainer, 2026-10-24).
- `LICENSE`.
- The downstream consumer `flutter_password_input` was not read (maintainer, 2026-10-24). See [package manifest](territory/package-manifest.md).
