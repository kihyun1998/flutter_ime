/// Pure encoding and decoding of the Windows input-source token.
///
/// The token is `KLID` or `KLID:conversion:sentence` — a keyboard layout
/// identifier optionally paired with the IME conversion and sentence modes.
/// It is **opaque to callers**: `getCurrentInputSource` hands it out and
/// `setInputSource` takes it back, and this file is the only place that looks
/// inside it.
///
/// The format is a hard compatibility requirement rather than an internal
/// detail. Consumers persist these tokens, so one written by 2.x must still be
/// accepted here.
///
/// Kept free of `dart:ffi` so it can be unit-tested on any platform, and so
/// the FFI layer stays a thin adapter with no branching logic of its own.
library;

/// Largest value either numeric segment can hold.
///
/// The C++ implementation got this bound for free: `std::stoul` threw
/// `out_of_range` because `unsigned long` is 32 bits on MSVC. Dart's `int` is
/// 64 bits, so the same input parses happily and the bound has to be checked.
const int _maxUint32 = 0xFFFFFFFF;

/// The decoded parts of an input-source token.
///
/// The two constructors make the invariant structural: conversion state is
/// either fully present or fully absent, never half-restored.
class InputSourceToken {
  /// A token that names only a keyboard layout.
  const InputSourceToken.layoutOnly(this.klid)
      : conversion = null,
        sentence = null;

  /// A token that also carries IME conversion state.
  const InputSourceToken.withConversion(
      this.klid, int this.conversion, int this.sentence);

  /// The keyboard layout identifier, e.g. `00000412` for Korean.
  final String klid;

  /// IME conversion mode, or null when the token carries no conversion state.
  final int? conversion;

  /// IME sentence mode, or null when the token carries no conversion state.
  final int? sentence;

  /// Whether there is conversion state to restore.
  bool get hasConversion => conversion != null;

  @override
  String toString() => hasConversion
      ? 'InputSourceToken($klid, conversion: $conversion, sentence: $sentence)'
      : 'InputSourceToken($klid, layout only)';
}

/// Parses [source] into its parts, returning null for anything malformed.
///
/// Never throws. That is the whole point: this runs on tokens that came back
/// from a consumer's storage, and 2.1.4 fixed a crash where a malformed one
/// reached `std::stoul` and threw across the method-channel boundary.
///
/// Accepts a bare `KLID`, a `KLID:` with no further segments, and a
/// well-formed `KLID:conversion:sentence`. Rejects an empty token, an empty
/// layout id, and any numeric segment that is not a plain unsigned 32-bit
/// number.
InputSourceToken? parseInputSourceToken(String source) {
  if (source.isEmpty) return null;

  final firstColon = source.indexOf(':');
  if (firstColon < 0) return InputSourceToken.layoutOnly(source);

  final klid = source.substring(0, firstColon);
  // An empty layout id names no keyboard. The C++ parser accepted it and let
  // LoadKeyboardLayout fail later; rejecting here is observably identical and
  // fails where the problem actually is.
  if (klid.isEmpty) return null;

  final secondColon = source.indexOf(':', firstColon + 1);
  // Without a second segment there is no complete conversion state, so restore
  // the layout alone rather than half of it.
  if (secondColon < 0) return InputSourceToken.layoutOnly(klid);

  final conversion =
      _parseUint32(source.substring(firstColon + 1, secondColon));
  final sentence = _parseUint32(source.substring(secondColon + 1));
  if (conversion == null || sentence == null) return null;

  return InputSourceToken.withConversion(klid, conversion, sentence);
}

/// Joins the parts back into a token. The inverse of [parseInputSourceToken].
String formatInputSourceToken(String klid, int conversion, int sentence) =>
    '$klid:$conversion:$sentence';

/// Parses one segment as an unsigned 32-bit number, or null.
///
/// Stricter than the C++ original in two ways that no token 2.x produces can
/// run into: `std::stoul` skipped leading whitespace and wrapped negative
/// values silently, and both are rejected here.
int? _parseUint32(String text) {
  if (text.isEmpty) return null;
  // `int.tryParse` accepts a leading sign; conversion modes are unsigned.
  if (!_isAllDigits(text)) return null;

  final value = int.tryParse(text);
  if (value == null || value > _maxUint32) return null;
  return value;
}

bool _isAllDigits(String text) {
  const zero = 0x30;
  const nine = 0x39;
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code < zero || code > nine) return false;
  }
  return true;
}
