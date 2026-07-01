#include "ime_message_filter.h"

#include <gtest/gtest.h>

namespace flutter_ime {
namespace {

TEST(ShouldBlockImeMessage, BlocksImeComposition) {
  EXPECT_TRUE(ShouldBlockImeMessage(WM_IME_COMPOSITION, 0));
}

TEST(ShouldBlockImeMessage, BlocksAllImeMessages) {
  EXPECT_TRUE(ShouldBlockImeMessage(WM_IME_STARTCOMPOSITION, 0));
  EXPECT_TRUE(ShouldBlockImeMessage(WM_IME_ENDCOMPOSITION, 0));
  EXPECT_TRUE(ShouldBlockImeMessage(WM_IME_NOTIFY, 0));
  EXPECT_TRUE(ShouldBlockImeMessage(WM_IME_SETCONTEXT, 0));
  EXPECT_TRUE(ShouldBlockImeMessage(WM_IME_CHAR, 0));
}

// WM_CHAR is blocked only for Korean characters. Boundary values come from the
// Unicode ranges (Hangul syllables 0xAC00-0xD7A3, Jamo 0x3131-0x3163), not from
// the implementation.
TEST(ShouldBlockImeMessage, BlocksWmCharAtHangulSyllableBoundaries) {
  EXPECT_TRUE(ShouldBlockImeMessage(WM_CHAR, 0xAC00));   // first
  EXPECT_TRUE(ShouldBlockImeMessage(WM_CHAR, 0xD7A3));   // last
  EXPECT_FALSE(ShouldBlockImeMessage(WM_CHAR, 0xABFF));  // just below
  EXPECT_FALSE(ShouldBlockImeMessage(WM_CHAR, 0xD7A4));  // just above
}

TEST(ShouldBlockImeMessage, BlocksWmCharAtJamoBoundaries) {
  EXPECT_TRUE(ShouldBlockImeMessage(WM_CHAR, 0x3131));   // first
  EXPECT_TRUE(ShouldBlockImeMessage(WM_CHAR, 0x3163));   // last
  EXPECT_FALSE(ShouldBlockImeMessage(WM_CHAR, 0x3130));  // just below
  EXPECT_FALSE(ShouldBlockImeMessage(WM_CHAR, 0x3164));  // just above
}

TEST(ShouldBlockImeMessage, AllowsLatinWmChar) {
  EXPECT_FALSE(ShouldBlockImeMessage(WM_CHAR, 'A'));
}

TEST(ShouldBlockImeMessage, AllowsNonImeMessages) {
  EXPECT_FALSE(ShouldBlockImeMessage(WM_KEYDOWN, 0));
  EXPECT_FALSE(ShouldBlockImeMessage(WM_CHAR, 'a'));
  EXPECT_FALSE(ShouldBlockImeMessage(WM_PAINT, 0));
}

}  // namespace
}  // namespace flutter_ime
