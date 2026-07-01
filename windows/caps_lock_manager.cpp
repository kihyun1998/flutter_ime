#include "caps_lock_manager.h"

#include <flutter/standard_method_codec.h>

#include <windows.h>

namespace flutter_ime {

bool CapsLockManager::IsCapsLockOn() const {
  // GetKeyState low-order bit is 1 when Caps Lock is toggled on.
  return (GetKeyState(VK_CAPITAL) & 0x0001) != 0;
}

bool CapsLockManager::QueryAndSyncState() {
  bool is_on = IsCapsLockOn();
  last_caps_lock_state_ = is_on;
  return is_on;
}

void CapsLockManager::SetEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink) {
  caps_lock_event_sink_ = std::move(sink);
  // Store initial Caps Lock state as the monitoring baseline.
  last_caps_lock_state_ = IsCapsLockOn();
}

void CapsLockManager::ClearEventSink() { caps_lock_event_sink_ = nullptr; }

void CapsLockManager::OnCapsLockKey() {
  bool is_caps_lock_on = IsCapsLockOn();
  if (is_caps_lock_on != last_caps_lock_state_) {
    last_caps_lock_state_ = is_caps_lock_on;
    SendCapsLockChangedEvent(is_caps_lock_on);
  }
}

void CapsLockManager::SendCapsLockChangedEvent(bool is_caps_lock_on) {
  if (caps_lock_event_sink_) {
    caps_lock_event_sink_->Success(flutter::EncodableValue(is_caps_lock_on));
  }
}

}  // namespace flutter_ime
