/// Turns a value that has to be polled into a stream of changes.
///
/// Windows needs this because there is no way to be told when the IME state
/// moves. The native plugin learned about changes from window messages, but a
/// window procedure has to return a value synchronously on the platform
/// thread, and Dart FFI has no callback that can do that: an isolate-local
/// callable is bound to its isolate's thread, and a listener callable is
/// asynchronous and returns nothing.
///
/// The value is read through an injected callback rather than read directly,
/// so the timing and de-duplication rules here are unit-testable under
/// `FakeAsync` with no timer, no OS call and no IME. This is the same seam
/// shape the window resolver uses for its lookups.
///
/// Kept free of `dart:ffi` so it can be tested on any platform, and so the FFI
/// layer stays a thin adapter with no branching logic of its own.
library;

import 'dart:async';

/// Reads [read] every [interval] while something is listening, and emits each
/// value that differs from the one before it.
///
/// Polling starts on the first listener and stops on the last cancel, so an
/// unobserved stream costs nothing.
class ValuePoller<T> {
  ValuePoller({required T Function() read, required Duration interval})
      : _read = read,
        _interval = interval;

  final T Function() _read;
  final Duration _interval;

  StreamController<T>? _controller;
  Timer? _timer;

  /// The value the next poll compares against. Captured when a listener
  /// attaches, never before — there is nothing to compare against until
  /// someone is watching.
  T? _baseline;

  /// Changes to the polled value, as a broadcast stream.
  ///
  /// The value current when a listener attaches is **not** emitted. It becomes
  /// the baseline, and only later transitions are reported — a stream named for
  /// changes should not fire merely because it was subscribed to. The native
  /// plugin behaves the same way: attaching a sink captured the state rather
  /// than sending it.
  Stream<T> get stream {
    final controller = _controller ??= StreamController<T>.broadcast(
      onListen: _startPolling,
      onCancel: _stopPolling,
    );
    return controller.stream;
  }

  void _startPolling() {
    // Re-read on every fresh subscription. A change that happened while nobody
    // was listening is not replayed: the one-shot query is there for callers
    // who need the current value, and the stream reports transitions it
    // actually observed.
    _baseline = _read();
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  void _poll() {
    final value = _read();
    if (value == _baseline) return;
    _baseline = value;
    _controller?.add(value);
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
    _baseline = null;
  }

  /// Stops polling and closes the stream. Safe to call more than once.
  void dispose() {
    _stopPolling();
    _controller?.close();
    _controller = null;
  }
}
