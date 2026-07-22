/// Turns a value that moves underneath you into a stream of its changes.
///
/// **What re-reads the value is injected; everything else is not.** Windows has
/// to poll on a timer, and macOS is told by a system notification, but "start
/// on the first listener, capture a baseline, emit only what differs from it,
/// ignore an unreadable reading, stop on the last cancel" is the same either
/// way. Writing that twice would mean two sets of rules to keep in agreement,
/// and only one of them would have the tests.
///
/// Both the reader and the trigger are callbacks, so all of it is unit-testable
/// with no timer, no OS call and no IME.
///
/// Kept free of `dart:ffi` so it can be tested on any platform, and so the FFI
/// layer stays a thin adapter with no branching logic of its own.
library;

import 'dart:async';

/// Emits each reading of [read] that differs from the one before it, re-reading
/// whenever the injected trigger says to.
///
/// [T] is non-nullable so that "no value yet" and "the value is null" cannot be
/// confused — the absence of a baseline is meaningful state here.
class ChangeStream<T extends Object> {
  ChangeStream({
    required T? Function() read,
    required void Function(void Function() reread) start,
    required void Function() stop,
  })  : _read = read,
        _start = start,
        _stop = stop;

  /// Returns the current value, or null when it momentarily cannot be read.
  ///
  /// Null is not a value — it is "ask again next time". The Windows IME
  /// conversion state is unreadable while `disableIME()` has the context
  /// detached, and reporting that as a value would announce an input-source
  /// change on every disable and another on every enable, neither of which
  /// happened.
  final T? Function() _read;

  /// Begins delivering triggers, calling the callback it is given each time the
  /// value might have moved. A trigger is permitted to be spurious: a reading
  /// equal to the baseline is discarded, so over-triggering costs a read and
  /// nothing else.
  final void Function(void Function() reread) _start;

  /// Stops delivering triggers. Must tolerate being called when nothing was
  /// started, since [dispose] can run on a stream nobody ever listened to.
  final void Function() _stop;

  StreamController<T>? _controller;
  bool _disposed = false;

  /// The value the next reading compares against, or null when there is nothing
  /// to compare against yet. Captured when a listener attaches, never before.
  T? _baseline;

  /// The changes, as a broadcast stream.
  ///
  /// The value current when a listener attaches is **not** emitted. It becomes
  /// the baseline, and only later transitions are reported — a stream named for
  /// changes should not fire merely because it was subscribed to. The native
  /// plugin behaved the same way: attaching a sink captured the state rather
  /// than sending it.
  Stream<T> get stream {
    if (_disposed) {
      // Without this the getter would quietly build a second controller and
      // start a second trigger, so a disposed stream would come back to life on
      // the next listen.
      throw StateError('This ChangeStream has been disposed.');
    }
    final controller = _controller ??= StreamController<T>.broadcast(
      onListen: _begin,
      onCancel: _end,
    );
    return controller.stream;
  }

  void _begin() {
    // Start the trigger before taking the baseline. If the read throws, the
    // exception would otherwise escape `listen()` with the subscription already
    // registered, leaving a stream that is subscribed but permanently dead —
    // `onListen` only fires for the first listener and would never fire again.
    _start(_reread);

    // Re-read on every fresh subscription. A change that happened while nobody
    // was listening is not replayed: the one-shot query is there for callers
    // who need the current value, and the stream reports transitions it
    // actually observed.
    _baseline = _readOrNull();
  }

  void _reread() {
    final value = _readOrNull();
    // An unreadable value is not a change. Skipping keeps a transient gap from
    // being reported as a transition, and preserves the baseline so the
    // comparison resumes against the last value actually seen.
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
  /// allocate. A throw inside a timer callback escapes as an uncaught async
  /// error, which would reach the app's zone on every interval; a throw inside
  /// a native callback has nowhere to go at all.
  T? _readOrNull() {
    try {
      return _read();
    } catch (_) {
      return null;
    }
  }

  void _end() {
    _stop();
    _baseline = null;
  }

  /// Stops the trigger and closes the stream. Safe to call more than once.
  ///
  /// Reading [stream] afterwards throws rather than silently starting over.
  void dispose() {
    _disposed = true;
    _end();
    _controller?.close();
    _controller = null;
  }
}
