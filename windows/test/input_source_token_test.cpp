#include "input_source_token.h"

#include <gtest/gtest.h>

namespace flutter_ime {
namespace {

// A bare KLID token carries no conversion state.
TEST(ParseInputSourceToken, BareKlidHasNoConversion) {
  InputSourceToken token;
  ASSERT_TRUE(ParseInputSourceToken("00000412", token));
  EXPECT_EQ(token.klid, "00000412");
  EXPECT_FALSE(token.has_conversion);
}

// A well-formed token decodes every part. Expected values are chosen here
// independently of the parser, not recomputed from it.
TEST(ParseInputSourceToken, WellFormedTokenDecodesAllParts) {
  InputSourceToken token;
  ASSERT_TRUE(ParseInputSourceToken("00000409:2:1", token));
  EXPECT_EQ(token.klid, "00000409");
  EXPECT_TRUE(token.has_conversion);
  EXPECT_EQ(token.conversion, 2u);
  EXPECT_EQ(token.sentence, 1u);
}

// A trailing colon with no second segment is a KLID-only token.
TEST(ParseInputSourceToken, KlidWithTrailingColonHasNoConversion) {
  InputSourceToken token;
  ASSERT_TRUE(ParseInputSourceToken("00000412:", token));
  EXPECT_EQ(token.klid, "00000412");
  EXPECT_FALSE(token.has_conversion);
}

TEST(ParseInputSourceToken, EmptyStringIsRejected) {
  InputSourceToken token;
  EXPECT_FALSE(ParseInputSourceToken("", token));
}

// Issue #3: a non-numeric conversion segment must be rejected, not sent to
// std::stoul (which would throw and crash the app). The test process surviving
// and the call returning false together prove no exception escaped.
TEST(ParseInputSourceToken, NonNumericConversionIsRejectedNotThrown) {
  InputSourceToken token;
  EXPECT_FALSE(ParseInputSourceToken("00000412:abc:0", token));
}

TEST(ParseInputSourceToken, NonNumericSentenceIsRejected) {
  InputSourceToken token;
  EXPECT_FALSE(ParseInputSourceToken("00000412:1:xyz", token));
}

// "1x" would make std::stoul stop early and silently succeed; the full-consume
// check rejects the trailing garbage.
TEST(ParseInputSourceToken, TrailingGarbageInSegmentIsRejected) {
  InputSourceToken token;
  EXPECT_FALSE(ParseInputSourceToken("00000412:1x:0", token));
}

TEST(ParseInputSourceToken, EmptyConversionSegmentIsRejected) {
  InputSourceToken token;
  EXPECT_FALSE(ParseInputSourceToken("00000412::0", token));
}

// Issue #3: an out-of-range number makes std::stoul throw std::out_of_range;
// it must be caught and reported as a rejection.
TEST(ParseInputSourceToken, OutOfRangeNumberIsRejectedNotThrown) {
  InputSourceToken token;
  EXPECT_FALSE(ParseInputSourceToken("00000412:99999999999999:0", token));
}

// Formatting is the inverse of parsing: klid + conversion + sentence joined by
// colons. Expected string is a hand-written literal, not recomputed.
TEST(FormatInputSourceToken, JoinsPartsWithColons) {
  EXPECT_EQ(FormatInputSourceToken("00000412", 1, 0), "00000412:1:0");
}

// Formatting then parsing recovers the original parts (inverse relationship).
TEST(FormatInputSourceToken, RoundTripsThroughParser) {
  const std::string formatted = FormatInputSourceToken("00000409", 2, 1);
  InputSourceToken token;
  ASSERT_TRUE(ParseInputSourceToken(formatted, token));
  EXPECT_EQ(token.klid, "00000409");
  EXPECT_TRUE(token.has_conversion);
  EXPECT_EQ(token.conversion, 2u);
  EXPECT_EQ(token.sentence, 1u);
}

}  // namespace
}  // namespace flutter_ime
