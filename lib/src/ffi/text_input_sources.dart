/// Raw Text Input Source Services bindings used by the macOS FFI
/// implementation.
///
/// Deliberately mechanical, like `win32.dart`: one Dart function per system
/// call and no decisions.
library;

import 'dart:ffi';

import 'core_foundation.dart';

/// `noErr` — the `OSStatus` value every one of these calls returns on success.
const int noErr = 0;

/// `includeAllInstalled: false` — list only the input sources showing in the
/// user's input menu.
const int tisEnabledOnly = 0;

/// `includeAllInstalled: true` — list every input source installed on the
/// machine, including ones the user has switched off.
///
/// Far wider than it sounds: a machine with five enabled sources can have three
/// hundred installed. Only worth asking for when an exact identifier is being
/// looked up.
const int tisAllInstalled = 1;

typedef _TISCopyCurrentKeyboardInputSourceNative = CFRef Function();

typedef _TISCreateInputSourceListNative = CFRef Function(CFRef, Uint8);
typedef _TISCreateInputSourceListDart = CFRef Function(CFRef, int);

typedef _TISGetInputSourcePropertyNative = CFRef Function(CFRef, CFRef);

typedef _TISInputSourceActionNative = Int32 Function(CFRef);
typedef _TISInputSourceActionDart = int Function(CFRef);

/// Lazily opened bindings to Text Input Source Services.
///
/// The functions live in HIToolbox, a subframework of Carbon. Carbon
/// re-exports it, so opening the umbrella framework is enough and avoids
/// naming a versioned path inside another framework's bundle.
///
/// Opening is deferred to first use so that merely constructing the FFI
/// platform implementation on a non-macOS host does not try to load the
/// framework.
class TextInputSources {
  TextInputSources._();

  static TextInputSources? _instance;

  /// The process-wide bindings, opened on first access.
  static TextInputSources get instance => _instance ??= TextInputSources._();

  late final DynamicLibrary _lib =
      DynamicLibrary.open('/System/Library/Frameworks/Carbon.framework/Carbon');

  /// The selected keyboard input source. **Copy semantics** — the caller owns
  /// the result and must release it.
  late final copyCurrentKeyboardInputSource = _lib.lookupFunction<
          _TISCopyCurrentKeyboardInputSourceNative,
          _TISCopyCurrentKeyboardInputSourceNative>(
      'TISCopyCurrentKeyboardInputSource');

  /// The input sources matching a property filter. **Create semantics** — the
  /// caller owns the returned array and must release it. The sources inside it
  /// belong to the array and must not be released.
  late final createInputSourceList = _lib.lookupFunction<
      _TISCreateInputSourceListNative,
      _TISCreateInputSourceListDart>('TISCreateInputSourceList');

  /// One property of an input source. **Get semantics** — the result is owned
  /// by the input source and must *not* be released.
  late final getInputSourceProperty = _lib.lookupFunction<
      _TISGetInputSourcePropertyNative,
      _TISGetInputSourcePropertyNative>('TISGetInputSourceProperty');

  late final enableInputSource = _lib.lookupFunction<
      _TISInputSourceActionNative,
      _TISInputSourceActionDart>('TISEnableInputSource');

  late final selectInputSource = _lib.lookupFunction<
      _TISInputSourceActionNative,
      _TISInputSourceActionDart>('TISSelectInputSource');

  /// `kTISPropertyInputSourceID` — the property key naming an input source's
  /// identifier, such as `com.apple.keylayout.Dvorak`.
  ///
  /// An exported **data symbol**, not a function: the symbol is a `CFStringRef`
  /// variable, so the lookup yields a pointer *to* the reference and has to be
  /// dereferenced once. Calling it, or passing the undereferenced pointer as
  /// the key, silently fails to match anything.
  late final CFRef propertyInputSourceId =
      _lib.lookup<CFRef>('kTISPropertyInputSourceID').value;

  /// `kTISPropertyInputSourceLanguages` — the property key for the languages an
  /// input source types, most significant first. See [propertyInputSourceId]
  /// for why this is dereferenced.
  late final CFRef propertyInputSourceLanguages =
      _lib.lookup<CFRef>('kTISPropertyInputSourceLanguages').value;

  /// `kTISNotifySelectedKeyboardInputSourceChanged` — the distributed
  /// notification macOS posts when the user switches keyboard.
  ///
  /// Another data symbol holding a `CFStringRef`, dereferenced for the same
  /// reason as [propertyInputSourceId]. Registering with the undereferenced
  /// pointer as the name subscribes to a notification nothing ever posts, which
  /// looks exactly like a system that simply never fires.
  late final CFRef notifySelectedKeyboardInputSourceChanged =
      _lib.lookup<CFRef>('kTISNotifySelectedKeyboardInputSourceChanged').value;
}
