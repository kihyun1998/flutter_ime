#include "flutter_ime_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "caps_lock_manager.h"
#include "ime_channel_constants.h"
#include "input_source_manager.h"

namespace flutter_ime {

// Static member initialization
FlutterImePlugin* FlutterImePlugin::instance_ = nullptr;
WNDPROC FlutterImePlugin::original_wndproc_ = nullptr;

// static
void FlutterImePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), channels::kMethod,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterImePlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // Setup input-source EventChannel.
  plugin->event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), channels::kInputSourceChangedEvent,
          &flutter::StandardMethodCodec::GetInstance());

  auto event_handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->input_source_manager_->SetEventSink(std::move(events));
        return nullptr;
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->input_source_manager_->ClearEventSink();
        return nullptr;
      });

  plugin->event_channel_->SetStreamHandler(std::move(event_handler));

  // Setup Caps Lock EventChannel.
  plugin->caps_lock_event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), channels::kCapsLockChangedEvent,
          &flutter::StandardMethodCodec::GetInstance());

  auto caps_lock_event_handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->caps_lock_manager_->SetEventSink(std::move(events));
        return nullptr;
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->caps_lock_manager_->ClearEventSink();
        return nullptr;
      });

  plugin->caps_lock_event_channel_->SetStreamHandler(
      std::move(caps_lock_event_handler));

  registrar->AddPlugin(std::move(plugin));
}

FlutterImePlugin::FlutterImePlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  instance_ = this;
  flutter_hwnd_ = GetFlutterViewHwnd();
  input_source_manager_ = std::make_unique<InputSourceManager>(
      [this]() { return GetFlutterViewHwnd(); });
  caps_lock_manager_ = std::make_unique<CapsLockManager>();
  // Setup WndProc hook for input source / caps lock detection.
  SetupWndProcHook();
}

FlutterImePlugin::~FlutterImePlugin() {
  RemoveWndProcHook();
  instance_ = nullptr;
}

HWND FlutterImePlugin::GetFlutterViewHwnd() {
  if (registrar_ && registrar_->GetView()) {
    return registrar_->GetView()->GetNativeWindow();
  }
  return GetForegroundWindow();
}

// WndProc hook - forwards input-source / caps-lock messages to the managers and
// blocks IME messages while the IME is disabled.
LRESULT CALLBACK FlutterImePlugin::WndProcHook(HWND hwnd, UINT message,
                                               WPARAM wparam, LPARAM lparam) {
  if (instance_) {
    InputSourceManager* input = instance_->input_source_manager_.get();
    CapsLockManager* caps = instance_->caps_lock_manager_.get();

    // Detect input source changes.
    // WM_INPUTLANGCHANGE: keyboard layout change (e.g., English -> Korean).
    // WM_IME_NOTIFY + IMN_SETCONVERSIONMODE: IME conversion mode change.
    if (message == WM_INPUTLANGCHANGE) {
      input->OnInputSourceChanged();
    } else if (message == WM_IME_NOTIFY && wparam == IMN_SETCONVERSIONMODE) {
      input->OnInputSourceChanged();
    }

    // Detect Caps Lock state changes via VK_CAPITAL in WM_KEYDOWN/WM_KEYUP.
    if ((message == WM_KEYDOWN || message == WM_KEYUP) && wparam == VK_CAPITAL) {
      caps->OnCapsLockKey();
    }

    // Block IME messages while the IME is disabled.
    if (input->ShouldBlockMessage(message, wparam)) {
      return 0;
    }
  }

  if (original_wndproc_) {
    return CallWindowProc(original_wndproc_, hwnd, message, wparam, lparam);
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

void FlutterImePlugin::SetupWndProcHook() {
  if (original_wndproc_ || !flutter_hwnd_) return;

  original_wndproc_ = reinterpret_cast<WNDPROC>(
      SetWindowLongPtr(flutter_hwnd_, GWLP_WNDPROC,
                       reinterpret_cast<LONG_PTR>(WndProcHook)));
}

void FlutterImePlugin::RemoveWndProcHook() {
  if (original_wndproc_ && flutter_hwnd_) {
    SetWindowLongPtr(flutter_hwnd_, GWLP_WNDPROC,
                     reinterpret_cast<LONG_PTR>(original_wndproc_));
    original_wndproc_ = nullptr;
  }
}

void FlutterImePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == methods::kSetEnglishKeyboard) {
    if (input_source_manager_->SetEnglishKeyboard()) {
      result->Success();
    } else {
      result->Error("IME_ERROR", "Failed to set English keyboard");
    }
  } else if (method == methods::kIsEnglishKeyboard) {
    result->Success(
        flutter::EncodableValue(input_source_manager_->IsEnglishKeyboard()));
  } else if (method == methods::kDisableIme) {
    if (input_source_manager_->DisableIME()) {
      result->Success();
    } else {
      result->Error("IME_ERROR", "Failed to disable IME");
    }
  } else if (method == methods::kEnableIme) {
    if (input_source_manager_->EnableIME()) {
      result->Success();
    } else {
      result->Error("IME_ERROR", "Failed to enable IME");
    }
  } else if (method == methods::kIsCapsLockOn) {
    result->Success(
        flutter::EncodableValue(caps_lock_manager_->QueryAndSyncState()));
  } else if (method == methods::kGetCurrentInputSource) {
    std::string source = input_source_manager_->GetCurrentInputSource();
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
          if (input_source_manager_->SetInputSource(*sourceId)) {
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
