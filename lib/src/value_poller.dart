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
///
/// [T] is non-nullable so that "no value yet" and "the value is null" cannot be
/// confused — the absence of a baseline is meaningful state here.
class ValuePoller<T extends Object> {
  ValuePoller({required T? Function() read, required Duration interval})
      : _read = read,
        _interval = interval;

  /// Returns the current value, or null when it momentarily cannot be read.
  ///
  /// Null is not a value — it is "ask again next tick". The Windows IME
  /// conversion state is unreadable while `disableIME()` has the context
  /// detached, and reporting that as a value would announce an input-source
  /// change on every disable and another on every enable, neither of which
  /// happened.
  final T? Function() _read;
  final Duration _interval;

  StreamController<T>? _controller;
  Timer? _timer;
  bool _disposed = false;

  /// The value the next poll compares against, or null when there is nothing to
  /// compare against yet. Captured when a listener attaches, never before.
  T? _baseline;

  /// Changes to the polled value, as a broadcast stream.
  ///
  /// The value current when a listener attaches is **not** emitted. It becomes
  /// the baseline, and only later transitions are reported — a stream named for
  /// changes should not fire merely because it was subscribed to. The native
  /// plugin behaved the same way: attaching a sink captured the state rather
  /// than sending it.
  Stream<T> get stream {
    if (_disposed) {
      // Without this the getter would quietly build a second controller and
      // start a second timer, so a disposed poller would come back to life on
      // the next listen.
      throw StateError('This ValuePoller has been disposed.');
    }
    final controller = _controller ??= StreamController<T>.broadcast(
      onListen: _startPolling,
      onCancel: _stopPolling,
    );
    return controller.stream;
  }

  void _startPolling() {
    // Start the timer before taking the baseline. If the read throws, the
    // exception would otherwise escape `listen()` with the subscription already
    // registered, leaving a stream that is subscribed but permanently dead —
    // `onListen` only fires for the first listener and would never fire again.
    _timer = Timer.periodic(_interval, (_) => _poll());

    // Re-read on every fresh subscription. A change that happened while nobody
    // was listening is not replayed: the one-shot query is there for callers
    // who need the current value, and the stream reports transitions it
    // actually observed.
    _baseline = _readOrNull();
  }

  void _poll() {
    final value = _readOrNull();
    // An unreadable value is not a change. Skipping the tick keeps a transient
    // gap from being reported as a transition, and preserves the baseline so
    // the comparison resumes against the last value actually seen.
    if (value == null) return;

    if (_baseline == null) {
      _baseline = value;
      return;
    }
    if (value == _baseline) return;

    _baseline = value;
    _controller?.add(value);
  }

  /// Reads the value, treating a thrown error the same as an unreadable one.
  ///
  /// The readers this is used with are written not to throw, but they do
  /// allocate. A throw inside `Timer.periodic` escapes as an uncaught async
  /// error, which would reach the app's zone on every interval.
  T? _readOrNull() {
    try {
      return _read();
    } catch (_) {
      return null;
    }
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
    _baseline = null;
  }

  /// Stops polling and closes the stream. Safe to call more than once.
  ///
  /// Reading [stream] afterwards throws rather than silently starting over.
  void dispose() {
    _disposed = true;
    _stopPolling();
    _controller?.close();
    _controller = null;
  }
}
