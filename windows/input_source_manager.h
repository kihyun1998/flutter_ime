#ifndef FLUTTER_PLUGIN_INPUT_SOURCE_MANAGER_H_
#define FLUTTER_PLUGIN_INPUT_SOURCE_MANAGER_H_

#include <flutter/event_channel.h>

#include <windows.h>

#include <functional>
#include <memory>
#include <string>

namespace flutter_ime {

// Owns all input-source / IME-control responsibilities on Windows: switching to
// English, reading and restoring the input-source token, disabling/enabling the
// IME, and emitting input-source-changed events.
//
// The window-procedure hook lives in the plugin and forwards the relevant
// messages here via OnInputSourceChanged() and ShouldBlockMessage().
class InputSourceManager {
 public:
  // [hwnd_provider] returns the Flutter view window handle to operate on.
  explicit InputSourceManager(std::function<HWND()> hwnd_provider);

  // IME operations. Each returns false on failure.
  bool SetEnglishKeyboard();
  bool IsEnglishKeyboard();
  std::string GetCurrentInputSource();
  bool SetInputSource(const std::string& source_id);
  bool DisableIME();
  bool EnableIME();

  // Event-sink lifecycle for the input-source-changed event channel.
  void SetEventSink(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);
  void ClearEventSink();

  // Called from the window-procedure hook when the OS reports an input-source
  // or IME-conversion change.
  void OnInputSourceChanged();

  // Returns true when [message] should be blocked because the IME is currently
  // disabled (see DisableIME).
  bool ShouldBlockMessage(UINT message, WPARAM wparam) const;

 private:
  void SendInputSourceChangedEvent(bool is_english);

  std::function<HWND()> hwnd_provider_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  bool ime_disabled_ = false;
};

}  // namespace flutter_ime

#endif  // FLUTTER_PLUGIN_INPUT_SOURCE_MANAGER_H_
