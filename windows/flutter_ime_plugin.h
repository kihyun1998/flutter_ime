#ifndef FLUTTER_PLUGIN_FLUTTER_IME_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_IME_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar_windows.h>

#include <windows.h>
#include <imm.h>
#include <memory>
#include <functional>

namespace flutter_ime {

class FlutterImePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterImePlugin(flutter::PluginRegistrarWindows *registrar);

  virtual ~FlutterImePlugin();

  // Disallow copy and assign.
  FlutterImePlugin(const FlutterImePlugin&) = delete;
  FlutterImePlugin& operator=(const FlutterImePlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // IME utility functions
  bool SetEnglishKeyboard();
  bool IsEnglishKeyboard();
  bool DisableIME();
  bool EnableIME();
  bool IsCapsLockOn();

 private:
  // Get Flutter view HWND
  HWND GetFlutterViewHwnd();

  // WndProc hook functions
  static LRESULT CALLBACK WndProcHook(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  void SetupWndProcHook();
  void RemoveWndProcHook();

  flutter::PluginRegistrarWindows *registrar_ = nullptr;
  HWND flutter_hwnd_ = nullptr;

  // WndProc hook members
  static FlutterImePlugin* instance_;
  static WNDPROC original_wndproc_;
  static bool ime_disabled_;

  // EventChannel for input source changes
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  // EventChannel for Caps Lock state changes
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> caps_lock_event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> caps_lock_event_sink_;

  void SendInputSourceChangedEvent(bool is_english);
  void SendCapsLockChangedEvent(bool is_caps_lock_on);

  // Track Caps Lock state
  static bool last_caps_lock_state_;
};

}  // namespace flutter_ime

#endif  // FLUTTER_PLUGIN_FLUTTER_IME_PLUGIN_H_
