#ifndef FLUTTER_PLUGIN_CAPS_LOCK_MANAGER_H_
#define FLUTTER_PLUGIN_CAPS_LOCK_MANAGER_H_

#include <flutter/event_channel.h>

#include <windows.h>

#include <memory>

namespace flutter_ime {

// Owns Caps Lock state querying and change monitoring on Windows, and emits
// Caps Lock change events. The window-procedure hook lives in the plugin and
// forwards VK_CAPITAL key messages here via OnCapsLockKey().
class CapsLockManager {
 public:
  // Reads the live Caps Lock toggle state.
  bool IsCapsLockOn() const;

  // Reads the live state and syncs the cached value, so the next OnCapsLockKey
  // compares against a fresh baseline. Used by the isCapsLockOn method call.
  bool QueryAndSyncState();

  // Event-sink lifecycle for the caps-lock-changed event channel. Setting a
  // sink also captures the current state as the monitoring baseline.
  void SetEventSink(
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink);
  void ClearEventSink();

  // Called from the window-procedure hook on a VK_CAPITAL key message.
  void OnCapsLockKey();

 private:
  void SendCapsLockChangedEvent(bool is_caps_lock_on);

  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>
      caps_lock_event_sink_;
  bool last_caps_lock_state_ = false;
};

}  // namespace flutter_ime

#endif  // FLUTTER_PLUGIN_CAPS_LOCK_MANAGER_H_
