#include "method_dispatch.h"

#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "caps_lock_manager.h"
#include "input_source_manager.h"

namespace flutter_ime {
namespace test {
namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

// Captures the observable outcome of a dispatch: success (with value), error
// (with code), or not-implemented.
struct CallOutcome {
  bool succeeded = false;
  bool errored = false;
  bool not_implemented = false;
  std::string error_code;
  EncodableValue value;
};

// Drives HandleImeMethodCall with fresh managers. The input-source manager gets
// a null-HWND provider, so IME operations that need a window fail cleanly
// instead of touching a real one.
CallOutcome Invoke(const std::string& method,
                   std::unique_ptr<EncodableValue> arguments) {
  InputSourceManager input_source([]() -> HWND { return nullptr; });
  CapsLockManager caps_lock;

  CallOutcome outcome;
  auto result = std::make_unique<MethodResultFunctions<EncodableValue>>(
      [&outcome](const EncodableValue* value) {
        outcome.succeeded = true;
        if (value) outcome.value = *value;
      },
      [&outcome](const std::string& code, const std::string& /*message*/,
                 const EncodableValue* /*details*/) {
        outcome.errored = true;
        outcome.error_code = code;
      },
      [&outcome]() { outcome.not_implemented = true; });

  HandleImeMethodCall(input_source, caps_lock,
                      MethodCall<EncodableValue>(method, std::move(arguments)),
                      std::move(result));
  return outcome;
}

}  // namespace

TEST(HandleImeMethodCall, UnknownMethodIsNotImplemented) {
  auto outcome = Invoke("totallyUnknownMethod",
                        std::make_unique<EncodableValue>());
  EXPECT_TRUE(outcome.not_implemented);
  EXPECT_FALSE(outcome.succeeded);
  EXPECT_FALSE(outcome.errored);
}

TEST(HandleImeMethodCall, SetInputSourceWithNonMapArgsIsInvalidArgument) {
  auto outcome = Invoke("setInputSource",
                        std::make_unique<EncodableValue>("not a map"));
  EXPECT_TRUE(outcome.errored);
  EXPECT_EQ(outcome.error_code, "INVALID_ARGUMENT");
}

TEST(HandleImeMethodCall, SetInputSourceWithMissingSourceIdIsInvalidArgument) {
  auto outcome = Invoke("setInputSource",
                        std::make_unique<EncodableValue>(EncodableMap{}));
  EXPECT_TRUE(outcome.errored);
  EXPECT_EQ(outcome.error_code, "INVALID_ARGUMENT");
}

TEST(HandleImeMethodCall, SetInputSourceWithNonStringSourceIdIsInvalidArgument) {
  auto outcome = Invoke(
      "setInputSource",
      std::make_unique<EncodableValue>(
          EncodableMap{{EncodableValue("sourceId"), EncodableValue(42)}}));
  EXPECT_TRUE(outcome.errored);
  EXPECT_EQ(outcome.error_code, "INVALID_ARGUMENT");
}

// A success path that works without a window: caps lock is read via GetKeyState.
TEST(HandleImeMethodCall, IsCapsLockOnSucceedsWithBool) {
  auto outcome = Invoke("isCapsLockOn", std::make_unique<EncodableValue>());
  EXPECT_TRUE(outcome.succeeded);
  EXPECT_FALSE(outcome.errored);
  EXPECT_TRUE(std::holds_alternative<bool>(outcome.value));
}

// An error path: with a null-HWND provider, setting the English keyboard fails
// and is reported as IME_ERROR (not a crash, not not-implemented).
TEST(HandleImeMethodCall, SetEnglishKeyboardWithoutWindowIsImeError) {
  auto outcome =
      Invoke("setEnglishKeyboard", std::make_unique<EncodableValue>());
  EXPECT_TRUE(outcome.errored);
  EXPECT_EQ(outcome.error_code, "IME_ERROR");
}

}  // namespace test
}  // namespace flutter_ime
