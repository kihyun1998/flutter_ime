# No Flutter dependency

## The fact
The package resolves, analyses and runs with no Flutter SDK: no `flutter` constraint or Flutter package in `pubspec.yaml`, `package:lints` rather than `flutter_lints`, tests on `package:test`, and a CI job with no Flutter SDK that analyses and tests the package.

## Why it is cross-cutting
The sites are separate files that nothing links: the manifest, the analysis options, the test imports, and the CI workflow. The `analysis_options.yaml` and `pubspec.yaml` comments each give the same reason ("would drag the Flutter SDK back"). Adding Flutter at any one site breaks the 3.0.0 promise for plain-Dart consumers. CI notices only through the job that has no Flutter: the main suite "passes just as well with a Flutter dependency present" (`ci.yml`, `plain-dart-consumer` comment).

## Territories it holds in
- [Package manifest](../territory/package-manifest.md) — `pubspec.yaml` `environment` (no `flutter:`) and `dependencies`; `analysis_options.yaml` `include: package:lints/recommended.yaml`.
- [CI](../territory/ci.md) — job `dart` (no Flutter SDK, `--no-example`) and job `plain-dart-consumer`.
- Tests — `test/*.dart` import `package:test` and `package:fake_async`; `change_stream_test.dart` defines its own `pumpEventQueue` in place of `flutter_test`'s.

## What a violation looks like
`dart pub get` in a plain Dart project fails to resolve `flutter_ime`, or the `dart` CI job fails at install. It reproduces as soon as any of these files gains a Flutter import or constraint.

## Discovery history
- Commit `8397162` (2026-07-22): the dependency was removed and verified with a plain Dart consumer end to end.
- Commit `b2ba051` (2026-07-22): the Dart CI job made to run without Flutter.

## Where it will recur
Any new dependency, dev dependency, lint set or test helper: check whether it depends on the Flutter SDK. `example/` is exempt — it is a Flutter app and nothing in it ships.
