/// Raw CoreFoundation bindings used by the macOS FFI implementation.
///
/// Deliberately mechanical, like `win32.dart`: one Dart function per system
/// call and no decisions. Marshalling between CoreFoundation and Dart values
/// lives in `macos_ime.dart`, where the release semantics can be seen next to
/// the calls that create the objects.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// An opaque CoreFoundation object reference — `CFTypeRef` and every `CF*Ref`
/// that specialises it.
typedef CFRef = Pointer<Void>;

/// `kCFStringEncodingUTF8`.
const int cfStringEncodingUtf8 = 0x08000100;

/// `kCFAllocatorDefault` is a null pointer, so it needs no symbol lookup.
final CFRef cfAllocatorDefault = nullptr;

typedef _CFStringCreateWithCStringNative = CFRef Function(
    CFRef, Pointer<Utf8>, Uint32);
typedef _CFStringCreateWithCStringDart = CFRef Function(
    CFRef, Pointer<Utf8>, int);

// CFIndex is a signed long — pointer-sized on every platform this runs on, so
// IntPtr is the right native type for every length, count and index below.
typedef _CFStringGetLengthNative = IntPtr Function(CFRef);
typedef _CFStringGetLengthDart = int Function(CFRef);

typedef _CFStringGetMaximumSizeForEncodingNative = IntPtr Function(
    IntPtr, Uint32);
typedef _CFStringGetMaximumSizeForEncodingDart = int Function(int, int);

typedef _CFStringGetCStringNative = Uint8 Function(
    CFRef, Pointer<Utf8>, IntPtr, Uint32);
typedef _CFStringGetCStringDart = int Function(CFRef, Pointer<Utf8>, int, int);

typedef _CFReleaseNative = Void Function(CFRef);
typedef _CFReleaseDart = void Function(CFRef);

typedef _CFArrayGetCountNative = IntPtr Function(CFRef);
typedef _CFArrayGetCountDart = int Function(CFRef);

typedef _CFArrayGetValueAtIndexNative = CFRef Function(CFRef, IntPtr);
typedef _CFArrayGetValueAtIndexDart = CFRef Function(CFRef, int);

typedef _CFGetTypeIDNative = UintPtr Function(CFRef);
typedef _CFGetTypeIDDart = int Function(CFRef);

typedef _CFTypeIDGetterNative = UintPtr Function();
typedef _CFTypeIDGetterDart = int Function();

typedef _CFDictionaryCreateNative = CFRef Function(
    CFRef, Pointer<CFRef>, Pointer<CFRef>, IntPtr, CFRef, CFRef);
typedef _CFDictionaryCreateDart = CFRef Function(
    CFRef, Pointer<CFRef>, Pointer<CFRef>, int, CFRef, CFRef);

// ---------------------------------------------------------------------------
// Distributed notifications
// ---------------------------------------------------------------------------

/// `CFNotificationSuspensionBehaviorDeliverImmediately` — deliver even while
/// the application is suspended, rather than coalescing or dropping.
///
/// An input-source change is a discrete event with no meaningful "latest
/// value", and the app being in the background is exactly when the user is off
/// changing their keyboard.
const int cfNotificationSuspensionBehaviorDeliverImmediately = 4;

/// The shape of a `CFNotificationCallback`: centre, observer, name, object,
/// userInfo.
typedef CFNotificationCallbackNative = Void Function(
    CFRef, CFRef, CFRef, CFRef, CFRef);

typedef _CFNotificationCenterGetDistributedCenterNative = CFRef Function();

typedef _CFNotificationCenterAddObserverNative = Void Function(
    CFRef,
    CFRef,
    Pointer<NativeFunction<CFNotificationCallbackNative>>,
    CFRef,
    CFRef,
    IntPtr);
typedef _CFNotificationCenterAddObserverDart = void Function(CFRef, CFRef,
    Pointer<NativeFunction<CFNotificationCallbackNative>>, CFRef, CFRef, int);

typedef _CFNotificationCenterRemoveObserverNative = Void Function(
    CFRef, CFRef, CFRef, CFRef);
typedef _CFNotificationCenterRemoveObserverDart = void Function(
    CFRef, CFRef, CFRef, CFRef);

/// Lazily opened bindings to CoreFoundation.
///
/// Opening is deferred to first use so that merely constructing the FFI
/// platform implementation on a non-macOS host does not try to load the
/// framework.
class CoreFoundation {
  CoreFoundation._();

  static CoreFoundation? _instance;

  /// The process-wide bindings, opened on first access.
  static CoreFoundation get instance => _instance ??= CoreFoundation._();

  late final DynamicLibrary _lib = DynamicLibrary.open(
      '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation');

  /// **Create semantics** — the caller owns the result and must release it.
  late final stringCreateWithCString = _lib.lookupFunction<
      _CFStringCreateWithCStringNative,
      _CFStringCreateWithCStringDart>('CFStringCreateWithCString');

  late final stringGetLength =
      _lib.lookupFunction<_CFStringGetLengthNative, _CFStringGetLengthDart>(
          'CFStringGetLength');

  late final stringGetMaximumSizeForEncoding = _lib.lookupFunction<
          _CFStringGetMaximumSizeForEncodingNative,
          _CFStringGetMaximumSizeForEncodingDart>(
      'CFStringGetMaximumSizeForEncoding');

  late final stringGetCString =
      _lib.lookupFunction<_CFStringGetCStringNative, _CFStringGetCStringDart>(
          'CFStringGetCString');

  late final release =
      _lib.lookupFunction<_CFReleaseNative, _CFReleaseDart>('CFRelease');

  late final arrayGetCount =
      _lib.lookupFunction<_CFArrayGetCountNative, _CFArrayGetCountDart>(
          'CFArrayGetCount');

  /// **Get semantics** — the element belongs to the array and must *not* be
  /// released.
  late final arrayGetValueAtIndex = _lib.lookupFunction<
      _CFArrayGetValueAtIndexNative,
      _CFArrayGetValueAtIndexDart>('CFArrayGetValueAtIndex');

  late final getTypeId =
      _lib.lookupFunction<_CFGetTypeIDNative, _CFGetTypeIDDart>('CFGetTypeID');

  late final arrayTypeId =
      _lib.lookupFunction<_CFTypeIDGetterNative, _CFTypeIDGetterDart>(
          'CFArrayGetTypeID');

  late final stringTypeId =
      _lib.lookupFunction<_CFTypeIDGetterNative, _CFTypeIDGetterDart>(
          'CFStringGetTypeID');

  /// **Create semantics** — the caller owns the result and must release it.
  /// With the type callbacks below, the dictionary retains its keys and values,
  /// so the caller's own references to those can go as soon as it returns.
  late final dictionaryCreate =
      _lib.lookupFunction<_CFDictionaryCreateNative, _CFDictionaryCreateDart>(
          'CFDictionaryCreate');

  /// The notification centre that carries messages between processes, which is
  /// where macOS announces an input-source change.
  ///
  /// **Get semantics** — a process-wide singleton, not ours to release.
  late final notificationCenterGetDistributedCenter = _lib.lookupFunction<
          _CFNotificationCenterGetDistributedCenterNative,
          _CFNotificationCenterGetDistributedCenterNative>(
      'CFNotificationCenterGetDistributedCenter');

  /// Registers [CFNotificationCallbackNative] for one notification name.
  ///
  /// The observer argument is an opaque token, not an object: it is compared by
  /// pointer identity when removing, and never dereferenced.
  late final notificationCenterAddObserver = _lib.lookupFunction<
      _CFNotificationCenterAddObserverNative,
      _CFNotificationCenterAddObserverDart>('CFNotificationCenterAddObserver');

  /// Unregisters what [notificationCenterAddObserver] registered, matched on
  /// the same observer token.
  late final notificationCenterRemoveObserver = _lib.lookupFunction<
          _CFNotificationCenterRemoveObserverNative,
          _CFNotificationCenterRemoveObserverDart>(
      'CFNotificationCenterRemoveObserver');

  /// `kCFTypeDictionaryKeyCallBacks` — the retain/release callbacks that make a
  /// dictionary own its keys.
  ///
  /// A data symbol, not a function, so it is looked up rather than called. It
  /// is a struct *instance*, so the symbol's address is already the struct and
  /// no dereference is needed — unlike the Text Input Source property names,
  /// which are pointer variables and must be dereferenced once.
  late final CFRef typeDictionaryKeyCallBacks =
      _lib.lookup<Void>('kCFTypeDictionaryKeyCallBacks');

  /// `kCFTypeDictionaryValueCallBacks`. See [typeDictionaryKeyCallBacks].
  late final CFRef typeDictionaryValueCallBacks =
      _lib.lookup<Void>('kCFTypeDictionaryValueCallBacks');
}
