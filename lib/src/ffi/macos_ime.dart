/// macOS IME operations expressed directly against Text Input Source Services.
///
/// A thin adapter: build a CoreFoundation value, make one system call, release
/// what was created, and hand any interpretation to a pure function. There is
/// deliberately no logic here beyond null guards, because nothing in this file
/// can be unit-tested without a live window server.
///
/// **Release semantics are the thing to get right here, and leaks are silent.**
/// The rule this file follows is the CoreFoundation one: a value from a
/// *Copy* or *Create* call is owned by us and must be released; a value from a
/// *Get* call is owned by something else and must not be. Each call site says
/// which it is.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../english_input_source.dart';
import 'core_foundation.dart';
import 'core_graphics.dart';
import 'text_input_sources.dart';

class MacosIme {
  MacosIme({
    CoreFoundation? coreFoundation,
    TextInputSources? textInputSources,
    CoreGraphics? coreGraphics,
  })  : _cf = coreFoundation ?? CoreFoundation.instance,
        _tis = textInputSources ?? TextInputSources.instance,
        _cg = coreGraphics ?? CoreGraphics.instance;

  final CoreFoundation _cf;
  final TextInputSources _tis;
  final CoreGraphics _cg;

  /// The layout [setEnglishKeyboard] switches to.
  ///
  /// ABC rather than "whichever English layout is already installed", matching
  /// 2.x. The classification fix means a Dvorak or Colemak user is no longer
  /// *pushed* here by the "force English" recipe — [isEnglishKeyboard] already
  /// answers true for them — so this only runs when a caller asks for English
  /// outright.
  static const String _englishInputSourceId = 'com.apple.keylayout.ABC';

  /// Switches the keyboard to the English (ABC) layout.
  ///
  /// Returns false when that layout is not among the user's enabled input
  /// sources, or when the switch is refused.
  ///
  /// Deliberately restricted to sources the user has already enabled, unlike
  /// [setInputSource]. Selecting ABC for someone who never enabled it would add
  /// a keyboard to their input menu that they did not ask for. Restoring is
  /// different: it hands back a keyboard that was theirs to begin with.
  bool setEnglishKeyboard() =>
      _selectInputSourceById(_englishInputSourceId, includeUnenabled: false);

  /// Whether the selected layout types English.
  ///
  /// Asks the input source which languages it types rather than matching its
  /// identifier, so Dvorak, Colemak, British, Australian and Canadian all
  /// answer true where 2.x answered false. See [isEnglishInputSource].
  ///
  /// Returns false when the current input source cannot be read.
  bool isEnglishKeyboard() => readEnglishStateOrNull() ?? false;

  /// The English state for the input-source stream to read, or null while there
  /// is no readable current input source.
  ///
  /// Distinct from [isEnglishKeyboard], which collapses "unreadable" to false
  /// for fidelity with 2.x. That collapse is wrong for a change stream: an
  /// unreadable moment would be announced as a switch to a non-English
  /// keyboard, and then announced again on the way back. The same split exists
  /// on the Windows side for the same reason.
  bool? readEnglishStateOrNull() => _withCurrentInputSource(
      (source) => isEnglishInputSource(_readLanguages(source)));

  /// Whether Caps Lock is currently on.
  ///
  /// Reads hardware modifier state, so it needs no window and no focus. See
  /// [CoreGraphics.eventSourceFlagsState] for why it also needs no permission,
  /// which is the point of it.
  bool isCapsLockOn() =>
      (_cg.eventSourceFlagsState(cgEventSourceStateHidSystemState) &
          cgEventFlagMaskAlphaShift) !=
      0;

  /// The selected input source's identifier, as an opaque token, or null when
  /// it cannot be read.
  ///
  /// The identifier *is* the token, exactly as in 2.x — `setInputSource` on
  /// this platform has nothing to parse. Consumers persist these, so a token
  /// saved before upgrading has to restore afterwards, and the only way to
  /// guarantee that is to keep producing the same bytes for the same keyboard.
  // The explicit type argument is load-bearing: without it T infers as String
  // from the return type, and _readSourceId — which can answer null — no longer
  // fits the callback.
  String? getCurrentInputSource() =>
      _withCurrentInputSource<String?>(_readSourceId);

  /// Restores the input source named by [sourceId], enabling it first if the
  /// user has it installed but switched off.
  ///
  /// Returns false when nothing installed carries that identifier — the usual
  /// reason being that the user removed the input source since the token was
  /// saved. That is an expected outcome of restoring rather than an
  /// exceptional one, so it is reported rather than thrown, and nothing is
  /// changed on the way to reporting it: the keyboard the user is on stays
  /// selected.
  ///
  /// Unlike the Windows token, there is nothing here to validate before
  /// calling the OS. Any string is a syntactically valid identifier, so a
  /// meaningless one is indistinguishable from an uninstalled one until the
  /// system is asked, and both answer false.
  ///
  /// **Differs from 2.x**, which searched only the sources showing in the input
  /// menu. It called `TISEnableInputSource` before selecting, but nothing it
  /// could find was ever switched off, so that call could not do anything — the
  /// documented behaviour was unreachable. Searching everything installed is
  /// what makes "enabled before selection" real rather than nominal.
  ///
  /// The cost of that widening is worth stating: [sourceId] is whatever a
  /// caller passes, so an identifier naming a keyboard the user has never
  /// enabled will be added to their input menu. Restoring a token this package
  /// produced can only ever hand back a keyboard that was theirs, but nothing
  /// enforces that a token came from here.
  bool setInputSource(String sourceId) =>
      _selectInputSourceById(sourceId, includeUnenabled: true);

  /// The selected input source's identifier and languages, for diagnostics.
  ///
  /// Returns a string rather than a structured value because it crosses the
  /// conditional-import boundary into the example app, where the web stub
  /// cannot name a type that depends on `dart:ffi`. Intended for confirming by
  /// eye that a non-QWERTY English layout classifies correctly.
  String? describeCurrentInputSource() => _withCurrentInputSource(
      (source) => '${_readSourceId(source) ?? '(no id)'}  '
          'languages: ${_readLanguages(source)}');

  /// The live registration with the distributed notification centre, or null
  /// while nothing is listening.
  ///
  /// Holding the callable is not optional bookkeeping. A `NativeCallable` keeps
  /// its isolate alive until closed, so dropping this reference without
  /// closing it leaks the callable *and* pins the isolate.
  NativeCallable<CFNotificationCallbackNative>? _inputSourceObserver;

  /// Starts telling [onChanged] that the keyboard may have moved.
  ///
  /// Push, not polling. macOS posts a distributed notification on every
  /// input-source change, and a notification callback returns nothing — which
  /// is precisely what a listener-style native callable can be. The Windows
  /// blocker was never that FFI cannot take callbacks; it was that a window
  /// procedure has to return a value synchronously. No return value, no
  /// problem.
  ///
  /// **[onChanged] fires more often than the keyboard changes.** macOS posts
  /// this notification twice for a single switch, and the callback carries no
  /// useful payload anyway, so it is a hint to re-read rather than an event.
  /// De-duplication belongs to whatever reads the value — see `ChangeStream`.
  ///
  /// Does nothing if already started, so the caller cannot register two
  /// observers for one stream.
  void startInputSourceNotifications(void Function() onChanged) {
    if (_inputSourceObserver != null) return;

    // A listener callable, not an isolate-local one: the notification arrives
    // on whichever thread the run loop delivers it on, and only the listener
    // kind may be invoked from a thread that is not the isolate's.
    final callable = NativeCallable<CFNotificationCallbackNative>.listener(
      (CFRef _, CFRef __, CFRef ___, CFRef ____, CFRef _____) => onChanged(),
    );

    // Register before storing. A failed registration must leave nothing
    // behind: an unclosed callable pins the isolate alive for the rest of the
    // process, and storing it first would hand back a handle to an observer
    // that was never registered.
    try {
      _cf.notificationCenterAddObserver(
        _cf.notificationCenterGetDistributedCenter(),
        // The observer token is compared by pointer identity when removing and
        // never dereferenced, so the callable's own address serves — unique per
        // registration and alive for exactly as long as the registration is.
        callable.nativeFunction.cast(),
        callable.nativeFunction,
        _tis.notifySelectedKeyboardInputSourceChanged,
        nullptr,
        cfNotificationSuspensionBehaviorDeliverImmediately,
      );
    } catch (_) {
      callable.close();
      rethrow;
    }
    _inputSourceObserver = callable;
  }

  /// Unregisters the observer and closes the callable. Safe to call when
  /// nothing was started.
  ///
  /// Order matters: remove first, then close. Closing a callable that the
  /// notification centre could still invoke would be a call through freed
  /// memory.
  void stopInputSourceNotifications() {
    final callable = _inputSourceObserver;
    if (callable == null) return;
    _inputSourceObserver = null;

    // The close has to happen even if the removal throws, or the handle is
    // gone and the callable can never be closed by anyone. Closing a callable
    // the centre might still invoke is the worse of the two failures, which is
    // why the removal goes first and only its *failure* is tolerated.
    try {
      _cf.notificationCenterRemoveObserver(
        _cf.notificationCenterGetDistributedCenter(),
        callable.nativeFunction.cast(),
        _tis.notifySelectedKeyboardInputSourceChanged,
        nullptr,
      );
    } finally {
      callable.close();
    }
  }

  /// Runs [body] against the selected keyboard input source, releasing it on
  /// every exit path. Returns null when there is no current input source to
  /// read.
  ///
  /// `TISCopyCurrentKeyboardInputSource` is a **copy**, so the result is ours
  /// to release.
  T? _withCurrentInputSource<T>(T Function(CFRef source) body) {
    final source = _tis.copyCurrentKeyboardInputSource();
    if (source == nullptr) return null;
    try {
      return body(source);
    } finally {
      _cf.release(source);
    }
  }

  /// An input source's identifier, or null if it declares none.
  ///
  /// `TISGetInputSourceProperty` is a **get**: the string belongs to the input
  /// source and is not released here.
  String? _readSourceId(CFRef source) => _readString(
      _tis.getInputSourceProperty(source, _tis.propertyInputSourceId));

  /// The languages an input source types, most significant first, or an empty
  /// list when it declares none.
  ///
  /// `TISGetInputSourceProperty` is a **get**: the array belongs to the input
  /// source and is not released here.
  List<String> _readLanguages(CFRef source) {
    final languages =
        _tis.getInputSourceProperty(source, _tis.propertyInputSourceLanguages);
    if (languages == nullptr) return const [];
    // A property key that stopped naming an array would make CFArrayGetCount
    // read a foreign object and take the whole app down with it. Cheaper to
    // ask.
    if (_cf.getTypeId(languages) != _cf.arrayTypeId()) return const [];

    final count = _cf.arrayGetCount(languages);
    final tags = <String>[];
    for (var i = 0; i < count; i++) {
      // CFArrayGetValueAtIndex is a get; the elements belong to the array.
      final tag = _readString(_cf.arrayGetValueAtIndex(languages, i));
      if (tag != null) tags.add(tag);
    }
    return tags;
  }

  /// Reads a `CFStringRef` as a Dart string, or null if it is absent, not a
  /// string, or cannot be encoded as UTF-8.
  ///
  /// Does not release [ref]: every string this file reads comes from a get-style
  /// call, and releasing one would over-release an object we never owned.
  String? _readString(CFRef ref) {
    if (ref == nullptr) return null;
    if (_cf.getTypeId(ref) != _cf.stringTypeId()) return null;

    // Maximum size, not length: a UTF-16 length says nothing about how many
    // UTF-8 bytes it takes. The extra byte is the terminator.
    final size = _cf.stringGetMaximumSizeForEncoding(
            _cf.stringGetLength(ref), cfStringEncodingUtf8) +
        1;
    final buffer = calloc<Uint8>(size);
    try {
      final ok = _cf.stringGetCString(
          ref, buffer.cast<Utf8>(), size, cfStringEncodingUtf8);
      if (ok == 0) return null;
      return buffer.cast<Utf8>().toDartString();
    } finally {
      calloc.free(buffer);
    }
  }

  /// Selects the input source whose identifier is [id].
  ///
  /// [includeUnenabled] widens the search from the sources showing in the
  /// user's input menu to everything installed on the machine. It is the whole
  /// difference between the two callers, and it is a policy decision rather
  /// than a mechanical one — see [setEnglishKeyboard] and [setInputSource].
  ///
  /// Returns false when nothing matches or the selection is refused.
  ///
  /// An identifier that matches nothing changes nothing: the search runs before
  /// anything that mutates, so it never reaches the enable or the select. A
  /// match that is then *refused* by [TextInputSources.selectInputSource] is
  /// the one case that leaves a trace — the enable has already run, so a source
  /// that was switched off is now switched on but not selected. That is not
  /// rolled back: the pre-restore state would have to be read first, the
  /// rollback can fail on its own, and leaving a keyboard enabled is a far
  /// smaller surprise than the alternative failure modes of undoing it.
  bool _selectInputSourceById(String id, {required bool includeUnenabled}) {
    final wanted = _newString(id);
    if (wanted == nullptr) return false;

    final filter = _newFilter(_tis.propertyInputSourceId, wanted);
    // The dictionary retains its key and value, so this reference has done its
    // job either way.
    _cf.release(wanted);
    if (filter == nullptr) return false;

    final matches = _tis.createInputSourceList(
        filter, includeUnenabled ? tisAllInstalled : tisEnabledOnly);
    _cf.release(filter);
    if (matches == nullptr) return false;

    try {
      if (_cf.arrayGetCount(matches) == 0) return false;
      // A get: the source belongs to the array.
      final source = _cf.arrayGetValueAtIndex(matches, 0);
      // Enable before select. A source that is installed but switched off is
      // refused by TISSelectInputSource, and it is exactly what a restore can
      // land on: the user can have turned the keyboard off in System Settings
      // between saving the token and restoring it. Enabling one already enabled
      // is a no-op, which is why the narrow caller can share this path.
      _tis.enableInputSource(source);
      return _tis.selectInputSource(source) == noErr;
    } finally {
      _cf.release(matches);
    }
  }

  /// Creates a `CFStringRef` from [value]. **The caller owns the result.**
  CFRef _newString(String value) {
    final utf8 = value.toNativeUtf8(allocator: calloc);
    try {
      return _cf.stringCreateWithCString(
          cfAllocatorDefault, utf8, cfStringEncodingUtf8);
    } finally {
      calloc.free(utf8);
    }
  }

  /// Creates a single-entry `CFDictionaryRef` to filter input sources with.
  /// **The caller owns the result.**
  CFRef _newFilter(CFRef key, CFRef value) {
    // One allocation for both arrays. Two would leave a window where the second
    // one throwing leaks the first.
    final slots = calloc<CFRef>(2);
    try {
      slots[0] = key;
      slots[1] = value;
      return _cf.dictionaryCreate(
        cfAllocatorDefault,
        slots,
        slots + 1,
        1,
        // Type callbacks, so the dictionary retains what it is given and
        // releases it when it goes.
        _cf.typeDictionaryKeyCallBacks,
        _cf.typeDictionaryValueCallBacks,
      );
    } finally {
      calloc.free(slots);
    }
  }
}
