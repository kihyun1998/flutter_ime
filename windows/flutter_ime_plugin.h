#ifndef FLUTTER_PLUGIN_FLUTTER_IME_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_IME_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar_windows.h>

#include <windows.h>
#include <memory>

#include "caps_lock_manager.h"
#include "input_source_manager.h"

namespace flutter_ime {

// Thin plugin shell: registers the channels, owns the window-procedure hook,
// and dispatches method calls and hooked messages to the feature managers.
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

 private:
  // Get Flutter view HWND.
  HWND GetFlutterViewHwnd();

  // WndProc hook functions.
  static LRESULT CALLBACK WndProcHook(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam);
  void SetupWndProcHook();
  void RemoveWndProcHook();

  flutter::PluginRegistrarWindows *registrar_ = nullptr;
  HWND flutter_hwnd_ = nullptr;

  // WndProc hook members. Still static (single-window assumption); removing the
  // static global state is tracked as a follow-up.
  static FlutterImePlugin* instance_;
  static WNDPROC original_wndproc_;

  // EventChannels (stream handlers forward sinks to the managers).
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> caps_lock_event_channel_;

  // Feature managers.
  std::unique_ptr<InputSourceManager> input_source_manager_;
  std::unique_ptr<CapsLockManager> caps_lock_manager_;
};

}  // namespace flutter_ime

#endif  // FLUTTER_PLUGIN_FLUTTER_IME_PLUGIN_H_
