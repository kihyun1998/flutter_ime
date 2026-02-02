#include "flutter_ime_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <imm.h>

// Link IMM32 library
#pragma comment(lib, "imm32.lib")

#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace flutter_ime {

// Static member initialization
FlutterImePlugin* FlutterImePlugin::instance_ = nullptr;
WNDPROC FlutterImePlugin::original_wndproc_ = nullptr;
bool FlutterImePlugin::ime_disabled_ = false;
bool FlutterImePlugin::last_caps_lock_state_ = false;

// static
void FlutterImePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_ime",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterImePlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // Setup EventChannel
  plugin->event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_ime/input_source_changed",
          &flutter::StandardMethodCodec::GetInstance());

  auto event_handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->event_sink_ = std::move(events);
        return nullptr;
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->event_sink_ = nullptr;
        return nullptr;
      });

  plugin->event_channel_->SetStreamHandler(std::move(event_handler));

  // Setup Caps Lock EventChannel
  plugin->caps_lock_event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_ime/caps_lock_changed",
          &flutter::StandardMethodCodec::GetInstance());

  auto caps_lock_event_handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->caps_lock_event_sink_ = std::move(events);
        // Store initial Caps Lock state
        last_caps_lock_state_ = plugin_pointer->IsCapsLockOn();
        return nullptr;
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->caps_lock_event_sink_ = nullptr;
        return nullptr;
      });

  plugin->caps_lock_event_channel_->SetStreamHandler(std::move(caps_lock_event_handler));

  registrar->AddPlugin(std::move(plugin));
}

FlutterImePlugin::FlutterImePlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  instance_ = this;
  flutter_hwnd_ = GetFlutterViewHwnd();
  // Setup WndProc hook for input source change detection
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

// WndProc hook - Intercepts IME messages and detects input source changes
LRESULT CALLBACK FlutterImePlugin::WndProcHook(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  // Detect input source changes
  // WM_INPUTLANGCHANGE: Keyboard layout change (e.g., English -> Korean keyboard)
  // WM_IME_NOTIFY + IMN_SETCONVERSIONMODE: IME conversion mode change (e.g., Korean/English toggle)
  if (message == WM_INPUTLANGCHANGE) {
    if (instance_) {
      bool is_english = instance_->IsEnglishKeyboard();
      instance_->SendInputSourceChangedEvent(is_english);
    }
  } else if (message == WM_IME_NOTIFY && wparam == IMN_SETCONVERSIONMODE) {
    if (instance_) {
      bool is_english = instance_->IsEnglishKeyboard();
      instance_->SendInputSourceChangedEvent(is_english);
    }
  }

  // Detect Caps Lock state changes
  // Detect VK_CAPITAL key in WM_KEYDOWN/WM_KEYUP
  if ((message == WM_KEYDOWN || message == WM_KEYUP) && wparam == VK_CAPITAL) {
    if (instance_) {
      bool is_caps_lock_on = instance_->IsCapsLockOn();
      if (is_caps_lock_on != last_caps_lock_state_) {
        last_caps_lock_state_ = is_caps_lock_on;
        instance_->SendCapsLockChangedEvent(is_caps_lock_on);
      }
    }
  }

  if (ime_disabled_) {
    switch (message) {
      case WM_IME_STARTCOMPOSITION:
      case WM_IME_COMPOSITION:
      case WM_IME_ENDCOMPOSITION:
      case WM_IME_NOTIFY:
      case WM_IME_SETCONTEXT:
      case WM_IME_CHAR:
        // Block IME messages
        return 0;
      case WM_CHAR:
        // Block Korean character range (Hangul syllables: 0xAC00-0xD7A3, Jamo: 0x3131-0x3163)
        if ((wparam >= 0xAC00 && wparam <= 0xD7A3) ||
            (wparam >= 0x3131 && wparam <= 0x3163)) {
          return 0;
        }
        break;
    }
  }

  if (original_wndproc_) {
    return CallWindowProc(original_wndproc_, hwnd, message, wparam, lparam);
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

// Send input source changed event to Flutter
void FlutterImePlugin::SendInputSourceChangedEvent(bool is_english) {
  if (event_sink_) {
    event_sink_->Success(flutter::EncodableValue(is_english));
  }
}

// Send Caps Lock state changed event to Flutter
void FlutterImePlugin::SendCapsLockChangedEvent(bool is_caps_lock_on) {
  if (caps_lock_event_sink_) {
    caps_lock_event_sink_->Success(flutter::EncodableValue(is_caps_lock_on));
  }
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
  ime_disabled_ = false;
}

void FlutterImePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("setEnglishKeyboard")==0){
    bool success = SetEnglishKeyboard();
    if(success){
      result->Success();
    }else{
      result->Error("IME_ERROR","Failed to set English keyboard");
    }
  } else if(method_call.method_name().compare("isEnglishKeyboard")==0){
    result->Success(flutter::EncodableValue(IsEnglishKeyboard()));
  } else if(method_call.method_name().compare("disableIME")==0){
    bool success = DisableIME();
    if(success){
      result->Success();
    }else{
      result->Error("IME_ERROR","Failed to disable IME");
    }
  } else if(method_call.method_name().compare("enableIME")==0){
    bool success = EnableIME();
    if(success){
      result->Success();
    }else{
      result->Error("IME_ERROR","Failed to enable IME");
    }
  } else if(method_call.method_name().compare("isCapsLockOn")==0){
    result->Success(flutter::EncodableValue(IsCapsLockOn()));
  } else if(method_call.method_name().compare("getCurrentInputSource")==0){
    std::string source = GetCurrentInputSource();
    if(!source.empty()){
      result->Success(flutter::EncodableValue(source));
    }else{
      result->Success(flutter::EncodableValue());
    }
  } else if(method_call.method_name().compare("setInputSource")==0){
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if(args){
      auto it = args->find(flutter::EncodableValue("sourceId"));
      if(it != args->end()){
        const auto* sourceId = std::get_if<std::string>(&it->second);
        if(sourceId){
          bool success = SetInputSource(*sourceId);
          if(success){
            result->Success();
          }else{
            result->Error("IME_ERROR","Failed to set input source");
          }
        }else{
          result->Error("INVALID_ARGUMENT","sourceId must be a string");
        }
      }else{
        result->Error("INVALID_ARGUMENT","sourceId is required");
      }
    }else{
      result->Error("INVALID_ARGUMENT","Arguments must be a map");
    }
  } else {
    result->NotImplemented();
  }
}


/// Set IME to English mode
bool FlutterImePlugin::SetEnglishKeyboard(){
  // Get Flutter view HWND
  HWND hwnd = GetFlutterViewHwnd();
  if(!hwnd) return false;

  // Get IME context
  HIMC imc = ImmGetContext(hwnd);
  if(!imc) return false;

  // Set IME conversion mode to alphanumeric (English)
  bool success = ImmSetConversionStatus(imc,IME_CMODE_ALPHANUMERIC, IME_SMODE_NONE);

  // Release IME context
  ImmReleaseContext(hwnd,imc);
  return success;
}

/// Check if IME is in English mode
bool FlutterImePlugin::IsEnglishKeyboard(){
  HWND hwnd = GetFlutterViewHwnd();
  if(!hwnd) return false;

  HIMC imc = ImmGetContext(hwnd);
  if(!imc) return false;

  DWORD conversion = 0;
  DWORD sentence = 0;

  // Get IME conversion status
  if(!ImmGetConversionStatus(imc,&conversion,&sentence)){
    ImmReleaseContext(hwnd,imc);
    return false;
  }

  // Release IME context
  ImmReleaseContext(hwnd,imc);

  // IME_CMODE_NATIVE (0x0001) set = native language mode (e.g., Korean)
  // IME_CMODE_NATIVE not set = English mode
  return (conversion & IME_CMODE_NATIVE) == 0;
}

/// Disable IME - Block IME messages via WndProc hook
bool FlutterImePlugin::DisableIME(){
  HWND hwnd = GetFlutterViewHwnd();
  if(!hwnd) return false;

  // Setup WndProc hook
  SetupWndProcHook();
  ime_disabled_ = true;

  // Detach IME context
  ImmAssociateContextEx(hwnd, nullptr, 0);

  return true;
}

/// Enable IME - Restore IME functionality
bool FlutterImePlugin::EnableIME(){
  HWND hwnd = GetFlutterViewHwnd();
  if(!hwnd) return false;

  // Stop blocking IME messages
  ime_disabled_ = false;

  // Restore IME context
  ImmAssociateContextEx(hwnd, nullptr, IACE_DEFAULT);

  return true;
}

/// Check if Caps Lock is on
bool FlutterImePlugin::IsCapsLockOn(){
  // GetKeyState low-order bit is 1 when Caps Lock is toggled on
  return (GetKeyState(VK_CAPITAL) & 0x0001) != 0;
}

/// Get current input source (KLID:conversion:sentence format)
std::string FlutterImePlugin::GetCurrentInputSource(){
  HWND hwnd = GetFlutterViewHwnd();
  if(!hwnd) return "";

  // Get keyboard layout name (KLID)
  char klid[KL_NAMELENGTH];
  if(!GetKeyboardLayoutNameA(klid)){
    return "";
  }

  // Get IME conversion status
  HIMC imc = ImmGetContext(hwnd);
  if(!imc){
    // Return KLID only if no IME context
    return std::string(klid);
  }

  DWORD conversion = 0;
  DWORD sentence = 0;
  ImmGetConversionStatus(imc, &conversion, &sentence);
  ImmReleaseContext(hwnd, imc);

  // Format: KLID:conversion:sentence
  std::ostringstream oss;
  oss << klid << ":" << conversion << ":" << sentence;
  return oss.str();
}

/// Set input source from saved state (KLID:conversion:sentence format)
bool FlutterImePlugin::SetInputSource(const std::string& sourceId){
  if(sourceId.empty()) return false;

  HWND hwnd = GetFlutterViewHwnd();
  if(!hwnd) return false;

  // Parse sourceId (format: KLID or KLID:conversion:sentence)
  std::string klid;
  DWORD conversion = 0;
  DWORD sentence = 0;
  bool hasConversion = false;

  size_t firstColon = sourceId.find(':');
  if(firstColon == std::string::npos){
    // KLID only
    klid = sourceId;
  }else{
    klid = sourceId.substr(0, firstColon);
    size_t secondColon = sourceId.find(':', firstColon + 1);
    if(secondColon != std::string::npos){
      conversion = std::stoul(sourceId.substr(firstColon + 1, secondColon - firstColon - 1));
      sentence = std::stoul(sourceId.substr(secondColon + 1));
      hasConversion = true;
    }
  }

  // Load and activate keyboard layout
  HKL hkl = LoadKeyboardLayoutA(klid.c_str(), KLF_ACTIVATE);
  if(!hkl){
    return false;
  }

  // Set IME conversion status if available
  if(hasConversion){
    HIMC imc = ImmGetContext(hwnd);
    if(imc){
      ImmSetConversionStatus(imc, conversion, sentence);
      ImmReleaseContext(hwnd, imc);
    }
  }

  return true;
}

}  // namespace flutter_ime
