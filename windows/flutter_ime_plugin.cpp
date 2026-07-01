#include "flutter_ime_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <commctrl.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "caps_lock_manager.h"
#include "ime_channel_constants.h"
#include "input_source_manager.h"
#include "method_dispatch.h"

// Link the common-controls library for SetWindowSubclass/DefSubclassProc
// (also linked via CMakeLists.txt).
#pragma comment(lib, "comctl32.lib")

namespace flutter_ime {

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
  flutter_hwnd_ = GetFlutterViewHwnd();
  input_source_manager_ = std::make_unique<InputSourceManager>(
      [this]() { return GetFlutterViewHwnd(); });
  caps_lock_manager_ = std::make_unique<CapsLockManager>();
  // Setup WndProc hook for input source / caps lock detection.
  SetupWndProcHook();
}

FlutterImePlugin::~FlutterImePlugin() {
  RemoveWndProcHook();
}

HWND FlutterImePlugin::GetFlutterViewHwnd() {
  if (registrar_ && registrar_->GetView()) {
    return registrar_->GetView()->GetNativeWindow();
  }
  return GetForegroundWindow();
}

// Subclass procedure - forwards input-source / caps-lock messages to the owning
// instance's managers and blocks IME messages while the IME is disabled. The
// instance is recovered from the per-window subclass ref-data.
LRESULT CALLBACK FlutterImePlugin::SubclassProc(HWND hwnd, UINT message,
                                                WPARAM wparam, LPARAM lparam,
                                                UINT_PTR /*id_subclass*/,
                                                DWORD_PTR ref_data) {
  auto* self = reinterpret_cast<FlutterImePlugin*>(ref_data);
  if (self) {
    InputSourceManager* input = self->input_source_manager_.get();
    CapsLockManager* caps = self->caps_lock_manager_.get();

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

  // Chain to the next subclass / original window procedure.
  return DefSubclassProc(hwnd, message, wparam, lparam);
}

void FlutterImePlugin::SetupWndProcHook() {
  if (hooked_ || !flutter_hwnd_) return;

  if (SetWindowSubclass(flutter_hwnd_, &SubclassProc, kSubclassId,
                        reinterpret_cast<DWORD_PTR>(this))) {
    hooked_ = true;
  }
}

void FlutterImePlugin::RemoveWndProcHook() {
  if (hooked_ && flutter_hwnd_) {
    RemoveWindowSubclass(flutter_hwnd_, &SubclassProc, kSubclassId);
    hooked_ = false;
  }
}

void FlutterImePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  HandleImeMethodCall(*input_source_manager_, *caps_lock_manager_, method_call,
                      std::move(result));
}

}  // namespace flutter_ime
