/// Opt-in entry point for the FFI-backed implementation.
///
/// The package still ships the native plugin, and that is still what you get by
/// default. Import this library and install the implementation to route calls
/// through `dart:ffi` instead:
///
/// ```dart
/// import 'package:flutter_ime/flutter_ime_ffi.dart';
/// import 'package:flutter_ime/flutter_ime_platform_interface.dart';
///
/// void main() {
///   if (Platform.isWindows || Platform.isMacOS) {
///     FlutterImePlatform.instance = FfiFlutterIme();
///   }
///   runApp(const MyApp());
/// }
/// ```
///
/// This library is transitional. When the migration completes, the FFI
/// implementation becomes the default and this opt-in disappears.
///
/// The conditional import keeps `dart:ffi` out of the library graph on web,
/// where importing it fails the build.
library;

export 'src/ffi/ffi_flutter_ime_stub.dart'
    if (dart.library.ffi) 'src/ffi/ffi_flutter_ime.dart';
