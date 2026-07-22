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
import 'text_input_sources.dart';

class MacosIme {
  MacosIme({CoreFoundation? coreFoundation, TextInputSources? textInputSources})
      : _cf = coreFoundation ?? CoreFoundation.instance,
        _tis = textInputSources ?? TextInputSources.instance;

  final CoreFoundation _cf;
  final TextInputSources _tis;

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
  bool setEnglishKeyboard() => _selectInputSourceById(_englishInputSourceId);

  /// Whether the selected layout types English.
  ///
  /// Asks the input source which languages it types rather than matching its
  /// identifier, so Dvorak, Colemak, British, Australian and Canadian all
  /// answer true where 2.x answered false. See [isEnglishInputSource].
  ///
  /// Returns false when the current input source cannot be read.
  bool isEnglishKeyboard() =>
      _withCurrentInputSource(
          (source) => isEnglishInputSource(_readLanguages(source))) ??
      false;

  /// The selected input source's identifier and languages, for diagnostics.
  ///
  /// Returns a string rather than a structured value because it crosses the
  /// conditional-import boundary into the example app, where the web stub
  /// cannot name a type that depends on `dart:ffi`. Intended for confirming by
  /// eye that a non-QWERTY English layout classifies correctly.
  String? describeCurrentInputSource() => _withCurrentInputSource((source) {
        final id = _readString(_tis.getInputSourceProperty(
                source, _tis.propertyInputSourceId)) ??
            '(no id)';
        return '$id  languages: ${_readLanguages(source)}';
      });

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

  /// Selects the enabled input source whose identifier is [id].
  ///
  /// Returns false when no enabled input source matches, or when the selection
  /// is refused.
  bool _selectInputSourceById(String id) {
    final wanted = _newString(id);
    if (wanted == nullptr) return false;

    final filter = _newFilter(_tis.propertyInputSourceId, wanted);
    // The dictionary retains its key and value, so this reference has done its
    // job either way.
    _cf.release(wanted);
    if (filter == nullptr) return false;

    // False for includeAllInstalled: only sources the user has enabled. This
    // matches 2.x. Selecting a source the user never enabled would put a
    // keyboard in their menu bar that they did not ask for.
    final matches = _tis.createInputSourceList(filter, 0);
    _cf.release(filter);
    if (matches == nullptr) return false;

    try {
      if (_cf.arrayGetCount(matches) == 0) return false;
      // A get: the source belongs to the array.
      final source = _cf.arrayGetValueAtIndex(matches, 0);
      // Belt and braces, kept from 2.x: everything in this list is enabled
      // already, since the list was built with includeAllInstalled false, so
      // this is a no-op today. It costs one call and is what stands between us
      // and a silent failure if that filter ever widens.
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
