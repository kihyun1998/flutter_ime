/// Resolves the window handle that IMM32 calls should target.
///
/// The native plugin got this handle from the Flutter plugin registrar, which
/// does not exist in a pure Dart package. This resolves it from the process's
/// own window tree instead.
///
/// The window lookups are injected as callbacks rather than called directly, so
/// the precedence chain and the cache-invalidation rule — the two things here
/// that can silently regress — are unit-testable without an operating system.
/// This mirrors how the polling implementation takes a reader callback.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'win32.dart';

/// Class name of the top-level window created by the Flutter Windows runner.
///
/// Confirmed by enumerating a running example app: the runner creates one
/// top-level window of this class, with the view as its direct child.
const String kFlutterRunnerWindowClass = 'FLUTTER_RUNNER_WIN32_WINDOW';

/// Class name of the Flutter view, a child of the runner window. This is the
/// window the native plugin operated on, so it is what we prefer.
const String kFlutterViewWindowClass = 'FLUTTERVIEW';

/// Where a resolved handle came from. Exposed so the example app can show it,
/// making a missed lookup visible rather than silent.
enum WindowResolution {
  /// The Flutter view child window — matches what the native plugin used.
  flutterView,

  /// The top-level runner window, used when no view child was found.
  runnerWindow,

  /// The foreground window. The native plugin used this same fallback.
  foregroundWindow,

  /// Nothing usable was found.
  none,
}

/// The outcome of a resolution attempt.
class ResolvedWindow {
  const ResolvedWindow(this.handle, this.source);

  final Handle32 handle;
  final WindowResolution source;

  bool get isUsable => handle != nullptr;

  @override
  String toString() =>
      'ResolvedWindow(0x${handle.address.toRadixString(16)}, ${source.name})';
}

/// Looks up the first top-level window of [className] owned by this process.
typedef FindOwnTopLevelWindow = Handle32 Function(String className);

/// Looks up a direct child of [parent] with [className].
typedef FindChildWindow = Handle32 Function(Handle32 parent, String className);

/// Returns the current foreground window.
typedef GetForegroundWindow = Handle32 Function();

/// Whether [handle] still refers to a live window.
typedef IsWindowAlive = bool Function(Handle32 handle);

/// Finds and caches the window IMM32 calls should target.
///
/// The handle is cached because resolution walks the window list, and
/// re-validated on every access because a cached handle goes stale when the
/// window is recreated.
class WindowResolver {
  WindowResolver({
    FindOwnTopLevelWindow? findOwnTopLevelWindow,
    FindChildWindow? findChildWindow,
    GetForegroundWindow? getForegroundWindow,
    IsWindowAlive? isWindowAlive,
    Win32? win32,
  }) {
    final calls = _Win32WindowCalls(win32 ?? Win32.instance);
    _findOwnTopLevelWindow = findOwnTopLevelWindow ?? calls.findOwnTopLevel;
    _findChildWindow = findChildWindow ?? calls.findChild;
    _getForegroundWindow = getForegroundWindow ?? calls.foreground;
    _isWindowAlive = isWindowAlive ?? calls.isAlive;
  }

  late final FindOwnTopLevelWindow _findOwnTopLevelWindow;
  late final FindChildWindow _findChildWindow;
  late final GetForegroundWindow _getForegroundWindow;
  late final IsWindowAlive _isWindowAlive;

  ResolvedWindow? _cached;

  /// Drops the cached handle, forcing the next [resolve] to search again.
  void invalidate() => _cached = null;

  /// Returns the window to operate on, searching only when there is no cached
  /// handle or the cached one is no longer a live window.
  ResolvedWindow resolve() {
    final cached = _cached;
    if (cached != null && cached.isUsable && _isWindowAlive(cached.handle)) {
      return cached;
    }
    return _cached = _search();
  }

  ResolvedWindow _search() {
    final runner = _findOwnTopLevelWindow(kFlutterRunnerWindowClass);
    if (runner != nullptr) {
      final view = _findChildWindow(runner, kFlutterViewWindowClass);
      if (view != nullptr) {
        return ResolvedWindow(view, WindowResolution.flutterView);
      }
      return ResolvedWindow(runner, WindowResolution.runnerWindow);
    }

    // The native plugin fell back to the foreground window too, so this is a
    // pre-existing weakness rather than a new one.
    final foreground = _getForegroundWindow();
    if (foreground != nullptr) {
      return ResolvedWindow(foreground, WindowResolution.foregroundWindow);
    }
    return ResolvedWindow(nullptr, WindowResolution.none);
  }
}

/// The real Win32-backed lookups. Split out so [WindowResolver] holds only the
/// precedence and caching rules.
class _Win32WindowCalls {
  _Win32WindowCalls(this._win32);

  final Win32 _win32;

  /// Walks the top-level windows of [className], returning the first owned by
  /// this process. Filtering by process id matters: another Flutter app running
  /// at the same time has windows of the same class.
  Handle32 findOwnTopLevel(String className) {
    final ownPid = _win32.getCurrentProcessId();
    final classNamePtr = className.toNativeUtf16();
    final pidOut = calloc<Uint32>();
    try {
      Handle32 current = nullptr;
      while (true) {
        current = _win32.findWindowEx(nullptr, current, classNamePtr, nullptr);
        if (current == nullptr) return nullptr;
        _win32.getWindowThreadProcessId(current, pidOut);
        if (pidOut.value == ownPid) return current;
      }
    } finally {
      calloc.free(pidOut);
      calloc.free(classNamePtr);
    }
  }

  Handle32 findChild(Handle32 parent, String className) {
    final classNamePtr = className.toNativeUtf16();
    try {
      return _win32.findWindowEx(parent, nullptr, classNamePtr, nullptr);
    } finally {
      calloc.free(classNamePtr);
    }
  }

  Handle32 foreground() => _win32.getForegroundWindow();

  bool isAlive(Handle32 handle) => _win32.isWindow(handle) != 0;
}
