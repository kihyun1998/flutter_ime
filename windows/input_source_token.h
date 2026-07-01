#ifndef FLUTTER_PLUGIN_INPUT_SOURCE_TOKEN_H_
#define FLUTTER_PLUGIN_INPUT_SOURCE_TOKEN_H_

#include <cstdint>
#include <string>

namespace flutter_ime {

// The decoded parts of an input-source token, which is either a bare "KLID" or
// "KLID:conversion:sentence". The token is opaque to Dart and parsed only here
// (see lib/flutter_ime.dart docs).
struct InputSourceToken {
  std::string klid;
  bool has_conversion = false;
  uint32_t conversion = 0;
  uint32_t sentence = 0;
};

// Parses [source_id] into [out] without ever throwing. Returns:
// - false for an empty input, or a malformed conversion/sentence segment
//   (non-numeric, trailing garbage, or out of 32-bit range);
// - true for a bare "KLID", a "KLID:" with no second segment (no conversion),
//   or a well-formed "KLID:conversion:sentence".
//
// This guards against std::stoul throwing across the method-channel boundary
// and crashing the host app.
bool ParseInputSourceToken(const std::string& source_id, InputSourceToken& out);

}  // namespace flutter_ime

#endif  // FLUTTER_PLUGIN_INPUT_SOURCE_TOKEN_H_
