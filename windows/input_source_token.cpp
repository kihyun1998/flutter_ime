#include "input_source_token.h"

#include <exception>
#include <sstream>

namespace flutter_ime {

namespace {

// Parses [text] as a 32-bit unsigned value without throwing. Returns false when
// the string is empty, has trailing non-numeric characters, or is out of range.
bool TryParseUint32(const std::string& text, uint32_t& out) {
  if (text.empty()) return false;
  try {
    size_t consumed = 0;
    unsigned long value = std::stoul(text, &consumed);
    if (consumed != text.size()) return false;  // trailing non-numeric
    if (value > 0xFFFFFFFFUL) return false;      // out of 32-bit range
    out = static_cast<uint32_t>(value);
    return true;
  } catch (const std::exception&) {
    // std::invalid_argument (not a number) or std::out_of_range.
    return false;
  }
}

}  // namespace

bool ParseInputSourceToken(const std::string& source_id, InputSourceToken& out) {
  if (source_id.empty()) return false;

  size_t first_colon = source_id.find(':');
  if (first_colon == std::string::npos) {
    // Bare KLID.
    out.klid = source_id;
    out.has_conversion = false;
    return true;
  }

  out.klid = source_id.substr(0, first_colon);

  size_t second_colon = source_id.find(':', first_colon + 1);
  if (second_colon == std::string::npos) {
    // "KLID:" with no second segment; no conversion state to restore.
    out.has_conversion = false;
    return true;
  }

  uint32_t conversion = 0;
  uint32_t sentence = 0;
  if (!TryParseUint32(source_id.substr(first_colon + 1, second_colon - first_colon - 1), conversion) ||
      !TryParseUint32(source_id.substr(second_colon + 1), sentence)) {
    // Malformed numeric segment: reject instead of letting std::stoul throw.
    return false;
  }

  out.conversion = conversion;
  out.sentence = sentence;
  out.has_conversion = true;
  return true;
}

std::string FormatInputSourceToken(const std::string& klid, uint32_t conversion,
                                   uint32_t sentence) {
  std::ostringstream oss;
  oss << klid << ":" << conversion << ":" << sentence;
  return oss.str();
}

}  // namespace flutter_ime
