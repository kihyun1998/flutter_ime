#ifndef FLUTTER_PLUGIN_METHOD_DISPATCH_H_
#define FLUTTER_PLUGIN_METHOD_DISPATCH_H_

#include <flutter/method_call.h>
#include <flutter/method_result.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "caps_lock_manager.h"
#include "input_source_manager.h"

namespace flutter_ime {

// Dispatches a method-channel call to the feature managers. Extracted from the
// plugin so it can be unit-tested without a PluginRegistrarWindows or a window.
void HandleImeMethodCall(
    InputSourceManager& input_source, CapsLockManager& caps_lock,
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

}  // namespace flutter_ime

#endif  // FLUTTER_PLUGIN_METHOD_DISPATCH_H_
