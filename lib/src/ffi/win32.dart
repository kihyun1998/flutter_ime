/// Raw Win32 bindings used by the FFI implementation.
///
/// This file is deliberately mechanical: one Dart function per system call,
/// no decisions. Anything that needs a decision belongs in a pure function
/// elsewhere, where it can be tested without an operating system.
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Opaque Win32 handle. `HWND`, `HIMC` and friends are all pointer-sized
/// values whose contents are never inspected.
typedef Handle32 = Pointer<Void>;

// ---------------------------------------------------------------------------
// imm32.dll — IME context and conversion status
// ---------------------------------------------------------------------------

typedef _ImmGetContextNative = Handle32 Function(Handle32);
typedef _ImmReleaseContextNative = Int32 Function(Handle32, Handle32);
typedef _ImmReleaseContextDart = int Function(Handle32, Handle32);
typedef _ImmGetConversionStatusNative = Int32 Function(
    Handle32, Pointer<Uint32>, Pointer<Uint32>);
typedef _ImmGetConversionStatusDart = int Function(
    Handle32, Pointer<Uint32>, Pointer<Uint32>);
typedef _ImmSetConversionStatusNative = Int32 Function(
    Handle32, Uint32, Uint32);
typedef _ImmSetConversionStatusDart = int Function(Handle32, int, int);

/// `IACE_DEFAULT` — restore the window's default IME context.
///
/// Detaching uses no flag at all: a null context with no flags is what removes
/// the association, which is how the IME gets disabled.
const int iaceDefault = 0x0010;

typedef _ImmAssociateContextExNative = Int32 Function(
    Handle32, Handle32, Uint32);
typedef _ImmAssociateContextExDart = int Function(Handle32, Handle32, int);

// ---------------------------------------------------------------------------
// user32.dll / kernel32.dll — window lookup
// ---------------------------------------------------------------------------

typedef _FindWindowExNative = Handle32 Function(
    Handle32, Handle32, Pointer<Utf16>, Pointer<Utf16>);
typedef _GetWindowThreadProcessIdNative = Uint32 Function(
    Handle32, Pointer<Uint32>);
typedef _GetWindowThreadProcessIdDart = int Function(Handle32, Pointer<Uint32>);
typedef _GetForegroundWindowNative = Handle32 Function();
typedef _IsWindowNative = Int32 Function(Handle32);
typedef _IsWindowDart = int Function(Handle32);
typedef _GetCurrentProcessIdNative = Uint32 Function();
typedef _GetCurrentProcessIdDart = int Function();

// ---------------------------------------------------------------------------
// user32.dll — key state
// ---------------------------------------------------------------------------

/// `VK_CAPITAL` — the Caps Lock virtual key.
const int vkCapital = 0x14;

/// Mask for the toggle bit of a `GetKeyState` result. The high bit says whether
/// the key is held down right now; this low bit says whether the toggle is on,
/// which is the part that matters for Caps Lock.
const int keyStateToggledMask = 0x0001;

typedef _GetKeyStateNative = Int16 Function(Int32);
typedef _GetKeyStateDart = int Function(int);

// ---------------------------------------------------------------------------
// user32.dll — keyboard layout
// ---------------------------------------------------------------------------

/// Buffer size `GetKeyboardLayoutName` requires, in bytes: eight hex digits
/// plus the terminator.
const int klNameLength = 9;

/// `KLF_ACTIVATE` — make the loaded layout the active one.
const int klfActivate = 0x00000001;

// The ANSI variants are deliberate. A layout identifier is always eight ASCII
// hex digits, and matching what the native plugin called keeps the token bytes
// identical to the ones 2.x produced.
typedef _GetKeyboardLayoutNameNative = Int32 Function(Pointer<Utf8>);
typedef _GetKeyboardLayoutNameDart = int Function(Pointer<Utf8>);
typedef _LoadKeyboardLayoutNative = Handle32 Function(Pointer<Utf8>, Uint32);
typedef _LoadKeyboardLayoutDart = Handle32 Function(Pointer<Utf8>, int);

/// Lazily opened bindings to the Windows system libraries.
///
/// Opening is deferred to first use so that merely constructing the FFI
/// platform implementation on a non-Windows host does not try to load
/// `imm32.dll`.
class Win32 {
  Win32._();

  static Win32? _instance;

  /// The process-wide bindings, opened on first access.
  static Win32 get instance => _instance ??= Win32._();

  late final DynamicLibrary _imm32 = DynamicLibrary.open('imm32.dll');
  late final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
  late final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');

  late final immGetContext =
      _imm32.lookupFunction<_ImmGetContextNative, _ImmGetContextNative>(
          'ImmGetContext');

  late final immReleaseContext =
      _imm32.lookupFunction<_ImmReleaseContextNative, _ImmReleaseContextDart>(
          'ImmReleaseContext');

  late final immGetConversionStatus = _imm32.lookupFunction<
      _ImmGetConversionStatusNative,
      _ImmGetConversionStatusDart>('ImmGetConversionStatus');

  late final immSetConversionStatus = _imm32.lookupFunction<
      _ImmSetConversionStatusNative,
      _ImmSetConversionStatusDart>('ImmSetConversionStatus');

  late final immAssociateContextEx = _imm32.lookupFunction<
      _ImmAssociateContextExNative,
      _ImmAssociateContextExDart>('ImmAssociateContextEx');

  late final findWindowEx =
      _user32.lookupFunction<_FindWindowExNative, _FindWindowExNative>(
          'FindWindowExW');

  late final getWindowThreadProcessId = _user32.lookupFunction<
      _GetWindowThreadProcessIdNative,
      _GetWindowThreadProcessIdDart>('GetWindowThreadProcessId');

  late final getForegroundWindow = _user32.lookupFunction<
      _GetForegroundWindowNative,
      _GetForegroundWindowNative>('GetForegroundWindow');

  late final isWindow =
      _user32.lookupFunction<_IsWindowNative, _IsWindowDart>('IsWindow');

  late final getCurrentProcessId = _kernel32.lookupFunction<
      _GetCurrentProcessIdNative,
      _GetCurrentProcessIdDart>('GetCurrentProcessId');

  late final getKeyboardLayoutName = _user32.lookupFunction<
      _GetKeyboardLayoutNameNative,
      _GetKeyboardLayoutNameDart>('GetKeyboardLayoutNameA');

  late final loadKeyboardLayout = _user32.lookupFunction<
      _LoadKeyboardLayoutNative,
      _LoadKeyboardLayoutDart>('LoadKeyboardLayoutA');

  late final getKeyState = _user32
      .lookupFunction<_GetKeyStateNative, _GetKeyStateDart>('GetKeyState');
}
