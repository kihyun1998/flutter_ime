#include "input_source_manager.h"

#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <imm.h>

#include <sstream>

// Link IMM32 library (also linked via CMakeLists.txt).
#pragma comment(lib, "imm32.lib")

namespace flutter_ime {

InputSourceManager::InputSourceManager(std::function<HWND()> hwnd_provider)
    : hwnd_provider_(std::move(hwnd_provider)) {}

void InputSourceManager::SetEventSink(
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink) {
  event_sink_ = std::move(sink);
}

void InputSourceManager::ClearEventSink() { event_sink_ = nullptr; }

void InputSourceManager::OnInputSourceChanged() {
  SendInputSourceChangedEvent(IsEnglishKeyboard());
}

void InputSourceManager::SendInputSourceChangedEvent(bool is_english) {
  if (event_sink_) {
    event_sink_->Success(flutter::EncodableValue(is_english));
  }
}

bool InputSourceManager::ShouldBlockMessage(UINT message, WPARAM wparam) const {
  if (!ime_disabled_) return false;

  switch (message) {
    case WM_IME_STARTCOMPOSITION:
    case WM_IME_COMPOSITION:
    case WM_IME_ENDCOMPOSITION:
    case WM_IME_NOTIFY:
    case WM_IME_SETCONTEXT:
    case WM_IME_CHAR:
      // Block IME messages.
      return true;
    case WM_CHAR:
      // Block Korean character range (Hangul syllables: 0xAC00-0xD7A3,
      // Jamo: 0x3131-0x3163).
      if ((wparam >= 0xAC00 && wparam <= 0xD7A3) ||
          (wparam >= 0x3131 && wparam <= 0x3163)) {
        return true;
      }
      break;
  }
  return false;
}

// Set IME to English mode.
bool InputSourceManager::SetEnglishKeyboard() {
  HWND hwnd = hwnd_provider_();
  if (!hwnd) return false;

  HIMC imc = ImmGetContext(hwnd);
  if (!imc) return false;

  // Set IME conversion mode to alphanumeric (English).
  bool success = ImmSetConversionStatus(imc, IME_CMODE_ALPHANUMERIC, IME_SMODE_NONE);

  ImmReleaseContext(hwnd, imc);
  return success;
}

// Check if IME is in English mode.
bool InputSourceManager::IsEnglishKeyboard() {
  HWND hwnd = hwnd_provider_();
  if (!hwnd) return false;

  HIMC imc = ImmGetContext(hwnd);
  if (!imc) return false;

  DWORD conversion = 0;
  DWORD sentence = 0;

  if (!ImmGetConversionStatus(imc, &conversion, &sentence)) {
    ImmReleaseContext(hwnd, imc);
    return false;
  }

  ImmReleaseContext(hwnd, imc);

  // IME_CMODE_NATIVE (0x0001) set = native language mode (e.g., Korean).
  // IME_CMODE_NATIVE not set = English mode.
  return (conversion & IME_CMODE_NATIVE) == 0;
}

// Disable IME - block IME messages via the window-procedure hook.
bool InputSourceManager::DisableIME() {
  HWND hwnd = hwnd_provider_();
  if (!hwnd) return false;

  ime_disabled_ = true;

  // Detach IME context.
  ImmAssociateContextEx(hwnd, nullptr, 0);

  return true;
}

// Enable IME - restore IME functionality.
bool InputSourceManager::EnableIME() {
  HWND hwnd = hwnd_provider_();
  if (!hwnd) return false;

  ime_disabled_ = false;

  // Restore IME context.
  ImmAssociateContextEx(hwnd, nullptr, IACE_DEFAULT);

  return true;
}

// Get current input source (KLID:conversion:sentence format).
std::string InputSourceManager::GetCurrentInputSource() {
  HWND hwnd = hwnd_provider_();
  if (!hwnd) return "";

  // Get keyboard layout name (KLID).
  char klid[KL_NAMELENGTH];
  if (!GetKeyboardLayoutNameA(klid)) {
    return "";
  }

  HIMC imc = ImmGetContext(hwnd);
  if (!imc) {
    // Return KLID only if no IME context.
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

// Set input source from a saved token (KLID:conversion:sentence format).
bool InputSourceManager::SetInputSource(const std::string& source_id) {
  if (source_id.empty()) return false;

  HWND hwnd = hwnd_provider_();
  if (!hwnd) return false;

  // Parse source_id (format: KLID or KLID:conversion:sentence).
  std::string klid;
  DWORD conversion = 0;
  DWORD sentence = 0;
  bool hasConversion = false;

  size_t firstColon = source_id.find(':');
  if (firstColon == std::string::npos) {
    // KLID only.
    klid = source_id;
  } else {
    klid = source_id.substr(0, firstColon);
    size_t secondColon = source_id.find(':', firstColon + 1);
    if (secondColon != std::string::npos) {
      conversion = std::stoul(source_id.substr(firstColon + 1, secondColon - firstColon - 1));
      sentence = std::stoul(source_id.substr(secondColon + 1));
      hasConversion = true;
    }
  }

  // Load and activate keyboard layout.
  HKL hkl = LoadKeyboardLayoutA(klid.c_str(), KLF_ACTIVATE);
  if (!hkl) {
    return false;
  }

  // Set IME conversion status if available.
  if (hasConversion) {
    HIMC imc = ImmGetContext(hwnd);
    if (imc) {
      ImmSetConversionStatus(imc, conversion, sentence);
      ImmReleaseContext(hwnd, imc);
    }
  }

  return true;
}

}  // namespace flutter_ime
