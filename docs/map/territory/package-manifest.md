# Package manifest

## What it is
What gets published to pub.dev and what a consumer's resolver sees: `pubspec.yaml` (SDK floor, declared platforms, dependency constraints, version), the `CHANGELOG.md` entry for each release, and the dependency-update policy proposed in the open backlog.

## Governing decisions
**None.** The open issue #28 holds the Dependabot design (`increase-if-necessary` at the root, one PR per dependency; grouped monthly for `example/` and Actions). Tracked: #28.

## Design model
From the source:
- **SDK floor `>=3.4.0`**: 3.1 brought `NativeCallable`, 3.4 its `keepIsolateAlive` setter, which the never-closed macOS observer needs so a plain Dart CLI can exit (`pubspec.yaml` `environment` comment). Nothing else needs 3.4.
- **No `flutter` constraint**, because declaring one makes Flutter a requirement for every consumer — see [No Flutter dependency](../invariant/no-flutter-dependency.md).
- **Platforms are declared, not inferred**: `macos`, `windows`, and `web` (which compiles, does nothing), with Android, iOS and Linux deliberately absent — safe is not supported, and pub.dev readers take the list as a capability list (`pubspec.yaml` `platforms` comment).
- **Runtime dependencies**: `ffi`, `meta`, `plugin_platform_interface`. `plugin_platform_interface` needs only `meta`, which is what made dropping Flutter possible (commit `8397162`).
- **The input-source token format is part of the published contract** — changing it breaks saved tokens; see [input-source token](input-source-token.md).
- **A raised floor here becomes the downstream consumer's floor** (issue #28, "Further Notes"; maintainer named `flutter_password_input` there).

## Code
- `pubspec.yaml` — `environment`, `platforms`, `dependencies`, `dev_dependencies`, `version`
- `CHANGELOG.md`
- `analysis_options.yaml`
- `.github/dependabot.yml` — **None.** It does not exist yet; #28 describes it.

## Reference behaviour
- `NativeCallable.keepIsolateAlive` availability by SDK version — dart.dev docs (summarized; [thegraph references](../../agents/thegraph.md)).

## Cross-cutting invariants
- [No Flutter dependency](../invariant/no-flutter-dependency.md)

## Blast radius
- [CI](ci.md) — the plain-Dart consumer job pins its own `sdk:` constraint and must move with the floor here.
- [macOS input-source observer](macos-input-source-observer.md) — lowering the SDK floor below 3.4 removes the setter it depends on.
- [Example app](example-app.md) — it depends on this package by path and has its own SDK constraint (`^3.6.1`) and lockfile.
- [Public API](public-api.md) — every behaviour change there is a CHANGELOG entry and a version decision here.

## Known holes / open
- Dependabot is not configured (Tracked: #28).
- The downstream consumer `flutter_password_input` was not read (maintainer, 2026-10-24: skip for now); which functions it calls and which floor it pins are unknown here.
- No committed root lockfile, by design for a package (issue #28).
