# README samples match the compiled copies

## The fact
Every Dart sample in `README.md` appears verbatim in `example/lib/readme_examples.dart`. The only additions allowed are the `StatefulWidget` wrapper a `State` needs and a numeric class-name suffix.

## Why it is cross-cutting
A Markdown file and a Dart file, and nothing generates one from the other. The rule is the file header of `readme_examples.dart` ("If you change a sample here, change it in the README, and the other way round"). Only the Dart copy is type-checked, by `flutter analyze` in CI. A README edit not mirrored there ships documentation that no check has compiled.

## Territories it holds in
- [Public API](../territory/public-api.md) — the README's "Usage" and recipe sections, which document its functions.
- [Example app](../territory/example-app.md) — `readme_examples.dart`, `readmeUsage` and the sample `State` classes.
- [CI](../territory/ci.md) — `example-web`'s `flutter analyze`.

## What a violation looks like
A README sample that no longer compiles against the current API, while CI stays green. The samples were stale once already: they were written against 2.x (`readme_examples.dart` header).

## Discovery history
- `example/lib/readme_examples.dart` header, added with the 3.0.0 docs rewrite (commit `8417bf9`, 2026-07-23).

## Where it will recur
Any edit to a fenced `dart` block in `README.md`, or to `readme_examples.dart`: the other file needs the same edit. Diff the two by hand. No check compares them. Tracked: #31
