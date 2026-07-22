/// Raw CoreGraphics bindings used to read modifier-key state on macOS.
///
/// Deliberately mechanical, like `win32.dart`: one Dart function per system
/// call and no decisions.
library;

import 'dart:ffi';

/// `kCGEventSourceStateHIDSystemState` — the state of the hardware itself,
/// rather than of one process's event stream.
///
/// The hardware state is what makes this work with no window and no focus: it
/// is the same answer no matter which application the user is typing in.
const int cgEventSourceStateHidSystemState = 1;

/// `kCGEventFlagMaskAlphaShift` — the Caps Lock bit of a `CGEventFlags`.
const int cgEventFlagMaskAlphaShift = 0x00010000;

/// `kVK_CapsLock` — the virtual keycode of the Caps Lock key.
const int cgKeyCodeCapsLock = 0x39;

typedef _CGEventSourceFlagsStateNative = Uint64 Function(Int32);
typedef _CGEventSourceFlagsStateDart = int Function(int);

typedef _CGEventSourceKeyStateNative = Uint8 Function(Int32, Uint16);
typedef _CGEventSourceKeyStateDart = int Function(int, int);

/// Lazily opened bindings to CoreGraphics.
///
/// Opening is deferred to first use so that merely constructing the FFI
/// platform implementation on a non-macOS host does not try to load the
/// framework.
class CoreGraphics {
  CoreGraphics._();

  static CoreGraphics? _instance;

  /// The process-wide bindings, opened on first access.
  static CoreGraphics get instance => _instance ??= CoreGraphics._();

  late final DynamicLibrary _lib = DynamicLibrary.open(
      '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics');

  /// The modifier flags currently set for a given event source.
  ///
  /// **Needs no Accessibility permission**, which is the entire reason it is
  /// here. The native plugin registered a global monitor for modifier-flag
  /// events instead, and global monitoring of key-related events delivers
  /// nothing unless the process is trusted for Accessibility — a permission
  /// this package never requested and never documented, so for most consumers
  /// that monitor sat silent. This is a plain read of hardware state.
  late final eventSourceFlagsState = _lib.lookupFunction<
      _CGEventSourceFlagsStateNative,
      _CGEventSourceFlagsStateDart>('CGEventSourceFlagsState');

  /// Whether a key is physically held down right now.
  ///
  /// Needed because the Caps Lock *flag* is set while the key is held whether
  /// or not the press will end up latching anything — see [capsLockState].
  /// Needs no Accessibility permission either.
  late final eventSourceKeyState = _lib.lookupFunction<
      _CGEventSourceKeyStateNative,
      _CGEventSourceKeyStateDart>('CGEventSourceKeyState');
}
