/// Turns a value that has to be polled into a stream of changes.
///
/// Windows needs this because there is no way to be told when the IME state
/// moves. The native plugin learned about changes from window messages, but a
/// window procedure has to return a value synchronously on the platform
/// thread, and Dart FFI has no callback that can do that: an isolate-local
/// callable is bound to its isolate's thread, and a listener callable is
/// asynchronous and returns nothing.
///
/// macOS is not in that position — a distributed notification observer returns
/// nothing, so it can be bridged — which is why the timer lives here rather
/// than in [ChangeStream]. Everything the two platforms agree on is there
/// instead; this file is only the clock.
///
/// The value is read through an injected callback rather than read directly,
/// so the timing and de-duplication rules are unit-testable under `FakeAsync`
/// with no timer, no OS call and no IME. This is the same seam shape the window
/// resolver uses for its lookups.
///
/// Kept free of `dart:ffi` so it can be tested on any platform, and so the FFI
/// layer stays a thin adapter with no branching logic of its own.
library;

import 'dart:async';

import 'change_stream.dart';

/// Reads [read] every [interval] while something is listening, and emits each
/// value that differs from the one before it.
///
/// Polling starts on the first listener and stops on the last cancel, so an
/// unobserved stream costs nothing.
///
/// [T] is non-nullable so that "no value yet" and "the value is null" cannot be
/// confused — the absence of a baseline is meaningful state here.
class ValuePoller<T extends Object> {
  ValuePoller({required T? Function() read, required Duration interval}) {
    _changes = ChangeStream<T>(
      read: read,
      start: (reread) => _timer = Timer.periodic(interval, (_) => reread()),
      stop: () {
        _timer?.cancel();
        _timer = null;
      },
    );
  }

  late final ChangeStream<T> _changes;
  Timer? _timer;

  /// Changes to the polled value, as a broadcast stream.
  ///
  /// The value current when a listener attaches is **not** emitted; it becomes
  /// the baseline. See [ChangeStream.stream].
  Stream<T> get stream => _changes.stream;

  /// Stops polling and closes the stream. Safe to call more than once.
  ///
  /// Reading [stream] afterwards throws rather than silently starting over.
  void dispose() => _changes.dispose();
}
