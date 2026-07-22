@TestOn('windows')
library;

import 'dart:ffi';

import 'package:flutter_ime/src/ffi/win32.dart';
import 'package:flutter_ime/src/ffi/window_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stand-in handles. Only their identity matters; nothing dereferences them.
Handle32 handle(int address) => Pointer<Void>.fromAddress(address);

final Handle32 runner = handle(0x1000);
final Handle32 view = handle(0x2000);
final Handle32 foreground = handle(0x3000);

/// Builds a resolver whose window lookups are all faked, so the precedence
/// chain and the caching rule can be exercised without an operating system.
WindowResolver buildResolver({
  Handle32? topLevel,
  Handle32? child,
  Handle32? foregroundWindow,
  bool Function(Handle32)? isAlive,
  void Function(String className)? onTopLevelLookup,
}) {
  return WindowResolver(
    findOwnTopLevelWindow: (className) {
      onTopLevelLookup?.call(className);
      return topLevel ?? nullptr;
    },
    findChildWindow: (parent, className) => child ?? nullptr,
    getForegroundWindow: () => foregroundWindow ?? nullptr,
    isWindowAlive: isAlive ?? (_) => true,
  );
}

void main() {
  group('precedence', () {
    test('prefers the Flutter view child, matching the native plugin', () {
      final resolved =
          buildResolver(topLevel: runner, child: view).resolve();

      expect(resolved.handle, view);
      expect(resolved.source, WindowResolution.flutterView);
    });

    test('falls back to the runner window when the view child is missing', () {
      final resolved = buildResolver(topLevel: runner).resolve();

      expect(resolved.handle, runner);
      expect(resolved.source, WindowResolution.runnerWindow);
    });

    test('falls back to the foreground window when no runner window is ours',
        () {
      final resolved =
          buildResolver(foregroundWindow: foreground).resolve();

      expect(resolved.handle, foreground);
      expect(resolved.source, WindowResolution.foregroundWindow);
    });

    test('reports nothing usable when every lookup comes back empty', () {
      final resolved = buildResolver().resolve();

      expect(resolved.isUsable, isFalse);
      expect(resolved.source, WindowResolution.none);
    });

    test('looks the runner window up by the Flutter runner class name', () {
      final seen = <String>[];
      buildResolver(topLevel: runner, onTopLevelLookup: seen.add).resolve();

      expect(seen, [kFlutterRunnerWindowClass]);
    });
  });

  group('caching', () {
    test('does not search again while the cached window is alive', () {
      var lookups = 0;
      final resolver = buildResolver(
        topLevel: runner,
        child: view,
        onTopLevelLookup: (_) => lookups++,
      );

      resolver.resolve();
      resolver.resolve();
      resolver.resolve();

      expect(lookups, 1);
    });

    test('searches again once the cached window is dead', () {
      var lookups = 0;
      var alive = true;
      final resolver = buildResolver(
        topLevel: runner,
        child: view,
        isAlive: (_) => alive,
        onTopLevelLookup: (_) => lookups++,
      );

      resolver.resolve();
      expect(lookups, 1);

      // The window is recreated; the cached handle is now stale.
      alive = false;
      resolver.resolve();

      expect(lookups, 2);
    });

    test('searches again after being explicitly invalidated', () {
      var lookups = 0;
      final resolver = buildResolver(
        topLevel: runner,
        child: view,
        onTopLevelLookup: (_) => lookups++,
      );

      resolver.resolve();
      resolver.invalidate();
      resolver.resolve();

      expect(lookups, 2);
    });

    test('keeps retrying while nothing is resolvable', () {
      var lookups = 0;
      final resolver = buildResolver(onTopLevelLookup: (_) => lookups++);

      resolver.resolve();
      resolver.resolve();

      // An unusable result must never be cached as if it were valid, or the
      // package would go permanently dead after one unlucky early call.
      expect(lookups, 2);
    });
  });
}
