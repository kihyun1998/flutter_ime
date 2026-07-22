#include "method_dispatch.h"

#include <string>
#include <variant>

#include "ime_channel_constants.h"

namespace flutter_ime {

void HandleImeMethodCall(
    InputSourceManager& input_source, CapsLockManager& caps_lock,
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == methods::kSetEnglishKeyboard) {
    if (input_source.SetEnglishKeyboard()) {
      result->Success();
    } else {
      result->Error("IME_ERROR", "Failed to set English keyboard");
    }
  } else if (method == methods::kIsEnglishKeyboard) {
    result->Success(flutter::EncodableValue(input_source.IsEnglishKeyboard()));
  } else if (method == methods::kDisableIme) {
    if (input_source.DisableIME()) {
      result->Success();
    } else {
      result->Error("IME_ERROR", "Failed to disable IME");
    }
  } else if (method == methods::kEnableIme) {
    if (input_source.EnableIME()) {
      result->Success();
    } else {
      result->Error("IME_ERROR", "Failed to enable IME");
    }
  } else if (method == "debugSetMessageBlocking") {
    // SPIKE ONLY: flips the WndProc-blocking half of DisableIME() so the
    // example app can compare it against ImmAssociateContextEx alone.
    const auto* args =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    const bool* enabled = nullptr;
    if (args) {
      auto it = args->find(flutter::EncodableValue("enabled"));
      if (it != args->end()) {
        enabled = std::get_if<bool>(&it->second);
      }
    }
    if (enabled) {
      input_source.SetMessageBlockingEnabled(*enabled);
      result->Success();
    } else {
      result->Error("INVALID_ARGUMENT", "enabled (bool) is required");
    }
  } else if (method == methods::kIsCapsLockOn) {
    result->Success(flutter::EncodableValue(caps_lock.QueryAndSyncState()));
  } else if (method == methods::kGetCurrentInputSource) {
    std::string source = input_source.GetCurrentInputSource();
    if (!source.empty()) {
      result->Success(flutter::EncodableValue(source));
    } else {
      result->Success(flutter::EncodableValue());
    }
  } else if (method == methods::kSetInputSource) {
    const auto* args =
        std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      auto it = args->find(flutter::EncodableValue(arguments::kSourceId));
      if (it != args->end()) {
        const auto* sourceId = std::get_if<std::string>(&it->second);
        if (sourceId) {
          if (input_source.SetInputSource(*sourceId)) {
            result->Success();
          } else {
            result->Error("IME_ERROR", "Failed to set input source");
          }
        } else {
          result->Error("INVALID_ARGUMENT", "sourceId must be a string");
        }
      } else {
        result->Error("INVALID_ARGUMENT", "sourceId is required");
      }
    } else {
      result->Error("INVALID_ARGUMENT", "Arguments must be a map");
    }
  } else {
    result->NotImplemented();
  }
}

}  // namespace flutter_ime
