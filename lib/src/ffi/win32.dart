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
}
